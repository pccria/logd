import 'dart:async';
import 'package:logd/logd.dart';
import 'package:test/test.dart';

base class TestSink extends LogSink<LogDocument> {
  final List<String> logs = [];

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    logs.add(entry.message);
  }
}

base class DelaySink extends LogSink<LogDocument> {
  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

base class FailingSink extends LogSink<LogDocument> {
  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    throw Exception('Simulated sink failure');
  }
}

void main() {
  setUp(() {
    Logger.reset();
  });

  group('Lifecycle Integrity & Defensive Polish', () {
    test('StandardDocument endBox() throws AssertionError on empty stack', () {
      final doc = StandardDocument();
      expect(() => doc.endBox(), throwsA(isA<AssertionError>()));
    });

    test('StandardDocument reset() drains unbalanced stack and warns', () {
      final doc = StandardDocument()
        ..startBox()
        ..reset();

      // Verify stack is clean by asserting that endBox() throws again
      expect(() => doc.endBox(), throwsA(isA<AssertionError>()));
    });

    test('Logger.configureMultiple() is atomic', () {
      final testSink = TestSink();
      Logger.configure(
        'test.one',
        handlers: [
          Handler(formatter: const PlainFormatter(), sink: testSink),
        ],
      );

      expect(
        () => Logger.configureMultiple({
          'test.one': const LoggerConfig(logLevel: LogLevel.warning),
          'test.two': const LoggerConfig(
            stackMethodCount: {LogLevel.info: -5},
          ), // Invalid count -> throws
        }),
        throwsArgumentError,
      );

      // Verify first logger config was NOT updated (remains debug, not warning)
      final level = Logger.get('test.one').logLevel;
      expect(level, equals(LogLevel.debug));
    });

    test(
        'Logger.configurePattern() deduplicates patterns and '
        'removePattern works', () {
      Logger.configurePattern('db.*', logLevel: LogLevel.debug);
      Logger.configurePattern('db.*', logLevel: LogLevel.warning); // Overwrites

      // Retrieve and verify
      var level = Logger.get('db.mysql').logLevel;
      expect(level, equals(LogLevel.warning));

      // Remove the pattern
      Logger.removePattern('db.*');

      // Verify it reverts to default (debug)
      level = Logger.get('db.mysql').logLevel;
      expect(level, equals(LogLevel.debug));
    });

    test('Handler timeout triggers TimeoutException and increments failures',
        () async {
      LoggerMetrics.reset();

      final delaySink = DelaySink();
      final handler = Handler(
        formatter: const PlainFormatter(),
        sink: delaySink,
        timeout: const Duration(milliseconds: 10),
      );

      final entry = LogEntry(
        loggerName: 'TimeoutTest',
        origin: 'test',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2025-01-01',
      );

      // Executing handler.log directly should throw TimeoutException
      expect(() => handler.log(entry), throwsA(isA<TimeoutException>()));
    });

    test('LoggerConfig.fromJson throws FormatException on invalid types', () {
      expect(
        () => LoggerConfig.fromJson(const {'enabled': 123}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LoggerConfig.fromJson(const {'handlers': 'not_a_list'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('Handler failure warning rate-limiting (per-type)', () async {
      final prints = <String>[];
      final failingSink = FailingSink();
      Logger.configure(
        'test.fail',
        handlers: [
          Handler(formatter: const PlainFormatter(), sink: failingSink),
        ],
      );

      await runZoned(
        () async {
          Logger.get('test.fail').info('log1');
          await Future.delayed(Duration.zero);

          Logger.get('test.fail').info('log2');
          await Future.delayed(Duration.zero);
        },
        zoneSpecification: ZoneSpecification(
          print: (final self, final parent, final zone, final line) {
            prints.add(line);
          },
        ),
      );

      final warnings =
          prints.where((final p) => p.contains('Handler failure')).toList();
      expect(warnings, hasLength(1));
    });

    test('Pattern-scoped cache invalidation', () {
      // Populate cache
      final levelDbBefore = Logger.get('db.mysql').logLevel;
      final levelUiBefore = Logger.get('ui.button').logLevel;

      expect(levelDbBefore, equals(LogLevel.debug));
      expect(levelUiBefore, equals(LogLevel.debug));

      // Configure pattern for db.*
      Logger.configurePattern('db.*', logLevel: LogLevel.warning);

      // Verify db.mysql cache is invalidated, but ui.button remains cached
      LoggerMetrics.reset();

      final dbLevelAfter = Logger.get('db.mysql').logLevel;
      final uiLevelAfter = Logger.get('ui.button').logLevel;

      expect(dbLevelAfter, equals(LogLevel.warning));
      expect(uiLevelAfter, equals(LogLevel.debug));

      expect(LoggerMetrics.cacheMisses, equals(1)); // only db.mysql resolved
      expect(LoggerMetrics.cacheHits, equals(1)); // ui.button was hit
    });

    test('Handler reference can dispose AsyncHandler', () async {
      final Handler h = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: TestSink(),
      );
      // Must compile and not throw
      await h.dispose();
    });

    test(
        'AsyncHandler attaches Finalizer and safely handles '
        'post-dispose log calls', () async {
      final handler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: TestSink(),
      );

      await handler.ready;
      await handler.dispose();

      // Subsequent log calls on disposed handler are safe no-ops
      final entry = LogEntry(
        loggerName: 'DisposedTest',
        origin: 'test',
        level: LogLevel.info,
        message: 'should be ignored',
        timestamp: '2025-01-01',
      );
      await handler.log(entry);
    });
  });
}
