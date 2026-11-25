import 'dart:convert';

import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownDialect & MapNode JSON Tests', () {
    const factory = StandardPipelineFactory();

    LogEntry makeErrorEntry() => LogEntry(
      level: LogLevel.error,
      message: 'Payment failed',
      loggerName: 'payments',
      timestamp: '2026-11-25T18:00:00.000',
      origin: 'checkout.dart:42',
      error: 'GatewayTimeout',
      stackTrace: StackTrace.fromString('#0 main (checkout.dart:42)'),
    );

    test('GFM dialect uses [!ERROR] alerts and <details> blocks', () {
      const formatter = MarkdownFormatter(dialect: MarkdownDialect.gfm);
      final doc = factory.checkoutDocument();
      final entry = makeErrorEntry();
      formatter.format(entry, doc, factory);

      final ctx = HandlerContext();
      (doc.metadata[AutoEncoder.encoderKey]! as LogEncoder).encode(
        entry,
        doc,
        entry.level,
        ctx,
        factory,
      );
      final output = utf8.decode(ctx.takeBytes());

      expect(output, contains('> [!ERROR]'));
      expect(output, contains('> Error: GatewayTimeout'));
    });

    test(
      'CommonMark dialect avoids [!ERROR] alerts and raw <details> HTML',
      () {
        const encoder = MarkdownEncoder(dialect: MarkdownDialect.commonmark);
        final doc = factory.checkoutDocument()
          ..writeNode(ErrorNode(segments: [const StyledText('Disk full')]))
          ..writeNode(
            SectionNode(
              summary: MessageNode(segments: [const StyledText('Trace')]),
              children: [
                MessageNode(segments: [const StyledText('Frame 0')]),
              ],
            ),
          );

        final entry = makeErrorEntry();
        final ctx = HandlerContext();
        encoder.encode(entry, doc, entry.level, ctx, factory);
        final output = utf8.decode(ctx.takeBytes());

        expect(output, contains('> **Error:**'));
        expect(output, isNot(contains('[!ERROR]')));
        expect(output, isNot(contains('<details>')));
        expect(output, contains('**Trace**'));
      },
    );

    test('GitLab dialect uses bold blockquotes and <details> blocks', () {
      const encoder = MarkdownEncoder(dialect: MarkdownDialect.gitlab);
      final doc = factory.checkoutDocument()
        ..writeNode(ErrorNode(segments: [const StyledText('Pipeline failed')]))
        ..writeNode(
          SectionNode(
            summary: MessageNode(segments: [const StyledText('Details')]),
            children: [
              MessageNode(segments: [const StyledText('More info')]),
            ],
          ),
        );

      final entry = makeErrorEntry();
      final ctx = HandlerContext();
      encoder.encode(entry, doc, entry.level, ctx, factory);
      final output = utf8.decode(ctx.takeBytes());

      expect(output, contains('> **Error:**'));
      expect(output, contains('<details>'));
      expect(output, contains('<summary>**Details**'));
    });

    test('MapNode serializes as valid indented JSON with safe fallback', () {
      const encoder = MarkdownEncoder();
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'Context check',
        loggerName: 'app',
        timestamp: '2026-11-25T18:00:00.000',
        origin: 'main.dart:10',
      );
      final doc = factory.checkoutDocument()
        ..writeNode(
          MapNode({
            'userId': 'u-42',
            'retries': 3,
            'timestamp': DateTime.utc(2026, 11, 25, 12),
            'stopwatch': Stopwatch(),
          }),
        );

      final ctx = HandlerContext();
      encoder.encode(entry, doc, entry.level, ctx, factory);
      final output = utf8.decode(ctx.takeBytes());

      expect(output, contains('```json\n{'));
      expect(output, contains('"userId":"u-42"'));
      expect(output, contains('"retries":3'));
      expect(output, contains('"timestamp":"2026-11-25T12:00:00.000Z"'));
    });

    test('MarkdownEncoder respects custom contextLanguage', () {
      const encoder = MarkdownEncoder(contextLanguage: 'yaml');
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'Custom lang',
        loggerName: 'app',
        timestamp: '2026-11-25T18:00:00.000',
        origin: 'main.dart:10',
      );
      final doc = factory.checkoutDocument()..writeNode(MapNode({'ok': true}));

      final ctx = HandlerContext();
      encoder.encode(entry, doc, entry.level, ctx, factory);
      final output = utf8.decode(ctx.takeBytes());

      expect(output, contains('```yaml'));
    });
  });
}
