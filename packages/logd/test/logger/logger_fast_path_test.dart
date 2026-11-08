import 'package:logd/logd.dart';
import 'package:test/test.dart';

void main() {
  group('Logger isLoggable & Fast-Path Filter Drops', () {
    setUp(() {
      Logger.reset();
      LoggerMetrics.reset();
    });

    tearDown(() {
      Logger.reset();
      LoggerMetrics.reset();
    });

    test('isLoggable accurately reflects enabled status and configured level',
        () {
      Logger.configure(
        'fast_logger',
        logLevel: LogLevel.warning,
        handlers: const [
          Handler(
            formatter: PlainFormatter(),
            sink: ConsoleSink(),
          ),
        ],
      );

      final logger = Logger.get('fast_logger');

      expect(logger.isLoggable(LogLevel.trace), isFalse);
      expect(logger.isLoggable(LogLevel.debug), isFalse);
      expect(logger.isLoggable(LogLevel.info), isFalse);
      expect(logger.isLoggable(LogLevel.warning), isTrue);
      expect(logger.isLoggable(LogLevel.error), isTrue);

      // Disable logger
      Logger.configure('fast_logger', enabled: false);
      expect(logger.isLoggable(LogLevel.warning), isFalse);
      expect(logger.isLoggable(LogLevel.error), isFalse);
    });

    test(
      'Filtered log methods bypass async pipeline and increment drops '
      'synchronously',
      () {
        final sink = MemorySink();
        Logger.configure(
          'bypass_test',
          logLevel: LogLevel.error,
          handlers: [
            Handler(
              formatter: const PlainFormatter(),
              sink: sink,
            ),
          ],
        );

        final logger = Logger.get('bypass_test');
        expect(LoggerMetrics.drops, equals(0));

        // Trace, Debug, Info, Warning are filtered at synchronous fast path.
        logger
          ..trace('should drop')
          ..debug('should drop')
          ..info('should drop')
          ..warning('should drop');

        expect(LoggerMetrics.drops, equals(4));
        expect(sink.entries, isEmpty);

        // Error passes fast-path guard
        logger.error('should pass');
        // Give microtask time to process
        expect(LoggerMetrics.drops, equals(4));
      },
    );

    test(
      'LogBuffer.sink() respects isLoggable and drops without pipeline '
      'overhead',
      () {
        final sink = MemorySink();
        Logger.configure(
          'buf_bypass',
          logLevel: LogLevel.warning,
          handlers: [
            Handler(
              formatter: const PlainFormatter(),
              sink: sink,
            ),
          ],
        );

        final logger = Logger.get('buf_bypass');
        final buf = logger.debugBuffer;
        expect(buf, isNotNull);

        buf!
          ..writeln('debug line in buffer')
          ..sink();

        expect(LoggerMetrics.drops, equals(1));
        expect(sink.entries, isEmpty);
      },
    );
  });
}
