import 'dart:async';
import 'dart:isolate';

import 'package:logd/logd.dart';
import 'package:test/test.dart';

base class IsolateTestSink extends LogSink<LogDocument> {
  const IsolateTestSink(this.port);
  final SendPort port;

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    port.send(entry.message);
  }
}

void main() {
  group('AsyncHandler Tests', () {
    setUp(() {
      Logger.reset();
    });

    test('should process and format logs on background isolate', () async {
      final receivePort = ReceivePort();
      final sink = IsolateTestSink(receivePort.sendPort);

      final asyncHandler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
      );

      final logger = Logger.get('async_logger');
      Logger.configure('async_logger', handlers: [asyncHandler]);

      logger.info('Hello from Async!');

      final completer = Completer<String>();
      receivePort.listen((final msg) {
        completer.complete(msg as String);
        receivePort.close();
      });

      final result = await completer.future.timeout(const Duration(seconds: 5));
      expect(result, equals('Hello from Async!'));

      await asyncHandler.dispose();
    });

    test('should respect handler level filters', () async {
      final receivePort = ReceivePort();
      final sink = IsolateTestSink(receivePort.sendPort);

      final asyncHandler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
        filters: const [
          ContextFilter('important', value: true),
        ],
      );

      final logger = Logger.get('filtered_async');
      Logger.configure('filtered_async', handlers: [asyncHandler]);

      // Should be filtered out
      logger
        ..info('Skip this')
        // Should log
        ..info('Log this', context: const {'important': true});

      final completer = Completer<String>();
      receivePort.listen((final msg) {
        completer.complete(msg as String);
        receivePort.close();
      });

      final result = await completer.future.timeout(const Duration(seconds: 5));
      expect(result, equals('Log this'));

      await asyncHandler.dispose();
    });

    test(
        'should handle dispose called immediately after instantiation '
        '(before ready)', () async {
      final receivePort = ReceivePort();
      final sink = IsolateTestSink(receivePort.sendPort);
      final asyncHandler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
      );
      // Immediately dispose, no await on ready
      await asyncHandler.dispose();
      receivePort.close();
    });

    test('should dispose cleanly while logs are being processed', () async {
      final receivePort = ReceivePort();
      final sink = IsolateTestSink(receivePort.sendPort);
      final asyncHandler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
      );
      final logger = Logger.get('async_inflight');
      Logger.configure('async_inflight', handlers: [asyncHandler]);

      logger.info('Log 1');
      await asyncHandler.dispose();
      receivePort.close();
    });

    test('should be idempotent on dispose', () async {
      final receivePort = ReceivePort();
      final sink = IsolateTestSink(receivePort.sendPort);
      final asyncHandler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
      );
      await asyncHandler.ready;
      await asyncHandler.dispose();
      // Second call should not throw
      await expectLater(asyncHandler.dispose(), completes);
      receivePort.close();
    });

    test('should ignore logs sent after dispose', () async {
      final receivePort = ReceivePort();
      final sink = IsolateTestSink(receivePort.sendPort);
      final asyncHandler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
      );
      await asyncHandler.ready;
      await asyncHandler.dispose();

      final logger = Logger.get('async_after_dispose');
      Logger.configure('async_after_dispose', handlers: [asyncHandler]);
      logger.info('Should not log');

      // Wait a short time to make sure nothing was sent/processed
      await Future<void>.delayed(const Duration(milliseconds: 100));
      receivePort.close();
    });

    test('should wait for ready and complete correctly', () async {
      final receivePort = ReceivePort();
      final sink = IsolateTestSink(receivePort.sendPort);
      final asyncHandler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
      );
      await asyncHandler.ready;

      final logger = Logger.get('async_ready');
      Logger.configure('async_ready', handlers: [asyncHandler]);
      logger.info('Ready check');

      final completer = Completer<String>();
      receivePort.listen((final msg) {
        completer.complete(msg as String);
        receivePort.close();
      });

      final result = await completer.future.timeout(const Duration(seconds: 5));
      expect(result, equals('Ready check'));
      await asyncHandler.dispose();
    });

    test(
        'should fall back to processing on main thread if LogEntry cannot '
        'be sent (non-sendable context)', () async {
      final receivePort = ReceivePort();
      final sink = IsolateTestSink(receivePort.sendPort);
      final asyncHandler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
      );
      await asyncHandler.ready;

      final logger = Logger.get('async_fallback');
      Logger.configure('async_fallback', handlers: [asyncHandler]);

      // Context has a local closure which is non-sendable in Dart
      void localClosure() {}
      logger.info('Fallback message', context: {'non_sendable': localClosure});

      final completer = Completer<String>();
      receivePort.listen((final msg) {
        completer.complete(msg as String);
        receivePort.close();
      });

      final result = await completer.future.timeout(const Duration(seconds: 5));
      expect(result, equals('Fallback message'));
      await asyncHandler.dispose();
    });

    test('should survive underlying sink dispose throwing an error', () async {
      final sink = ThrowingDisposeSink();
      final asyncHandler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
      );
      await asyncHandler.ready;
      await expectLater(asyncHandler.dispose(), completes);
    });

    test('AsyncHandler compares by identity even with equal configuration',
        () async {
      // ignore: prefer_const_constructors
      final h1 = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: const ConsoleSink(),
      );
      // ignore: prefer_const_constructors
      final h2 = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: const ConsoleSink(),
      );

      expect(
        h1 == h2,
        isFalse,
        reason: 'AsyncHandlers own distinct isolates and must not be equal',
      );
      expect(h1 == h1, isTrue);

      await h1.dispose();
      await h2.dispose();
    });

    test(
        'AsyncHandler bounds send queue and drops when '
        'maxQueueSize is exceeded', () async {
      LoggerMetrics.reset();
      final receivePort = ReceivePort();
      final sink = SlowBlockSink(receivePort.sendPort);

      final handler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
        maxQueueSize: 2,
      );
      await handler.ready;

      final logger = Logger.get('async_queue_test');
      Logger.configure('async_queue_test', handlers: [handler]);

      // Emit 10 logs rapidly while worker is delayed
      for (int i = 0; i < 10; i++) {
        logger.info('Rapid message $i');
      }

      await Future<void>.delayed(const Duration(milliseconds: 150));
      await handler.dispose();
      receivePort.close();

      expect(
        LoggerMetrics.drops,
        greaterThan(0),
        reason: 'Excess logs beyond maxQueueSize should increment drops metric',
      );
    });
  });
}

base class SlowBlockSink extends LogSink<LogDocument> {
  SlowBlockSink(this.port);
  final SendPort port;

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    port.send(entry.message);
  }
}

base class ThrowingDisposeSink extends LogSink<LogDocument> {
  ThrowingDisposeSink();

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {}

  @override
  Future<void> dispose() async {
    throw StateError('Simulated sink dispose failure');
  }
}
