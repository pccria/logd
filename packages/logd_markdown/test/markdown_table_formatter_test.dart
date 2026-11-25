import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownTableFormatter Tests', () {
    const factory = StandardPipelineFactory();

    test('emits GFM table header via preamble and aligned row via encode', () {
      const formatter = MarkdownTableFormatter(
        metadata: {LogMetadata.timestamp, LogMetadata.logger},
      );
      final entry = LogEntry(
        level: LogLevel.warning,
        message: 'Latency | spike\nretrying',
        loggerName: 'net.http',
        timestamp: '2026-11-25T18:10:00',
        origin: 'client.dart:88',
        context: {'ms': 450},
      );

      final doc = factory.checkoutDocument();
      formatter.format(entry, doc, factory);
      final encoder = doc.metadata[AutoEncoder.encoderKey]! as LogEncoder;

      final ctx = HandlerContext();
      encoder.preamble(ctx, entry.level, factory, document: doc);
      encoder.encode(entry, doc, entry.level, ctx, factory);
      final output = utf8.decode(ctx.takeBytes());

      final lines = output.trim().split('\n');
      expect(lines.length, 3);
      expect(lines[0], '| Timestamp | Level | Logger | Message | Context |');
      expect(lines[1], '| --- | --- | --- | --- | --- |');
      expect(
        lines[2],
        r'| 2026-11-25T18:10:00 | ⚠️ WARNING | net.http | Latency \| spike<br>retrying | `{"ms":450}` |',
      );
    });

    test('CommonMark dialect uses spaces instead of <br> in table cells', () {
      const formatter = MarkdownTableFormatter(
        metadata: {},
        includeContext: false,
        dialect: MarkdownDialect.commonmark,
      );
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'Line 1\nLine 2',
        loggerName: 'app',
        timestamp: '2026-11-25T18:10:00',
        origin: 'main.dart:1',
      );

      final doc = factory.checkoutDocument();
      formatter.format(entry, doc, factory);
      final encoder = doc.metadata[AutoEncoder.encoderKey]! as LogEncoder;

      final ctx = HandlerContext();
      encoder.encode(entry, doc, entry.level, ctx, factory);
      final output = utf8.decode(ctx.takeBytes());

      expect(output.trim(), '| ℹ️ INFO | Line 1 Line 2 |');
    });

    test(
      'MarkdownFileHandler with tableMode: true writes table to disk',
      () async {
        final dir = await Directory.systemTemp.createTemp('logd_md_table_');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}/report.md';

        final handler = MarkdownFileHandler(
          path: path,
          tableMode: true,
          metadata: const {LogMetadata.logger},
        );
        Logger.configure('md_table_test', handlers: [handler]);
        final logger = Logger.get('md_table_test');

        logger.info('Step 1 passed');
        logger.error('Step 2 failed', error: 'Exit code 1');
        await handler.dispose();

        final content = await File(path).readAsString();
        expect(content, contains('| Level | Logger | Message | Context |'));
        expect(content, isNot(contains('|\n\n|')));
        expect(
          content,
          contains('| ℹ️ INFO | md_table_test | Step 1 passed | — |'),
        );
        expect(
          content,
          contains(
            '| ❌ ERROR | md_table_test | Step 2 failed<br>Error: Exit code 1 | — |',
          ),
        );
      },
    );
  });
}
