// ignore_for_file: invalid_use_of_internal_member, implementation_imports
library;

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'package:logd/logd.dart';
import 'package:logd/src/logger/internal_logger.dart';
import 'dashboard_html.dart';

/// A [LogSink] that starts a local HTTP and WebSocket server to host a
/// real-time log viewer dashboard.
@experimental
base class HttpServerSink extends EncodingSink {
  /// Creates an [HttpServerSink] binding to [address] and [port].
  HttpServerSink({
    this.address = 'localhost',
    this.port = 8080,
    super.encoder = const AutoTextEncoder(),
    final int? lineLength,
    super.enabled = true,
    this.bufferCapacity = 100,
    this.maxConnections = 32,
    this.allowedOrigins = const {},
  }) : super(preferredWidth: lineLength ?? 120, delegate: _staticWrite) {
    _startServer();
  }

  /// The local interface address to bind to.
  final String address;

  /// The local port number to bind to.
  final int port;

  /// Maximum number of historical log entries to buffer and replay to new
  /// WebSocket dashboard connections.
  final int bufferCapacity;

  /// Maximum number of concurrent WebSocket dashboard connections permitted.
  final int maxConnections;

  /// Allowed origins for incoming WebSocket upgrade requests.
  ///
  /// By default, loopback origins (`localhost`, `127.0.0.1`, `::1`, and matching `Host` header)
  /// and non-browser clients (null origin) are allowed to prevent Cross-Site WebSocket
  /// Hijacking (CSWSH). Add any custom remote dashboard domains here if applicable.
  final Set<String> allowedOrigins;

  /// Completer to track server readiness.
  final Completer<void> _ready = Completer<void>();

  /// A future that completes when the HTTP server is successfully bound
  /// and listening.
  Future<void> get ready => _ready.future;

  /// The actual bound port of the running HTTP server.
  int get boundPort => _server?.port ?? port;

  io.HttpServer? _server;
  final List<io.WebSocket> _sockets = [];
  final List<String> _history = [];
  bool _isDisposed = false;

  static void _staticWrite(final Uint8List data) {
    // Overridden by custom output logic
  }

  Future<void> _startServer() async {
    try {
      final server = await io.HttpServer.bind(address, port);
      _server = server;
      _ready.complete();

      server.listen((final request) async {
        if (request.uri.path == '/') {
          request.response.headers.contentType = io.ContentType.html;
          request.response.headers.set('X-Content-Type-Options', 'nosniff');
          request.response.headers.set('X-Frame-Options', 'DENY');
          request.response.headers.set(
            'Content-Security-Policy',
            "default-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://fonts.gstatic.com; connect-src 'self' ws: wss:;",
          );
          var html = dashboardHtml;
          final Object currentEncoder = encoder;
          if (currentEncoder.runtimeType.toString() == 'HtmlEncoder') {
            final dynamic enc = currentEncoder;
            final css = enc.stylesheet;
            html = html.replaceFirst('</head>', '<style>$css</style></head>');
          }
          request.response.write(html);
          await request.response.close();
        } else if (request.uri.path == '/ws') {
          // 1. Connection limit check
          if (_sockets.length >= maxConnections) {
            request.response.statusCode = io.HttpStatus.serviceUnavailable;
            request.response.headers.set('Retry-After', '5');
            request.response.write(
              'Maximum concurrent dashboard connections reached ($maxConnections).',
            );
            await request.response.close();
            return;
          }

          // 2. CSWSH Origin validation
          final origin = request.headers.value('origin');
          if (origin != null &&
              origin.isNotEmpty &&
              !_isOriginAllowed(origin, request.headers.host)) {
            request.response.statusCode = io.HttpStatus.forbidden;
            request.response
                .write('Cross-origin WebSocket connection forbidden.');
            await request.response.close();
            return;
          }

          try {
            final socket = await io.WebSocketTransformer.upgrade(request);
            _sockets.add(socket);
            for (final item in _history) {
              if (socket.readyState == io.WebSocket.open) {
                socket.add(item);
              }
            }
            socket.listen(
              (final _) {},
              onError: (final _) {
                _sockets.remove(socket);
              },
              onDone: () {
                _sockets.remove(socket);
              },
            );
          } catch (e) {
            InternalLogger.log(
              LogLevel.error,
              'HttpServerSink: Failed to upgrade WebSocket request',
              error: e,
            );
          }
        } else {
          request.response.statusCode = io.HttpStatus.notFound;
          await request.response.close();
        }
      });
    } catch (e, s) {
      _ready.completeError(e, s);
      InternalLogger.log(
        LogLevel.error,
        'HttpServerSink: Failed to start HTTP server on $address:$port',
        error: e,
        stackTrace: s,
      );
    }
  }

  bool _isOriginAllowed(final String origin, final String? hostHeader) {
    if (allowedOrigins.contains(origin)) {
      return true;
    }
    try {
      final originUri = Uri.parse(origin);
      final originHost = originUri.host.toLowerCase();

      // Allow loopback / localhost origins by default
      if (originHost == 'localhost' ||
          originHost == '127.0.0.1' ||
          originHost == '::1') {
        return true;
      }

      // Allow if origin host matches the incoming HTTP Host header
      if (hostHeader != null) {
        final hostOnly = hostHeader.split(':').first.toLowerCase();
        if (originHost == hostOnly) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    if (!enabled || _isDisposed) {
      return;
    }

    final context = factory.checkoutContext();
    try {
      encoder.encode(
        entry,
        document,
        level,
        context,
        factory,
        width: preferredWidth,
      );
      final data = context.takeBytes();
      final formattedString = convert.utf8.decode(data);

      final payload = {
        'formatted': formattedString,
        'isHtml': encoder.runtimeType.toString() == 'HtmlEncoder',
        'entry': {
          'loggerName': entry.loggerName,
          'origin': entry.origin,
          'level': entry.level.name,
          'message': entry.message,
          'timestamp': entry.timestamp,
          if (entry.error != null) 'error': entry.error.toString(),
          if (entry.stackTrace != null)
            'stackTrace': entry.stackTrace.toString(),
          if (entry.context != null) 'context': entry.context,
        },
        if (document.metadata.containsKey('toon_columns'))
          'toon': {
            'array': document.metadata['toon_array'] as String? ?? 'logs',
            'columns': document.metadata['toon_columns'] as List<String>?,
            'delimiter': document.metadata['toon_delimiter'] as String? ?? '\t',
          },
      };

      final payloadJson = convert.jsonEncode(payload);

      if (bufferCapacity > 0) {
        _history.add(payloadJson);
        if (_history.length > bufferCapacity) {
          _history.removeAt(0);
        }
      }

      final sockets = List<io.WebSocket>.from(_sockets);
      for (final socket in sockets) {
        if (socket.readyState == io.WebSocket.open) {
          socket.add(payloadJson);
        }
      }
    } catch (e, s) {
      InternalLogger.log(
        LogLevel.error,
        'HttpServerSink output failed',
        error: e,
        stackTrace: s,
      );
    } finally {
      factory.release(context);
    }
  }

  @override
  @mustCallSuper
  Future<void> dispose() async {
    _isDisposed = true;

    final sockets = List<io.WebSocket>.from(_sockets);
    for (final socket in sockets) {
      await socket.close();
    }
    _sockets.clear();
    _history.clear();

    await _server?.close(force: true);
    await super.dispose();
  }
}
