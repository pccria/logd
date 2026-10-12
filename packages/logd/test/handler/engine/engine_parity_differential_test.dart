import 'dart:convert';
import 'package:logd/logd.dart';
import 'package:test/test.dart';

base class TestEncodingSink extends EncodingSink {
  TestEncodingSink({required final int width}) : this._(width, <List<int>>[]);

  TestEncodingSink._(final int width, final List<List<int>> chunks)
      : byteChunks = chunks,
        super(
          encoder: const AnsiEncoder(),
          preferredWidth: width,
          delegate: (final data) {
            chunks.add(data);
          },
        );
  final List<List<int>> byteChunks;

  String get outputText {
    final sb = StringBuffer();
    for (final chunk in byteChunks) {
      sb.write(utf8.decode(chunk));
    }
    return sb.toString();
  }

  void clear() {
    byteChunks.clear();
  }
}

void main() {
  group('Differential Layout Parity Suite', () {
    // 1. Core Levels to verify styling parity
    final levels = [
      LogLevel.debug,
      LogLevel.info,
      LogLevel.warning,
      LogLevel.error,
    ];

    // 2. Terminal Widths to test wrap/border boundary calculations
    final widths = [20, 40, 80, 120];

    // 3. Formatters
    final formatters = {
      'Plain': const PlainFormatter(),
      'Structured': const StructuredFormatter(),
      'Json': const JsonFormatter(),
    };

    // 4. Decorators
    final decoratorCombinations = <String, List<LogDecorator>>{
      'None': [],
      'Prefix': [
        const PrefixDecorator('>>> '),
      ],
      'Suffix': [
        const SuffixDecorator(' <<<', aligned: false),
      ],
      'SuffixAligned': [
        const SuffixDecorator(' <<<', aligned: true),
      ],
      'RoundedBox': [
        const BoxDecorator(borderStyle: BorderStyle.rounded),
      ],
      'DoubleBox': [
        const BoxDecorator(borderStyle: BorderStyle.double),
      ],
      'HierarchyDepth': [
        const HierarchyDepthPrefixDecorator(indent: '| '),
      ],
      'ComposedComplex': [
        const HierarchyDepthPrefixDecorator(indent: '| '),
        const PrefixDecorator('>>> '),
        const BoxDecorator(borderStyle: BorderStyle.rounded),
        const SuffixDecorator(' <<<', aligned: true),
      ],
    };

    // 5. Payloads to stress wrapping and formatters
    final payloads = <String, LogEntry>{
      'SimpleSingleLine': LogEntry(
        loggerName: 'ParityTest',
        origin: 'main.dart:42',
        level: LogLevel.info,
        message: 'This is a simple single line message.',
        timestamp: '2026-06-12 12:00:00',
      ),
      'ExplicitNewlines': LogEntry(
        loggerName: 'ParityTest',
        origin: 'main.dart:101',
        level: LogLevel.warning,
        message: 'Line number one.\nLine number two.\nLine number three.',
        timestamp: '2026-06-12 12:01:00',
      ),
      'ExtremelyLongWrap': LogEntry(
        loggerName: 'ParityTest',
        origin: 'main.dart:505',
        level: LogLevel.debug,
        message:
            'This is an extremely long string that will exceed the maximum '
            'width of the terminal and force both layout engines to wrap words,'
            ' test alignment, indent wrapping lines correctly, and check the'
            ' border padding integrity under constraint.',
        timestamp: '2026-06-12 12:02:00',
      ),
      'WithErrorAndTrace': LogEntry(
        loggerName: 'ParityTest',
        origin: 'main.dart:999',
        level: LogLevel.error,
        message: 'A critical state failure has occurred!',
        error: StateError('Parity violation exception'),
        stackTrace: StackTrace.fromString(
          'main (test.dart:10:5)\nrun (test.dart:25:2)\nsetup (test.dart:42:1)',
        ),
        timestamp: '2026-06-12 12:03:00',
      ),
    };

    // Construct and run the matrix
    for (final level in levels) {
      for (final width in widths) {
        for (final formatterEntry in formatters.entries) {
          final formatterName = formatterEntry.key;
          final formatter = formatterEntry.value;

          for (final decoratorEntry in decoratorCombinations.entries) {
            final decoratorName = decoratorEntry.key;
            final decorators = decoratorEntry.value;

            for (final payloadEntry in payloads.entries) {
              final payloadName = payloadEntry.key;
              final originalEntry = payloadEntry.value;

              // Force the level to the current matrix test level
              final entry = LogEntry(
                loggerName: originalEntry.loggerName,
                origin: originalEntry.origin,
                level: level,
                message: originalEntry.message,
                error: originalEntry.error,
                stackTrace: originalEntry.stackTrace,
                timestamp: originalEntry.timestamp,
              );

              final testName = 'L:$level | W:$width | F:$formatterName | '
                  'D:$decoratorName | P:$payloadName';

              test(testName, () async {
                // Initialize sinks
                final stdSink = TestEncodingSink(width: width);
                final nativeSink = TestEncodingSink(width: width);

                // Initialize handlers
                final stdHandler = Handler(
                  formatter: formatter,
                  decorators: decorators,
                  sink: stdSink,
                  engine: const StandardEngine(),
                );

                final nativeHandler = Handler(
                  formatter: formatter,
                  decorators: decorators,
                  sink: nativeSink,
                  engine: NativeEngine(),
                );

                // Run Standard
                await stdHandler.log(entry);
                final stdOut = stdSink.outputText;

                // Run Native
                await nativeHandler.log(entry);
                final nativeOut = nativeSink.outputText;

                // Normalise and compare line-by-line for clear diff tracking
                final stdLines = stdOut.trimRight().split('\n');
                final nativeLines = nativeOut.trimRight().split('\n');

                expect(
                  nativeLines.length,
                  stdLines.length,
                  reason: 'Mismatch in line counts. '
                      'Standard had ${stdLines.length} lines, Native had '
                      '${nativeLines.length} lines.\n'
                      'Standard:\n$stdOut\n'
                      'Native:\n$nativeOut',
                );

                for (int i = 0; i < stdLines.length; i++) {
                  expect(
                    nativeLines[i],
                    stdLines[i],
                    reason: 'Rendering mismatch on line $i.\n'
                        'Standard:\n$stdOut\n'
                        'Native:\n$nativeOut',
                  );
                }
              });
            }
          }
        }
      }
    }
  });
}
