import 'package:logd/logd.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('Control Character & Escape Neutralization', () {
    test('neutralizes raw ANSI escape sequences in plain text and layout', () {
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'Hello \x1B[2J\x1B[H cleared',
        timestamp: '2026-11-02 00:00:00',
      );

      const formatter = PlainFormatter(metadata: {LogMetadata.logger});
      final arena = Arena.instance;
      final doc = arena.checkoutDocument();
      try {
        formatter.format(entry, doc, arena);
        final lines = renderLines(doc);

        expect(lines.length, equals(1));
        // The raw ESC (0x1B) sequence should be neutralized into readable text
        // and NOT remain raw 0x1B inside the rendered text.
        final text = lines.first;
        expect(text, isNot(contains('\x1B[2J')));
        expect(text, contains('^[[2J'));
      } finally {
        doc.releaseRecursive(arena);
      }
    });

    test('normalizes carriage returns to prevent line overwrite forging', () {
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'Normal message\r[CRITICAL] forged line',
        timestamp: '2026-11-02 00:00:00',
      );

      const formatter = PlainFormatter(metadata: {LogMetadata.logger});
      final arena = Arena.instance;
      final doc = arena.checkoutDocument();
      try {
        formatter.format(entry, doc, arena);
        final lines = renderLines(doc);

        // Raw carriage return '\r' must not be in the output lines
        for (final line in lines) {
          expect(line, isNot(contains('\r')));
        }
        // Instead, it should be split into multiple indented lines
        expect(lines.length, equals(2));
        expect(lines[0], contains('Normal message'));
        expect(lines[1], contains('[CRITICAL] forged line'));
      } finally {
        doc.releaseRecursive(arena);
      }
    });

    test('strips destructive C0 control codes like BEL and NUL', () {
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'Clean\x00Message\x07With\x08Controls',
        timestamp: '2026-11-02 00:00:00',
      );

      const formatter = PlainFormatter(metadata: {LogMetadata.logger});
      final arena = Arena.instance;
      final doc = arena.checkoutDocument();
      try {
        formatter.format(entry, doc, arena);
        final lines = renderLines(doc);

        expect(lines.length, equals(1));
        expect(lines.first, isNot(contains('\x00')));
        expect(lines.first, isNot(contains('\x07')));
        expect(lines.first, isNot(contains('\x08')));
        expect(lines.first, contains('CleanMessageWithControls'));
      } finally {
        doc.releaseRecursive(arena);
      }
    });

    test('preserves raw escape sequences when tagged with LogTag.raw', () {
      final doc = Arena.instance.checkoutDocument();
      try {
        doc.nodes.add(
          Arena.instance.checkoutMessage()
            ..segments.add(
              const StyledText('Raw \x1B[32mGreen\x1B[0m', tags: LogTag.raw),
            ),
        );
        final lines = renderLines(doc);
        expect(lines.first, contains('\x1B[32mGreen\x1B[0m'));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });
  });
}
