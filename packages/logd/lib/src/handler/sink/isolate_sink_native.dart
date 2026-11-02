library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../logger/logger.dart';
import '../document/binary_ir_native.dart';
import '../document/document.dart';
import '../engine/arena_native.dart';
import '../engine/engine.dart';
import '../engine/isolate_protocol.dart';
import '../engine/isolate_worker.dart';
import '../engine/native_engine_native.dart';
import '../sink/sink.dart';

/// A [LogSink] wrapper that offloads I/O operations to a background isolate.
///
/// This ensures that the main application thread never blocks on disk or
/// network I/O. It uses [TransferableTypedData] to minimize memory pressure
/// during isolate communication.
@experimental
base class IsolateSink extends LogSink<Uint8List> {
  /// Creates an [IsolateSink] that wraps the [target] sink.
  ///
  /// The [target] sink will be moved to a background isolate.
  ///
  /// WARNING: The [target] sink and all its dependencies must be sendable
  /// across isolates. This means they cannot contain non-static closures or
  /// native resources (unless they are handled via [SendPort] themselves).
  IsolateSink(this.target)
      : _worker = IsolateWorker(
          entryPoint: _spawnWorker,
          initArg: target,
          debugName: 'IsolateSink',
        ),
        super(enabled: target.enabled) {
    _start();
  }

  /// The underlying sink that will perform the actual I/O in the isolate.
  final LogSink<Uint8List> target;

  final IsolateWorker _worker;

  Future<void> _start() async {
    await _worker.start();
  }

  @override
  Future<void> output(
    final Uint8List data,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    if (!enabled || _worker.isDisposed) {
      return;
    }

    if (!_worker.isReady) {
      await _worker.ready;
    }

    // To ensure the main thread can immediately reuse the pooled buffer
    // from Arena, we must perform exactly one copy here.
    // We then use TransferableTypedData to ensure that sending this copy
    // to the worker isolate does not involve a second copy.
    final copy = Uint8List.fromList(data);
    final transferable = TransferableTypedData.fromList([copy]);

    _worker.send(
      IsolateLog(
        data: transferable,
        entry: entry,
        level: level,
      ),
    );
  }

  @override
  Future<void> flush() async {
    if (!enabled || _worker.isDisposed) {
      return;
    }
    if (!_worker.isReady) {
      await _worker.ready;
    }
    final port = _worker.commandPort;
    if (port != null) {
      final callback = ReceivePort();
      try {
        port.send(IsolateCommand.flush(callback.sendPort));
        await callback.first.timeout(const Duration(seconds: 5));
      } catch (_) {
        // Fallback if timeout or worker error
      } finally {
        callback.close();
      }
    }
  }

  @override
  Future<void> dispose() async {
    await flush();
    await _worker.dispose();
    await super.dispose();
  }

  static void _spawnWorker(final List<dynamic> args) {
    unawaited(
      () async {
        final sendPort = args[0] as SendPort;
        final target = args[1] as LogSink<Uint8List>;

        final receivePort = ReceivePort();
        sendPort.send(receivePort.sendPort);

        await for (final message in receivePort) {
          if (message is IsolateLog) {
            try {
              final data = message.data.materialize().asUint8List();
              const factory = StandardPipelineFactory();
              await target.output(data, message.entry, message.level, factory);
            } catch (e, s) {
              InternalLogger.log(
                LogLevel.error,
                'IsolateSink target output failed',
                error: e,
                stackTrace: s,
              );
            }
          } else if (message is IsolateCommand) {
            if (message.type == IsolateCommandType.flush) {
              try {
                await target.flush();
              } catch (e, s) {
                InternalLogger.log(
                  LogLevel.error,
                  'IsolateSink target flush failed',
                  error: e,
                  stackTrace: s,
                );
              } finally {
                message.replyPort?.send(null);
              }
            } else if (message.type == IsolateCommandType.stop) {
              try {
                await target.dispose();
              } catch (e, s) {
                InternalLogger.log(
                  LogLevel.error,
                  'IsolateSink target disposal failed',
                  error: e,
                  stackTrace: s,
                );
              } finally {
                message.replyPort?.send(null);
                receivePort.close();
              }
            }
          }
        }
      }(),
    );
  }
}

@internal
class IsolateLog {
  IsolateLog({
    required this.data,
    required this.entry,
    required this.level,
  });
  final TransferableTypedData data;
  final LogEntry entry;
  final LogLevel level;
}

