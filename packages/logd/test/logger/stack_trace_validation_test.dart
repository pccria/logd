// ignore_for_file: cascade_invocations
import 'package:logd/logd.dart';
import 'package:logd/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Stack Tracing & Origin Validation Suite', () {
    setUp(() {
      Logger.reset();
    });

    group('1. Formatter Output Rendering Matrix', () {
      test('PlainFormatter: renders origin when true, omits cleanly when false',
          () async {
        final sinkWithOrigin = CaptureSink();
        final sinkWithoutOrigin = CaptureSink();

        Logger.configure(
          'plain.with',
          includeOrigin: true,
          handlers: [
            Handler(
              formatter: const PlainFormatter(
                metadata: {LogMetadata.origin, LogMetadata.logger},
              ),
              sink: sinkWithOrigin,
            ),
          ],
        );

        Logger.configure(
          'plain.without',
          includeOrigin: false,
          handlers: [
            Handler(
              formatter: const PlainFormatter(
                metadata: {LogMetadata.origin, LogMetadata.logger},
              ),
              sink: sinkWithoutOrigin,
            ),
          ],
        );

        Logger.get('plain.with').info('Hello With Origin');
        Logger.get('plain.without').info('Hello Without Origin');

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(sinkWithOrigin.logs.first.origin, isNotEmpty);
        expect(sinkWithoutOrigin.logs.first.origin, isEmpty);
        expect(
          sinkWithoutOrigin.logs.first.message,
          equals('Hello Without Origin'),
        );
      });

      test('StructuredFormatter: handles origin tag and brackets correctly',
          () async {
        final sink = CaptureSink();
        Logger.configure(
          'struct.test',
          includeOrigin: false,
          handlers: [
            Handler(
              formatter: const StructuredFormatter(),
              sink: sink,
            ),
          ],
        );

        Logger.get('struct.test').info('Structured log payload');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(sink.logs, hasLength(1));
        expect(sink.logs.first.origin, isEmpty);
        expect(sink.logs.first.message, equals('Structured log payload'));
      });

      test('JsonFormatter: includes origin key when true, omits key when false',
          () async {
        final sink = CaptureSink();
        Logger.configure(
          'json.no_origin',
          includeOrigin: false,
          handlers: [
            Handler(
              formatter: const JsonFormatter(),
              sink: sink,
            ),
          ],
        );

        Logger.get('json.no_origin').info('JSON log payload');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(sink.logs.first.origin, isEmpty);
      });

      test('PlainFormatter: omits origin line cleanly when empty', () async {
        final sink = CaptureSink();
        Logger.configure(
          'plain.no_origin',
          includeOrigin: false,
          handlers: [
            Handler(
              formatter: const PlainFormatter(),
              sink: sink,
            ),
          ],
        );

        Logger.get('plain.no_origin').info('Plain log payload');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(sink.logs.first.origin, isEmpty);
      });
    });

    group('2. Stack Method Count Invariants', () {
      test(
          'stackMethodCount > 0 extracts frames independently of includeOrigin',
          () async {
        final sink = CaptureSink();
        Logger.configure(
          'frames.test',
          includeOrigin: false,
          stackMethodCount: const {
            LogLevel.warning: 4,
            LogLevel.error: 8,
          },
          handlers: [
            Handler(
              formatter: const PlainFormatter(),
              sink: sink,
            ),
          ],
        );

        final logger = Logger.get('frames.test');
        logger.warning('Warning message');
        logger.error('Error message');

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(sink.logs, hasLength(2));

        // First log: Warning
        expect(sink.logs[0].level, equals(LogLevel.warning));
        expect(sink.logs[0].origin, isEmpty);

        // Second log: Error
        expect(sink.logs[1].level, equals(LogLevel.error));
        expect(sink.logs[1].origin, isEmpty);
      });
    });

    group('3. Explicit Error and StackTrace Preservation', () {
      test(
        'explicit error and stackTrace are fully preserved '
        'when includeOrigin is false',
        () async {
          final sink = CaptureSink();
          Logger.configure(
            'error.test',
            includeOrigin: false,
            handlers: [
              Handler(
                formatter: const PlainFormatter(),
                sink: sink,
              ),
            ],
          );

          final logger = Logger.get('error.test');
          final customError = StateError('Operation failed');
          final customStack = StackTrace.current;

          logger.error(
            'Failed execution',
            error: customError,
            stackTrace: customStack,
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(sink.logs, hasLength(1));
          final captured = sink.logs.first;

          expect(captured.level, equals(LogLevel.error));
          expect(captured.message, equals('Failed execution'));
          expect(captured.origin, isEmpty);
          expect(captured.error, equals(customError));
          expect(captured.stackTrace, equals(customStack));
        },
      );
    });

    group('4. includeFileLineInHeader Matrix', () {
      test('includeFileLineInHeader works when includeOrigin is true',
          () async {
        final sink = CaptureSink();
        Logger.configure(
          'fileline.test',
          includeOrigin: true,
          includeFileLineInHeader: true,
          handlers: [
            Handler(
              formatter: const PlainFormatter(),
              sink: sink,
            ),
          ],
        );

        Logger.get('fileline.test').info('Check file and line');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(sink.logs.first.origin, contains('.dart:'));
      });

      test(
        'includeFileLineInHeader is ignored cleanly when '
        'includeOrigin is false',
        () async {
          final sink = CaptureSink();
          Logger.configure(
            'fileline.no_origin',
            includeOrigin: false,
            includeFileLineInHeader: true,
            handlers: [
              Handler(
                formatter: const PlainFormatter(),
                sink: sink,
              ),
            ],
          );

          Logger.get('fileline.no_origin').info('Check empty origin');
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(sink.logs.first.origin, isEmpty);
        },
      );
    });
  });
}
