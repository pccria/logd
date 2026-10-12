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
