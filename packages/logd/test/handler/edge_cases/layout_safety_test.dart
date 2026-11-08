import 'package:logd/logd.dart';
import 'package:logd/src/handler/handler.dart' show TerminalLayout;
import 'package:test/test.dart';

import '../test_helpers.dart';

void main() {
  group('Layout & Encoding Safety', () {
    test('Unicode and Emoji handle widths correctly in BoxDecorator', () {
      const box = BoxDecorator(borderStyle: BorderStyle.rounded);
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'test',
        level: LogLevel.info,
        message: '你好世界 🌍',
        timestamp: '2025-01-01 10:00:00',
      );

      final lines = ['你好世界 🌍', 'ASCII Test'];
      final doc = createTestDocument(lines);
      try {
        box.decorate(doc, entry, Arena.instance);

        final layout = TerminalLayout(width: 40, factory: Arena.instance);
        final result = layout.layout(doc, LogLevel.info).lines;

        final topWidth = result[0].visibleLength;
        for (final line in result) {
          expect(
            line.visibleLength,
            equals(topWidth),
            reason: 'Line failed: $line',
          );
        }
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('ANSI preservation across wrapping in BoxDecorator', () {
      const box = BoxDecorator(borderStyle: BorderStyle.double);
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'test',
        level: LogLevel.info,
        message: 'test',
        timestamp: '2025-01-01 10:00:00',
      );

      // Colored message
      final lines = ['\x1B[31mThis is red\x1B[0m'];
      final doc = createTestDocument(lines, tags: LogTag.raw);
      try {
        box.decorate(doc, entry, Arena.instance);

        final layout = TerminalLayout(width: 20, factory: Arena.instance);
        final result = layout.layout(doc, LogLevel.info).lines;

        expect(result.length, equals(4));
        // Each wrapped line should start with red color (if preserved)
        // Note: Current naive implementation preserves ANSI at start of each
        // wrap
        expect(result[1].toString(), contains('\x1B[31m'));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('Very long words without spaces are forced to wrap', () {
      const formatter = StructuredFormatter();
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'test',
        level: LogLevel.info,
        message: 'Supercalifragilisticexpialidocious',
        timestamp: '2025-01-01 10:00:00',
      );

      final doc = formatDoc(formatter, entry);
      try {
        final layout = TerminalLayout(width: 20, factory: Arena.instance);
        final lines = layout.layout(doc, LogLevel.info).lines;
        for (final line in lines) {
          expect(line.visibleLength, lessThanOrEqualTo(20));
        }
        final json = lines.map((final l) => l.toString()).join('\n');
        expect(json, isNot(contains('"error":')));
        expect(lines.length, greaterThan(3));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('Malformed ANSI codes do not crash the system', () {
      final lines = ['Normal \x1B[999;999;999m Malformed'];
      // Should not crash visibleLength calculation
      // We can use TerminalLayout to simulate rendering which calculates
      // visibleLength
      final layout = TerminalLayout(width: 80, factory: Arena.instance);
      final doc = createTestDocument(lines);
      try {
        final physical = layout.layout(doc, LogLevel.info);
        expect(physical.lines.first.visibleLength, isPositive);
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('wrapping behavior at exact boundaries (width - 1, width, width + 1)',
        () {
      final doc1 = createTestDocument(['a' * 19]);
      final doc2 = createTestDocument(['a' * 20]);
      final doc3 = createTestDocument(['a' * 21]);
      try {
        final layout = TerminalLayout(width: 20, factory: Arena.instance);
        final lines1 = layout.layout(doc1, LogLevel.info).lines;
        final lines2 = layout.layout(doc2, LogLevel.info).lines;
        final lines3 = layout.layout(doc3, LogLevel.info).lines;

        expect(lines1.length, equals(1));
        expect(lines1[0].visibleLength, equals(19));

        expect(lines2.length, equals(1));
        expect(lines2[0].visibleLength, equals(20));

        expect(lines3.length, equals(2));
        expect(lines3[0].visibleLength, equals(20));
        expect(lines3[1].visibleLength, equals(1));
      } finally {
        doc1.releaseRecursive(Arena.instance);
        doc2.releaseRecursive(Arena.instance);
        doc3.releaseRecursive(Arena.instance);
      }
    });
  });
}
