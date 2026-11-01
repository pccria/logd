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
  ///   (defaults to [StandardEngine]).
  /// - [timeout]: Optional timeout boundary for pipeline processing.
  AsyncHandler({
    required super.formatter,
    required super.sink,
    super.filters = const [],
    super.decorators = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : _worker = IsolateWorker(
          entryPoint: _spawnWorker,
          initArg: [
            formatter,
            sink,
            decorators,
            engine,
            timeout,
          ],
          debugName: 'AsyncHandler',
        ) {
    _finalizer.attach(this, _worker, detach: this);
    _start();
  }

  static final Finalizer<IsolateWorker> _finalizer =
      Finalizer<IsolateWorker>((final worker) {
    InternalLogger.log(
      LogLevel.warning,
      'AsyncHandler leak detected! '
      'Handler garbage-collected without dispose(). '
      'Background isolate terminated immediately. '
      'Call dispose() explicitly to flush pending log entries and close '
      'resources gracefully.',
    );
    worker.kill();
  });

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
      try {
        port.send(entry);
        return;
      } catch (e, s) {
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
    await super.dispose();
  }

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

        final receivePort = ReceivePort();
        sendPort.send(receivePort.sendPort);

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
            }
          } else if (message is IsolateCommand) {
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
