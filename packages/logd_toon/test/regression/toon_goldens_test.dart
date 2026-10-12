// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

void main() {
  group('Toon Regression Goldens', () {
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

    const widths = [80, 40, 20];

    for (final entryName in ['Standard', 'Long']) {
      final currentEntry = entryName == 'Standard' ? entry : longEntry;

      group('Entry: $entryName', () {
        for (final width in widths) {
          test('Width: $width', () {
            const formatter = ToonFormatter();
            const factory = StandardPipelineFactory();
            final doc = factory.checkoutDocument();

            try {
              formatter.format(currentEntry, doc, factory);

              final context = HandlerContext();
              final encoder =
                  doc.metadata[AutoEncoder.encoderKey]! as LogEncoder;
              encoder.encode(
                currentEntry,
                doc,
                currentEntry.level,
                context,
                factory,
                width: width,
              );

              final output = const Utf8Decoder().convert(context.takeBytes());

              // Resolve golden directory
              final baseDir = File('lib/logd_toon.dart').existsSync()
                  ? 'test/regression/goldens'
                  : 'packages/logd_toon/test/regression/goldens';

              final fileName = 'toon_${entryName.toLowerCase()}_$width.txt';
              final file = File('$baseDir/$fileName');

              expect(
                file.existsSync(),
                isTrue,
                reason: 'Golden file $fileName must exist',
              );

              final expected = file.readAsStringSync().replaceAll('\r\n', '\n');
              final normalizedOutput = output.replaceAll('\r\n', '\n');

              expect(
                normalizedOutput,
                expected,
                reason: 'Output mismatch for Toon | $entryName | $width.',
              );
            } finally {
              doc.releaseRecursive(Arena.instance);
            }
          });
        }
      });
    }
  });
}
