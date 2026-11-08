import 'package:logd/logd.dart';
import 'package:logd/testing.dart';
import 'package:test/test.dart';

final class _FailingSink extends LogSink<LogDocument> {
  _FailingSink(this.errorToThrow);
  final Exception errorToThrow;

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    throw errorToThrow;
  }
}

void main() {
  group('Core Resilience & Invalidation Fixes', () {
    tearDown(() {
      Logger.reset();
    });

    test('explicit stack trace does not skip frame 0 (the throw site)',
        () async {
      final testLogger = TestLogger('test.stack');
      addTearDown(testLogger.dispose);

      final explicitTrace = StackTrace.fromString(
        '#0   crashSite (package:demo/crash.dart:42:10)\n'
        '#1   helper (package:demo/helper.dart:10:5)\n'
        '#2   main (package:demo/main.dart:5:1)',
      );

      testLogger.logger.error('failure', stackTrace: explicitTrace);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(testLogger.logs, hasLength(1));
      // Frame 0 is crashSite - must NOT be skipped when trace is explicit
      expect(testLogger.logs.first.origin, contains('crashSite'));
    });

    test('MemorySink instance inequality allows reconfiguration with new sink',
        () {
      final sink1 = MemorySink();
      Logger.configure(
        'test.mem',
        handlers: [
          Handler(
            formatter: const PlainFormatter(),
            sink: sink1,
          ),
        ],
      );

      Logger.get('test.mem').info('entry 1');
      expect(sink1.entries, hasLength(1));

      // Reconfigure with a fresh MemorySink instance
      final sink2 = MemorySink();
      expect(
        sink1 == sink2,
        isFalse,
        reason: 'Distinct stateful MemorySink instances must not be equal',
      );

      Logger.configure(
        'test.mem',
        handlers: [
          Handler(
            formatter: const PlainFormatter(),
            sink: sink2,
          ),
        ],
      );

      Logger.get('test.mem').info('entry 2');

      // The new sink must have received the new entry
      expect(sink2.entries, hasLength(1));
      expect(sink2.entries.first.message, equals('entry 2'));
    });

    test('StackTraceParser equality accounts for symbolResolver', () {
      final parser1 = StackTraceParser(
        symbolResolver: (final symbol) => 'symbol_A',
      );
      final parser2 = StackTraceParser(
        symbolResolver: (final symbol) => 'symbol_B',
      );
      const parserNoResolver = StackTraceParser();

      expect(parser1 == parser2, isFalse);
      expect(parser1 == parserNoResolver, isFalse);
      expect(parser1.hashCode == parser2.hashCode, isFalse);
    });

    test(
      'importConfig rebuilds descendants so child loggers '
      'follow parent updates',
      () {
        Logger.reset();
        Logger.configure('app', logLevel: LogLevel.info);
        Logger.configure('app.ui', includeOrigin: false);

        final exported = Logger.exportConfig();
        Logger.reset();
        Logger.importConfig(exported);

        // Initially app.ui inherits LogLevel.info from app
        expect(Logger.get('app.ui').logLevel, equals(LogLevel.info));

        // Reconfigure parent app to LogLevel.error
        Logger.configure('app', logLevel: LogLevel.error);

        // Child app.ui must invalidate and inherit parent's new level
        expect(Logger.get('app.ui').logLevel, equals(LogLevel.error));
      },
    );

    test('MultiSink rethrows when all enabled child sinks fail', () async {
      final sinkA = _FailingSink(Exception('Disk write failure'));
      final sinkB = _FailingSink(Exception('Network timeout'));
      final multiSink = MultiSink([sinkA, sinkB]);

      final doc = Arena.instance.checkoutDocument();
      doc.nodes.add(
        Arena.instance.checkoutMessage()
          ..segments.add(const StyledText('critical')),
      );
      final entry = LogEntry(
        loggerName: 'test',
        level: LogLevel.error,
        message: 'critical message',
        timestamp: '2026-11-02',
        origin: 'main',
      );

      expect(
        () => multiSink.output(
          doc,
          entry,
          LogLevel.error,
          const StandardPipelineFactory(),
        ),
        throwsA(isA<Exception>()),
      );

      doc.releaseRecursive(Arena.instance);
      Arena.instance.releaseLogEntry(entry);
    });
  });
}
