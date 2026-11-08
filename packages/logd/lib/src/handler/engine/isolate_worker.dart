library;

import 'dart:async';
import 'dart:isolate';
import 'package:meta/meta.dart';
import '../../logger/logger.dart';
import 'isolate_protocol.dart';

/// A reusable runner for background isolates managing spawn, error handling,
/// commands, and clean disposal.
@internal
class IsolateWorker {
  /// Creates an [IsolateWorker].
  IsolateWorker({
    required this.entryPoint,
    required this.initArg,
    required this.debugName,
    this.onWorkerError,
  });

  /// The entry point function for the isolate.
  final void Function(List<dynamic>) entryPoint;

  /// The argument passed as config/state to the isolate.
  final dynamic initArg;

  /// Name used in error/debug logging.
  final String debugName;

  /// Optional callback triggered if the isolate crashes/errors.
  final void Function(dynamic error)? onWorkerError;

  SendPort? _commandPort;
  ReceivePort? _errorPort;
  Isolate? _isolate;
  final Completer<void> _ready = Completer<void>();
  bool _isDisposed = false;

  /// The control port for sending messages to the worker isolate.
  SendPort? get commandPort => _commandPort;

  /// The spawned isolate instance.
  Isolate? get isolate => _isolate;

  /// A future that completes when the worker isolate is spawned and ready.
  Future<void> get ready => _ready.future;

  /// Whether the worker isolate is ready.
  bool get isReady => _ready.isCompleted;

  /// Whether the worker isolate has been disposed.
  bool get isDisposed => _isDisposed;

  /// Starts the worker isolate.
  Future<void> start() async {
    final receivePort = ReceivePort();
    final errPort = ReceivePort();
    _errorPort = errPort;

    try {
      _isolate = await Isolate.spawn(
        entryPoint,
        [receivePort.sendPort, initArg],
        onError: errPort.sendPort,
        errorsAreFatal: false,
      );

      if (_isDisposed) {
        errPort.close();
        receivePort.close();
        _isolate?.kill();
        _isolate = null;
        return;
      }

      errPort.listen((final message) {
        InternalLogger.log(
          LogLevel.error,
          '$debugName worker error',
          error: message,
        );
        if (onWorkerError != null) {
          onWorkerError!(message);
        }
      });

      _commandPort = await receivePort.first as SendPort;
      _ready.complete();
    } catch (e, s) {
      errPort.close();
      receivePort.close();
      if (!_ready.isCompleted) {
        _ready.completeError(e, s);
      }
      rethrow;
    }
  }

  /// Sends a command or message to the worker isolate.
  void send(final dynamic message) {
    if (_isDisposed) {
      return;
    }
    _commandPort?.send(message);
  }

  /// Immediately terminates the worker isolate and closes control ports
  /// without waiting for a graceful stop response.
  ///
  /// Intended for emergency resource cleanup in [Finalizer] callbacks.
  void kill() {
    _isDisposed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _errorPort?.close();
    _errorPort = null;
    _commandPort = null;
  }

  /// Cleanly shuts down the worker isolate, attempting a graceful stop command
  /// before killing the isolate.
  Future<void> dispose() async {
    _isDisposed = true;
    final port = _commandPort;
    if (port != null) {
      final callback = ReceivePort();
      try {
        port.send(IsolateCommand.stop(callback.sendPort));
        await callback.first.timeout(const Duration(seconds: 5));
      } catch (_) {
        // Safe fallback if worker died/failed to respond
        _isolate?.kill();
      } finally {
        callback.close();
      }
    } else {
      _isolate?.kill();
    }
    _isolate = null;
    _errorPort?.close();
    _errorPort = null;
    _commandPort = null;
  }
}
