import 'dart:io';

import 'package:logd/logd.dart';
import 'package:test/test.dart';

import '../handler/test_helpers.dart';
import '../utils/log_snap.dart';

void main() {
  group('Formatter Goldens (Baseline)', () {
    final entry = LogEntry(
      loggerName: 'SnapTest',
      origin: 'snap.dart:10:5',
      level: LogLevel.info,
      message: 'This is a standard log message for golden verification.',
      timestamp: '2025-01-01 12:00:00',
    );

    final longEntry = LogEntry(
      loggerName: 'LongSnap',
      origin: 'long.dart',
      level: LogLevel.warning,
      message: 'A very long message that should trigger wrapping across '
          'multiple lines to verify structural integrity and spacing.',
      timestamp: '2025-01-01 12:00:01',
    );

    final formatters = {
      'Plain': const PlainFormatter(),
      'Structured': const StructuredFormatter(),
    };

    final widths = [80, 40, 20];

    for (final entryName in ['Standard', 'Long']) {
      final currentEntry = entryName == 'Standard' ? entry : longEntry;

      group('Entry: $entryName', () {
        for (final entry in formatters.entries) {
          final formatterName = entry.key;
          final formatter = entry.value;

          group('Formatter: $formatterName', () {
            for (final width in widths) {
              test('Width: $width', () {
                final doc = formatDoc(formatter, currentEntry);

                try {
                  final output = LogSnap.capture(
                    doc,
                    currentEntry.level,
                    width: width,
                    useAnsi:
                        false, // Plain text for goldens to avoid escape code
                    // noise
                  );

                  // Detect package root to avoid pollution when run from
                  // workspace root
                  final baseDir = File('lib/logd.dart').existsSync()
                      ? 'test/regression/goldens'
                      : 'packages/logd/test/regression/goldens';

                  final fileName = '${formatterName.toLowerCase()}_'
                      '${entryName.toLowerCase()}'
                      '_$width.txt';
                  final file =
                      File('$baseDir/${formatterName.toLowerCase()}/$fileName');

                  if (!file.existsSync()) {
                    file.parent
                        .createSync(recursive: true); // Ensure directory exists
                    file.writeAsStringSync(output);
                    print('Generated golden: ${file.path}');
                  } else {
                    final expected =
                        file.readAsStringSync().replaceAll('\r\n', '\n');
                    final normalizedOutput = output.replaceAll('\r\n', '\n');
                    expect(
                      normalizedOutput,
                      expected,
                      reason:
                          'Output mismatch for $formatterName | $entryName | '
                          '$width. '
                          'If this is an intentional change, delete the golden'
                          ' file and re-run.',
                    );
                  }
                } finally {
                  doc.releaseRecursive(Arena.instance);
                }
              });
            }
          });
        }
      });
    }
  });
}
