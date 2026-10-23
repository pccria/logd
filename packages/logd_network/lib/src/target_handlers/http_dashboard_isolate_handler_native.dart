library;

import 'dart:async';
import 'dart:io' as io;
import 'dart:isolate';

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import '../sink/http_server_sink.dart';

/// Internal plain-data config passed across the isolate boundary.
class _HttpWorkerConfig {
  const _HttpWorkerConfig({
    required this.address,
    required this.port,
    required this.bufferCapacity,
    this.lineLength,
    this.maxConnections = 32,
    this.allowedOrigins = const {},
    required this.formatter,
    required this.decorators,
    this.timeoutMs,
  });

  final String address;
  final int port;
  final int bufferCapacity;
  final int? lineLength;
  final int maxConnections;
  final Set<String> allowedOrigins;
  final LogFormatter formatter;
  final List<LogDecorator> decorators;
  final int? timeoutMs;
}

/// Internal stop command sent to the worker isolate.
class _StopCommand {
  _StopCommand(this.replyPort);

  final SendPort replyPort;
}

class _IsolateState {
  Isolate? isolate;
  SendPort? commandPort;
  int? boundPort;
  bool isDisposed = false;
}

/// A background-isolate [Handler] for [HttpServerSink] that passes only
/// plain-data config across the isolate boundary, constructing the
/// [HttpServerSink] fresh inside the worker isolate.
///
/// This avoids the [SendPort] `object is unsendable` error that arises when
/// transferring an active HTTP server, WebSocket list, or [Completer] across
/// isolate boundaries.
@internal
base class HttpDashboardIsolateHandler extends Handler {
  /// Creates an [HttpDashboardIsolateHandler] that spawns a background isolate.
  ///
  /// The [HttpServerSink] is constructed inside the background isolate from
  /// the supplied plain-data config. The HTTP server is bound and WebSocket
  /// connections are handled entirely off the main thread.
  HttpDashboardIsolateHandler({
    final String address = 'localhost',
    final int port = 8080,
    final int bufferCapacity = 100,
    final int? lineLength,
    final int maxConnections = 32,
    final Set<String> allowedOrigins = const {},
    super.formatter = const StructuredFormatter(),
    super.decorators,
    super.filters,
    super.timeout,
  })  : _config = _HttpWorkerConfig(
          address: address,
          port: port,
          bufferCapacity: bufferCapacity,
          lineLength: lineLength,
          maxConnections: maxConnections,
          allowedOrigins: allowedOrigins,
          formatter: formatter,
          decorators: decorators,
          timeoutMs: timeout?.inMilliseconds,
        ),
        super(
          sink: _NoOpSink(),
          engine: const StandardEngine(),
        ) {
    _finalizer.attach(this, _receivePort, detach: this);
    _start();
  }

  final _HttpWorkerConfig _config;
  final ReceivePort _receivePort = ReceivePort();
  final ReceivePort _errorPort = ReceivePort();
  final Completer<void> _ready = Completer<void>();
  final _IsolateState _state = _IsolateState();

  /// The actual bound port of the running HTTP server inside the worker isolate.
  int get boundPort => _state.boundPort ?? _config.port;

  static final Finalizer<ReceivePort> _finalizer =
      Finalizer<ReceivePort>((final port) {
    io.stderr.writeln(
      '[logd] HttpDashboardIsolateHandler leak detected! '
      'Handler garbage-collected without dispose(). '
      'Call dispose() to close the HTTP server and WebSocket connections.',
    );
    port.close();
  });

  /// A future that completes when the background isolate is ready.
  Future<void> get ready => _ready.future;

  Future<void> _start() async {
    try {
      _state.isolate = await Isolate.spawn(
        _workerMain,
        [_receivePort.sendPort, _config],
        onError: _errorPort.sendPort,
        debugName: 'HttpDashboardIsolateHandler',
      );

      _errorPort.listen((final message) {
        if (!_ready.isCompleted) {
          _ready.completeError(
            StateError('HttpDashboardIsolateHandler worker error: $message'),
          );
        }
        io.stderr.writeln(
          '[logd] HttpDashboardIsolateHandler worker error: $message',
        );
      });

      final firstMsg = await _receivePort.first;
      if (firstMsg is List && firstMsg.isNotEmpty) {
        final success = firstMsg[0] as bool;
        if (success) {
          _state.commandPort = firstMsg[1] as SendPort;
          _state.boundPort = firstMsg[2] as int;
          if (!_ready.isCompleted) {
            _ready.complete();
          }
        } else {
          final error = firstMsg[1] as String;
          if (!_ready.isCompleted) {
            _ready.completeError(
              StateError(
                'HttpDashboardIsolateHandler worker failed to initialize: $error',
              ),
            );
          }
        }
      } else if (firstMsg is SendPort) {
        _state.commandPort = firstMsg;
        if (!_ready.isCompleted) {
          _ready.complete();
        }
      }
    } catch (e, s) {
      _errorPort.close();
      _receivePort.close();
      if (!_ready.isCompleted) {
        _ready.completeError(e, s);
      }
    }
  }

  @override
  @internal
  Future<void> log(final LogEntry entry) async {
    if (_state.isDisposed) return;

    if (filters.any((final f) => !f.shouldLog(entry))) return;

    if (!_ready.isCompleted) {
      await _ready.future;
    }

    if (_state.isDisposed) return;

    _state.commandPort?.send(entry);
  }

  @override
  Future<void> dispose() async {
    if (_state.isDisposed) return;
    _state.isDisposed = true;
    _finalizer.detach(this);

    if (!_ready.isCompleted) {
      try {
        await _ready.future.timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    final port = _state.commandPort;
    if (port != null) {
      final reply = ReceivePort();
      try {
        port.send(_StopCommand(reply.sendPort));
        await reply.first.timeout(const Duration(seconds: 3));
      } catch (_) {
        _state.isolate?.kill(priority: Isolate.immediate);
      } finally {
        reply.close();
      }
    } else {
      _state.isolate?.kill(priority: Isolate.immediate);
    }

    _receivePort.close();
    _errorPort.close();
    _state.isolate = null;
    _state.commandPort = null;
    await super.dispose();
  }

  /// Worker isolate entry point. Receives only plain-data config.
  /// Constructs [HttpServerSink] fresh here — no live handles cross the boundary.
  static Future<void> _workerMain(final List<dynamic> args) async {
    final sendPort = args[0] as SendPort;
    final config = args[1] as _HttpWorkerConfig;

    final formatter = config.formatter;
    final decorators = config.decorators;
    final timeout = config.timeoutMs != null
        ? Duration(milliseconds: config.timeoutMs!)
        : null;

    // Construct sink fresh inside the isolate — HTTP server binds here.
    final HttpServerSink sink;
    try {
      sink = HttpServerSink(
        address: config.address,
        port: config.port,
        bufferCapacity: config.bufferCapacity,
        lineLength: config.lineLength,
        maxConnections: config.maxConnections,
        allowedOrigins: config.allowedOrigins,
      );
      await sink.ready;
    } catch (e, s) {
      sendPort.send([false, e.toString(), s.toString()]);
      return;
    }

    const engine = StandardEngine();

    final receivePort = ReceivePort();
    sendPort.send([true, receivePort.sendPort, sink.boundPort]);

    await for (final message in receivePort) {
      if (message is LogEntry) {
        try {
          if (timeout != null) {
            await engine
                .execute(message, formatter, decorators, sink)
                .timeout(timeout);
          } else {
            await engine.execute(message, formatter, decorators, sink);
          }
        } catch (e, s) {
          io.stderr.writeln(
            '[logd] HttpDashboardIsolateHandler worker pipeline failed: $e\n$s',
          );
        }
      } else if (message is _StopCommand) {
        try {
          await sink.dispose();
        } catch (e, s) {
          io.stderr.writeln(
            '[logd] HttpDashboardIsolateHandler worker dispose failed: $e\n$s',
          );
        } finally {
          message.replyPort.send(null);
          receivePort.close();
        }
        break;
      }
    }
  }
}

/// A no-op [LogSink] used as a placeholder in [HttpDashboardIsolateHandler]'s
/// [Handler] superclass constructor. All actual output goes to the
/// [HttpServerSink] running inside the background isolate.
base class _NoOpSink extends LogSink<LogDocument> {
  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {}
}
