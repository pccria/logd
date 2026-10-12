import 'package:logd/logd.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';

void main() {
  group('AnsiEncoder', () {
    const encoder = AnsiEncoder();
    const factory = StandardPipelineFactory();
    late LogEntry testEntry;

    setUp(() {
      testEntry = LogEntry(
        loggerName: 'ansi_test',
        origin: 'ansi_encoder_test.dart',
        level: LogLevel.info,
        message: 'ansi test',
        timestamp: '2026-09-20T12:00:00.000Z',
      );
    });

    test('wrappingStrategy is none', () {
      expect(encoder.wrappingStrategy, equals(WrappingStrategy.none));
    });

    test('preamble and postamble execute cleanly without modifying context',
        () {
      final context = HandlerContext();
      encoder
        ..preamble(context, LogLevel.info, factory)
        ..postamble(context, LogLevel.info, factory);
      expect(context.length, equals(0));
    });

    test('does nothing when document has no nodes', () {
      final emptyDoc = factory.checkoutDocument();
      final context = HandlerContext();
      try {
        encoder.encode(testEntry, emptyDoc, LogLevel.info, context, factory);
        expect(context.length, equals(0));
      } finally {
        emptyDoc.releaseRecursive(factory);
      }
    });

    test('encodes unstyled text without ANSI escape codes', () {
      final doc = createTestDocument(['plain text without styling']);
      final context = HandlerContext();
      try {
        encoder.encode(testEntry, doc, LogLevel.info, context, factory);
        expect(context.toString(), equals('plain text without styling'));
      } finally {
        doc.releaseRecursive(factory);
      }
    });

    test('encodes styled foreground colors with reset at line end', () {
      final doc = factory.checkoutDocument();
      final msg = factory.checkoutMessage()
        ..segments.add(
          const StyledText(
            'red text',
            style: LogStyle(color: LogColor.red),
          ),
        );
      doc.writeNode(msg);

      final context = HandlerContext();
      try {
        encoder.encode(testEntry, doc, LogLevel.info, context, factory);
        // \x1B[31mred text\x1B[0m
        expect(context.toString(), equals('\x1B[31mred text\x1B[0m'));
      } finally {
        doc.releaseRecursive(factory);
      }
    });

    test('encodes bright foreground colors', () {
      final doc = factory.checkoutDocument();
      final msg = factory.checkoutMessage()
        ..segments.add(
          const StyledText(
            'bright green',
            style: LogStyle(color: LogColor.brightGreen),
          ),
        );
      doc.writeNode(msg);

      final context = HandlerContext();
      try {
        encoder.encode(testEntry, doc, LogLevel.info, context, factory);
        // brightGreen -> 30 + 62 = 92
        expect(context.toString(), equals('\x1B[92mbright green\x1B[0m'));
      } finally {
        doc.releaseRecursive(factory);
      }
    });

    test('encodes background colors correctly', () {
      final doc = factory.checkoutDocument();
      final msg = factory.checkoutMessage()
        ..segments.add(
          const StyledText(
            'blue bg',
            style: LogStyle(backgroundColor: LogColor.blue),
          ),
        );
      doc.writeNode(msg);

      final context = HandlerContext();
      try {
        encoder.encode(testEntry, doc, LogLevel.info, context, factory);
        // blue background -> 40 + 4 = 44
        expect(context.toString(), equals('\x1B[44mblue bg\x1B[0m'));
      } finally {
        doc.releaseRecursive(factory);
      }
    });

    test('encodes bright background colors correctly', () {
      final doc = factory.checkoutDocument();
      final msg = factory.checkoutMessage()
        ..segments.add(
          const StyledText(
            'bright yellow bg',
            style: LogStyle(backgroundColor: LogColor.brightYellow),
          ),
        );
      doc.writeNode(msg);

      final context = HandlerContext();
      try {
        encoder.encode(testEntry, doc, LogLevel.info, context, factory);
        // brightYellow background -> 40 + 63 = 103
        expect(context.toString(), equals('\x1B[103mbright yellow bg\x1B[0m'));
      } finally {
        doc.releaseRecursive(factory);
      }
    });

    test('encodes all style modifiers (bold, dim, italic, inverse, underline)',
        () {
      final doc = factory.checkoutDocument();
      final msg = factory.checkoutMessage()
        ..segments.add(
          const StyledText(
            'styled text',
            style: LogStyle(
              bold: true,
              dim: true,
              italic: true,
              inverse: true,
              underline: true,
            ),
          ),
        );
      doc.writeNode(msg);

      final context = HandlerContext();
      try {
        encoder.encode(testEntry, doc, LogLevel.info, context, factory);
        // codes: 1;2;3;7;4
        expect(
          context.toString(),
          equals('\x1B[1;2;3;7;4mstyled text\x1B[0m'),
        );
      } finally {
        doc.releaseRecursive(factory);
      }
    });

    test(
        'coalesces identical styles across adjacent segments without redundant'
        ' escapes', () {
      const sharedStyle = LogStyle(color: LogColor.yellow, bold: true);
      final doc = factory.checkoutDocument();
      final msg = factory.checkoutMessage()
        ..segments.addAll([
          const StyledText('part1', style: sharedStyle),
          const StyledText('part2', style: sharedStyle),
        ]);
      doc.writeNode(msg);

      final context = HandlerContext();
      try {
        encoder.encode(testEntry, doc, LogLevel.info, context, factory);
        // Style should only open once, then reset at end: \x1B[1;33mpart1part2\x1B[0m
        expect(context.toString(), equals('\x1B[1;33mpart1part2\x1B[0m'));
      } finally {
        doc.releaseRecursive(factory);
      }
    });

    test('resets and applies new style when switching styles on same line', () {
      const redStyle = LogStyle(color: LogColor.red);
      const greenStyle = LogStyle(color: LogColor.green);
      final doc = factory.checkoutDocument();
      final msg = factory.checkoutMessage()
        ..segments.addAll([
          const StyledText('red', style: redStyle),
          const StyledText('green', style: greenStyle),
        ]);
      doc.writeNode(msg);

      final context = HandlerContext();
      try {
        encoder.encode(testEntry, doc, LogLevel.info, context, factory);
        expect(
          context.toString(),
          equals('\x1B[31mred\x1B[0m\x1B[32mgreen\x1B[0m'),
        );
      } finally {
        doc.releaseRecursive(factory);
      }
    });

    test('encodes multi-line documents separated by newline characters', () {
      final doc = createTestDocument(['line 1', 'line 2', 'line 3']);
      final context = HandlerContext();
      try {
        encoder.encode(testEntry, doc, LogLevel.info, context, factory);
        expect(context.toString(), equals('line 1\nline 2\nline 3'));
      } finally {
        doc.releaseRecursive(factory);
      }
    });
  });

  group('AnsiColorCode and AnsiStyle Adapter', () {
    test('AnsiColorCode.fromLogColor maps all LogColor enum values', () {
      for (final color in LogColor.values) {
        final ansiCode = AnsiColorCode.fromLogColor(color);
        expect(ansiCode, isNotNull);
        expect(ansiCode.foreground, startsWith('\x1B['));
        expect(ansiCode.foreground, endsWith('m'));
        expect(ansiCode.background, startsWith('\x1B['));
        expect(ansiCode.background, endsWith('m'));
      }
    });

    test('AnsiColorCode sequence formats correctly', () {
      expect(AnsiColorCode.black.foreground, equals('\x1B[30m'));
      expect(AnsiColorCode.black.background, equals('\x1B[40m'));
      expect(AnsiColorCode.red.foreground, equals('\x1B[31m'));
      expect(AnsiColorCode.red.background, equals('\x1B[41m'));
      expect(AnsiColorCode.brightWhite.foreground, equals('\x1B[97m'));
      expect(AnsiColorCode.brightWhite.background, equals('\x1B[107m'));
    });

    test('AnsiStyle sequence formats correctly', () {
      expect(AnsiStyle.reset.sequence, equals('\x1B[0m'));
      expect(AnsiStyle.bold.sequence, equals('\x1B[1m'));
      expect(AnsiStyle.dim.sequence, equals('\x1B[2m'));
      expect(AnsiStyle.italic.sequence, equals('\x1B[3m'));
      expect(AnsiStyle.underline.sequence, equals('\x1B[4m'));
      expect(AnsiStyle.blink.sequence, equals('\x1B[5m'));
      expect(AnsiStyle.reverse.sequence, equals('\x1B[7m'));
      expect(AnsiStyle.hidden.sequence, equals('\x1B[8m'));
      expect(AnsiStyle.strikethrough.sequence, equals('\x1B[9m'));
    });
  });
}