/// A specialized [LogSink] that offloads Native B-IR rendering and I/O
/// to a background isolate.
///
/// Use [NativeIsolateSink] when using [NativeEngine] to achieve zero-latency
/// logging on the main thread.
@experimental
base class NativeIsolateSink extends LogSink<dynamic> {
  /// Creates a [NativeIsolateSink] wrapping the [target].
  NativeIsolateSink(this.target) : super(enabled: target.enabled) {
    _start();
  }

  /// The underlying sink that performs the final byte I/O.
  final EncodingSink target;

  late IsolateWorker _worker;

  /// Exposes the background worker Isolate for testing.
  @visibleForTesting
  Isolate? get isolate => _worker.isolate;

  final List<Object> _buffer = [];
  bool _workerDead = false;

  /// Exposes whether the worker has crashed/died.
  @visibleForTesting
  bool get workerDead => _workerDead;

  bool _isDisposed = false;
  bool _bufferOverflowWarningFired = false;
  static const int _maxPreReadyBuffer = 200;

  Future<void> _start() async {
    _workerDead = false;
    _worker = IsolateWorker(
      entryPoint: spawnNativeWorker,
      initArg: target,
      debugName: 'NativeIsolateSink',
      onWorkerError: (final _) {
        Arena.instance.reclaimInFlightBuffers();
        _workerDead = true;

        // Attempt to restart if not disposed
        if (!_isDisposed) {
          Future.delayed(const Duration(seconds: 2), () {
            if (!_isDisposed) {
              _start();
            }
          });
        }
      },
    );

    await _worker.start();

    // Flush buffer
    for (final msg in _buffer) {
      _worker.send(msg);
    }
    _buffer.clear();
  }

  /// Dispatches a [NativePacket] directly to the worker isolate.
  ///
  /// This method bypasses the standard [output] path and is called
  /// by the [NativeEngine].
  @internal
  void dispatchPacket(final NativePacket packet) {
    if (_workerDead || !enabled) {
      packet.completionPort.send(packet.address);
      return;
    }
    if (_worker.isReady) {
      _worker.send(packet);
    } else {
      if (_buffer.length >= _maxPreReadyBuffer) {
        final dropped = _buffer.removeAt(0);
        if (dropped is NativePacket) {
          dropped.completionPort.send(dropped.address);
        }
        if (!_bufferOverflowWarningFired) {
          _bufferOverflowWarningFired = true;
          InternalLogger.log(
            LogLevel.warning,
            'NativeIsolateSink buffer overflowed. '
            'Dropping oldest native packets.',
          );
        }
      }
      _buffer.add(packet);
    }
  }

  @override
  Future<void> output(
    final dynamic data,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    if (!enabled || _workerDead) {
      return;
    }

    if (data is LogDocument) {
      final context = factory.checkoutContext();
      try {
        target.encoder.encode(
          entry,
          data,
          level,
          context,
          factory,
          width: target.preferredWidth,
        );
        final bytes = context.takeBytes();
        _sendBytes(bytes, entry, level);
      } finally {
        factory.release(context);
      }
    } else if (data is Uint8List) {
      _sendBytes(data, entry, level);
    }
  }

  void _sendBytes(
    final Uint8List data,
    final LogEntry entry,
    final LogLevel level,
  ) {
    if (_workerDead) {
      return;
    }
    final copy = Uint8List.fromList(data);
    final transferable = TransferableTypedData.fromList([copy]);
    final msg = IsolateLog(
      data: transferable,
      entry: entry,
      level: level,
    );

    if (_worker.isReady) {
      _worker.send(msg);
    } else {
      if (_buffer.length >= _maxPreReadyBuffer) {
        _buffer.removeAt(0);
        if (!_bufferOverflowWarningFired) {
          _bufferOverflowWarningFired = true;
          InternalLogger.log(
            LogLevel.warning,
            'NativeIsolateSink buffer overflowed. Dropping oldest log entries.',
          );
        }
      }
      _buffer.add(msg);
    }
  }

  @override
  Future<void> flush() async {
    if (!enabled || _workerDead || _worker.isDisposed) {
      return;
    }
    if (!_worker.isReady) {
      await _worker.ready;
    }
    final port = _worker.commandPort;
    if (port != null) {
      final callback = ReceivePort();
      try {
        port.send(IsolateCommand.flush(callback.sendPort));
        await callback.first.timeout(const Duration(seconds: 5));
      } catch (_) {
        // Fallback if timeout or worker error
      } finally {
        callback.close();
      }
    }
  }

  @override
  Future<void> dispose() async {
    await flush();
    _isDisposed = true;
    await _worker.dispose();
    for (final msg in _buffer) {
      if (msg is NativePacket) {
        msg.completionPort.send(msg.address);
      }
    }
    _buffer.clear();
    Arena.instance.reclaimInFlightBuffers();
    await super.dispose();
  }
}
