library;

import 'dart:async';
import 'dart:io' as io;
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../../logger/logger.dart';
import '../handler.dart';
import 'isolate_protocol.dart';
import 'isolate_worker.dart';

/// A [Handler] that offloads the execution of the logging pipeline
/// (formatting, decorating, and sinking) to a background worker isolate.
///
/// ### Architecture & Concurrency
/// When instantiated, [AsyncHandler] spawns a dedicated background isolate.
/// Any log events logged through this handler are sent as message payloads
/// across a [SendPort] boundary. The background isolate listens to these
/// events, processes them sequentially on its own event loop, and outputs
/// them to the underlying [sink].
///
/// ### Performance Characteristics
/// * **Unblocked Main Thread**: Since layout formatting, decorating, and
///   physical I/O are performed off-thread, logging calls return almost
///   instantly (~15–20µs), maximizing main thread throughput.
/// * **Throughput vs. Latency**: Ideal for applications with high-frequency
///   logging or slow physical sinks (e.g., files, HTTP dashboards). However,
///   it introduces minor overhead due to thread context-switching and object
///   serialization.
///
/// ### Isolate Copy/Transfer Constraints
/// Because the pipeline runs in a separate isolate, all parameters (the
/// [formatter], [sink], and [decorators]) must be sendable. Sinks with
/// non-transferable native assets or open TCP sockets must handle
/// isolate-aware setup or use custom serialization handles.
///
/// ### Lifecycle Management
/// It is critical to call [dispose] when this handler is no longer needed.
/// [dispose] safely closes the isolate control ports, flushes the background
/// worker queues, disposes of the underlying [sink], and terminates the
/// worker isolate to prevent resource leaks.
base class AsyncHandler extends Handler {
  /// Creates an [AsyncHandler] that delegates pipeline execution to a
  /// background isolate.
  ///
  /// - [formatter]: The formatter used to translate logs into semantic
  ///   documents.
  /// - [sink]: The final output sink.
  /// - [filters]: Optional filters to block events before isolate boundary
  ///   crossing.
  /// - [decorators]: Optional decorators for document layout enrichment.
  /// - [engine]: The execution engine to run on the background isolate
  /// - [timeout]: Optional timeout boundary for pipeline processing.
  /// - [maxQueueSize]: Maximum pending entries allowed in background queue
  ///   before excess entries are dropped (defaults to 10,000). Set <= 0 for
  ///   unbounded.
  AsyncHandler({
    required final LogFormatter formatter,
    required final LogSink sink,
    final List<LogFilter> filters = const [],
    final List<LogDecorator> decorators = const [],
    final LogEngine engine = const StandardEngine(),
    final Duration? timeout,
    final int maxQueueSize = 10000,
  }) : this._internal(
          formatter: formatter,
          sink: sink,
          filters: filters,
          decorators: decorators,
          engine: engine,
          timeout: timeout,
          maxQueueSize: maxQueueSize,
          ackPort: ReceivePort(),
        );

  AsyncHandler._internal({
    required super.formatter,
    required super.sink,
    required super.filters,
    required super.decorators,
    required super.engine,
    required super.timeout,
    required this.maxQueueSize,
    required final ReceivePort ackPort,
  })  : _ackPort = ackPort,
        _worker = IsolateWorker(
          entryPoint: _spawnWorker,
          initArg: [
            formatter,
            sink,
            decorators,
            engine,
            timeout,
            ackPort.sendPort,
          ],
          debugName: 'AsyncHandler',
        ) {
    _finalizer.attach(this, _worker, detach: this);
    _ackPort.listen((final count) {
      if (count is int) {
        _pendingTracker.count =
            (_pendingTracker.count - count).clamp(0, 1000000000);
      }
    });
    _start();
  }

  static final Finalizer<IsolateWorker> _finalizer =
      Finalizer<IsolateWorker>((final worker) {
    InternalLogger.log(
      LogLevel.warning,
      'AsyncHandler leak detected! '
      'Handler garbage-collected without dispose(). '
      'Background isolate shutting down gracefully. '
      'Call dispose() explicitly to flush pending log entries and close '
      'resources gracefully.',
    );
    unawaited(worker.dispose());
  });

  /// Maximum pending entries allowed in background queue before drops occur.
  final int maxQueueSize;

  final ReceivePort _ackPort;
  final _PendingTracker _pendingTracker = _PendingTracker();

  final IsolateWorker _worker;

  /// A future that completes when the background isolate worker is ready.
  Future<void> get ready => _worker.ready;

  Future<void> _start() async {
    await _worker.start();
  }

  @override
  @internal
  Future<void> log(final LogEntry entry) async {
    if (_worker.isDisposed) {
      return;
    }

    if (filters.any((final filter) => !filter.shouldLog(entry))) {
      return;
    }

    if (!_worker.isReady) {
      await _worker.ready;
    }

    final port = _worker.commandPort;
    if (port != null) {
      if (maxQueueSize > 0 && _pendingTracker.count >= maxQueueSize) {
        LoggerMetrics.incrementDrops();
        return;
      }
      try {
        _pendingTracker.count++;
        port.send(entry);
        return;
      } catch (e, s) {
        _pendingTracker.count--;
        // Output to stderr to ensure this silent fallback is visible
        io.stderr.writeln(
          'AsyncHandler: Failed to send LogEntry to background isolate. '
          'Processing on caller thread. Error: $e',
        );
        InternalLogger.log(
          LogLevel.warning,
          'AsyncHandler: Failed to send LogEntry to background isolate. '
          'Processing on caller isolate.',
          error: e,
          stackTrace: s,
        );
      }
    }

    if (timeout != null) {
      await engine
          .execute(
            entry,
            formatter,
            decorators,
            sink,
          )
          .timeout(timeout!);
    } else {
      await engine.execute(
        entry,
        formatter,
        decorators,
        sink,
      );
    }
  }

  /// Flushes in-flight log operations on the background worker isolate.
  @override
  Future<void> flush() async {
    await super.flush();
    if (_worker.isDisposed) {
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
        // Safe fallback on timeout or worker issue
      } finally {
        callback.close();
      }
    }
  }

  /// Disposes of the background isolate and releases any associated resources.
  @override
  Future<void> dispose() async {
    _finalizer.detach(this);
    await flush();
    await _worker.dispose();
    _ackPort.close();
    await super.dispose();
  }

  @override
  bool operator ==(final Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);

  static void _spawnWorker(final List<dynamic> args) {
    unawaited(
      () async {
        final sendPort = args[0] as SendPort;
        final configArgs = args[1] as List<dynamic>;

        final formatter = configArgs[0] as LogFormatter;
        final sink = configArgs[1] as LogSink;
        final decorators = configArgs[2] as List<LogDecorator>;
        final engine = configArgs[3] as LogEngine;
        final timeout = configArgs[4] as Duration?;
        final ackPort =
            configArgs.length > 5 ? configArgs[5] as SendPort? : null;

        final receivePort = ReceivePort();
        sendPort.send(receivePort.sendPort);

        int processedSinceLastAck = 0;

        await for (final message in receivePort) {
          if (message is LogEntry) {
            try {
              if (timeout != null) {
                await engine
                    .execute(
                      message,
                      formatter,
                      decorators,
                      sink,
                    )
                    .timeout(timeout);
              } else {
                await engine.execute(
                  message,
                  formatter,
                  decorators,
                  sink,
                );
              }
            } catch (e, s) {
              InternalLogger.log(
                LogLevel.error,
                'AsyncHandler worker pipeline execution failed',
                error: e,
                stackTrace: s,
              );
            } finally {
              processedSinceLastAck++;
              if (processedSinceLastAck >= 64) {
                ackPort?.send(processedSinceLastAck);
                processedSinceLastAck = 0;
              }
            }
          } else if (message is IsolateCommand) {
            if (processedSinceLastAck > 0) {
              ackPort?.send(processedSinceLastAck);
              processedSinceLastAck = 0;
            }
            if (message.type == IsolateCommandType.flush) {
              try {
                await sink.flush();
              } catch (e, s) {
                InternalLogger.log(
                  LogLevel.error,
                  'AsyncHandler worker sink flush failed',
                  error: e,
                  stackTrace: s,
                );
              } finally {
                message.replyPort?.send(null);
              }
            } else if (message.type == IsolateCommandType.stop) {
              try {
                await sink.dispose();
              } catch (e, s) {
                InternalLogger.log(
                  LogLevel.error,
                  'AsyncHandler worker sink disposal failed',
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

final class _PendingTracker {
  int count = 0;
}
