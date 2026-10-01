// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('Markdown Regression Goldens', () {
    final standardEntry = LogEntry(
      loggerName: 'SnapTest',
      origin: 'snap.dart:10:5',
      level: LogLevel.info,
      message: 'This is a standard log message for golden verification.',
      timestamp: '2025-01-01 12:00:00',
    );

    final errorEntry = LogEntry(
      loggerName: 'ErrorSnap',
      origin: 'error.dart:42',
      level: LogLevel.error,
      message: 'Database connection failed.',
      timestamp: '2025-01-01 12:00:01',
      error: 'SocketException: Connection refused '
          '(OS Error: Connection refused, errno = 111)',
      stackTrace: StackTrace.fromString(
        '#0      Socket.connect (dart:io/socket.dart:100:5)\n'
        '#1      DbPool.acquire (package:db/pool.dart:50:12)',
      ),
    );

    const testCases = [
      ('standard', 'markdown_standard.md'),
      ('error', 'markdown_error.md'),
    ];

    for (final (name, fileName) in testCases) {
      test('Golden: $name ($fileName)', () {
        final currentEntry = name == 'standard' ? standardEntry : errorEntry;
        const formatter = MarkdownFormatter();
        const factory = StandardPipelineFactory();
        final doc = factory.checkoutDocument();

        try {
          formatter.format(currentEntry, doc, factory);

          final context = HandlerContext();
          (doc.metadata[AutoEncoder.encoderKey]! as LogEncoder).encode(
            currentEntry,
            doc,
            currentEntry.level,
            context,
            factory,
          );

          final output = const Utf8Decoder().convert(context.takeBytes());

          final baseDir = File('lib/logd_markdown.dart').existsSync()
              ? 'test/regression/goldens'
              : 'packages/logd_markdown/test/regression/goldens';

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
            reason: 'Output mismatch for Markdown golden: $fileName',
          );
        } finally {
          doc.releaseRecursive(Arena.instance);
        }
      });
    }
  });
}
