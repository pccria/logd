import 'dart:io';

import 'package:logd/logd.dart'
    hide Arena, ArenaDocument, ArenaEngine, FileSink, IsolateSink, NativeEngine;
import 'package:logd/src/handler/document/binary_ir_native.dart';
import 'package:logd/src/handler/engine/arena_native.dart';
import 'package:test/test.dart';

void main() {
  group('Binary IR Goldens (Native Parity)', () {
    final entry = LogEntry(
      loggerName: 'BinarySnap',
      origin: 'binary.dart:42',
      level: LogLevel.info,
      message:
          'Verified Binary IR rendering with semantic coloring and alignment.',
      timestamp: '2025-01-01 12:00:00',
    );

    final errorEntry = LogEntry(
      loggerName: 'BinaryError',
      origin: 'error.dart:1',
      level: LogLevel.error,
      message: 'Critical system failure detected in the binary pipeline!',
      timestamp: '2025-01-01 12:00:05',
    );

    final formatters = {
      'Plain': const PlainFormatter(),
      'Structured': const StructuredFormatter(),
    };

    final widths = [80, 40];

    for (final testEntry in {'standard': entry, 'error': errorEntry}.entries) {
      final entryName = testEntry.key;
      final currentEntry = testEntry.value;

      group('Entry: $entryName', () {
        for (final fEntry in formatters.entries) {
          final formatterName = fEntry.key;
          final formatter = fEntry.value;

          group('Formatter: $formatterName', () {
            for (final width in widths) {
              test('Width: $width', () {
                final arena = Arena.instance;
                final doc = arena.checkoutDocument() as ArenaDocument;

                try {
                  // 1. Format
                  formatter.format(currentEntry, doc, arena);

                  // 2. Linearize to B-IR
                  final irPtr = doc.writer.write(doc);

                  // 3. Render via BinaryAnsiEncoder
                  const encoder = BinaryAnsiEncoder();
                  final output = encoder.encode(
                    irPtr,
                    terminalWidth: width,
                    level: currentEntry.level,
                  );

                  // 4. Compare with Golden
                  final baseDir = File('lib/logd.dart').existsSync()
                      ? 'test/regression/goldens/binary'
                      : 'packages/logd/test/regression/goldens/binary';

                  final fileName = 'binary_${formatterName.toLowerCase()}_'
                      '${entryName.toLowerCase()}_$width.txt';
                  final file = File('$baseDir/$fileName');

                  final updateGoldens =
                      Platform.environment['UPDATE_GOLDENS'] == 'true';
                  if (!file.existsSync() || updateGoldens) {
                    file.parent.createSync(recursive: true);
                    file.writeAsStringSync(output);
                    if (updateGoldens && file.existsSync()) {
                      print('Updated Binary golden: ${file.path}');
                    } else {
                      print('Generated Binary golden: ${file.path}');
                    }
                  } else {
                    final expected =
                        file.readAsStringSync().replaceAll('\r\n', '\n');
                    final normalizedOutput = output.replaceAll('\r\n', '\n');
                    expect(
                      normalizedOutput,
                      expected,
                      reason: 'Binary IR output mismatch for $formatterName | '
                          '$entryName | $width',
                    );
                  }
                } finally {
                  doc.releaseRecursive(arena);
                }
              });
            }
          });
        }
      });
    }
  });
}
