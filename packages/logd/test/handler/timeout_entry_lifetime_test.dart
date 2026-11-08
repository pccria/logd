import 'dart:async';

import 'package:logd/logd.dart';
import 'package:test/test.dart';

base class _SlowInspectingSink extends LogSink<LogDocument> {
  String? capturedMessage;
  Map<String, dynamic>? capturedContext;
  final Completer<void> completedCompleter = Completer<void>();

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    // Simulate slow I/O or stalled sink
    await Future.delayed(const Duration(milliseconds: 50));
    capturedMessage = entry.message;
    capturedContext = entry.context != null
        ? Map<String, dynamic>.from(entry.context!)
        : null;
    if (!completedCompleter.isCompleted) {
      completedCompleter.complete();
    }
  }
}

base class _PassThroughSink extends LogSink<LogDocument> {
  LogEntry? receivedEntry;

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    receivedEntry = entry;
  }
}

void main() {
  setUp(() {
    Logger.reset();
  });

  tearDown(() {
    Logger.reset();
  });

  group('LogEntry.clone', () {
    test('accurately clones all fields and pre-cached hierarchy depth', () {
      final original = LogEntry(
        loggerName: 'net.http.client',
        origin: 'Client.get',
        level: LogLevel.warning,
        message: 'Request timeout',
        timestamp: '2026-11-02T12:00:00Z',
        error: StateError('Connection dropped'),
        stackTrace: StackTrace.current,
        context: {'requestId': 'req-123', 'retries': 3},
      );

      // Trigger hierarchy depth calculation to populate cache
      expect(original.hierarchyDepth, equals(3));

      final cloned = original.clone();

      expect(cloned.loggerName, equals(original.loggerName));
      expect(cloned.origin, equals(original.origin));
      expect(cloned.level, equals(original.level));
      expect(cloned.message, equals(original.message));
      expect(cloned.timestamp, equals(original.timestamp));
      expect(cloned.error, equals(original.error));
      expect(cloned.stackTrace, equals(original.stackTrace));
      expect(cloned.context, equals(original.context));
      expect(cloned.hierarchyDepth, equals(3));

      // Mutating cloned context should not alter original
      cloned.context!['newKey'] = 'value';
      expect(original.context!.containsKey('newKey'), isFalse);

      // Resetting original should not mutate clone
      original.reset();
      expect(cloned.message, equals('Request timeout'));
      expect(cloned.loggerName, equals('net.http.client'));
    });
  });

  group('Timeout Entry Lifetime Guard', () {
    test(
      'passes original LogEntry directly when timeout is null '
      '(zero-allocation fast path)',
      () async {
        final sink = _PassThroughSink();
        final handler = Handler(
          formatter: const PlainFormatter(),
          sink: sink,
          timeout: null,
        );

        final entry = LogEntry(
          loggerName: 'test.fastpath',
          origin: 'test',
          level: LogLevel.info,
          message: 'direct pass',
          timestamp: '2026-11-02T12:00:00Z',
        );

        await handler.log(entry);

        expect(identical(sink.receivedEntry, entry), isTrue);
      },
    );

    test(
      'clones LogEntry on timed-out handler so background completion '
      'does not observe pooled reset',
      () async {
        final sink = _SlowInspectingSink();
        final handler = Handler(
          formatter: const PlainFormatter(),
          sink: sink,
          timeout: const Duration(milliseconds: 15),
        );

        final logger = Logger.get('test.timeout');
        Logger.configure(
          'test.timeout',
          handlers: [handler],
        );

        // First log will time out after 15ms
        logger.info(
          'Initial message',
          context: {'session': 's1'},
        );

        // Wait past the 15ms timeout so logInternal completes and releases
        // entry to pool
        await Future.delayed(const Duration(milliseconds: 25));

        // Trigger second log to checkout and mutate the recycled entry
        logger.info(
          'Subsequent message',
          context: {'session': 's2'},
        );

        // Wait for background sink from first log to finish its 50ms delay
        await sink.completedCompleter.future.timeout(
          const Duration(seconds: 2),
        );

        // The background sink from the first log should have captured
        // 'Initial message' and context {'session': 's1'}, NOT
        // 'Subsequent message' or an empty string from entry.reset()
        expect(sink.capturedMessage, equals('Initial message'));
        expect(sink.capturedContext, equals({'session': 's1'}));
      },
    );
  });
}
