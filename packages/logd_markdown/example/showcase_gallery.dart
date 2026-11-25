import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';

void main() async {
  print('================================================================');
  print('        logd_markdown v0.2.0 Interactive Showcase Gallery       ');
  print('================================================================\n');

  _demo1GfmVsCommonMark();
  _demo2CompactTableFormatter();
  _demo3SafeJsonContext();
  await _demo4GitHubStepSummary();

  print('All showcase scenarios executed successfully.');
}

void _demo1GfmVsCommonMark() {
  print('--- Scenario 1: GFM vs CommonMark Dialects ---');

  const factory = StandardPipelineFactory();
  final entry = LogEntry(
    loggerName: 'checkout',
    origin: 'payment.dart:42',
    level: LogLevel.error,
    message: 'Payment gateway timed out',
    timestamp: '2026-11-25T20:00:00',
    error: 'TimeoutException after 5000ms',
  );

  for (final dialect in [MarkdownDialect.gfm, MarkdownDialect.commonmark]) {
    final formatter = MarkdownFormatter(
      metadata: const {LogMetadata.timestamp, LogMetadata.logger},
      dialect: dialect,
    );
    final doc = factory.checkoutDocument();
    formatter.format(entry, doc, factory);

    final ctx = HandlerContext();
    (doc.metadata[AutoEncoder.encoderKey]! as LogEncoder).encode(
      entry,
      doc,
      entry.level,
      ctx,
      factory,
    );
    print('[Dialect: ${dialect.name}]');
    print(utf8.decode(ctx.takeBytes()).trim());
    print('');
  }
}

void _demo2CompactTableFormatter() {
  print('--- Scenario 2: Compact Table Mode (MarkdownTableFormatter) ---');

  const factory = StandardPipelineFactory();
  const formatter = MarkdownTableFormatter(
    metadata: {LogMetadata.timestamp, LogMetadata.logger},
  );

  final entries = [
    LogEntry(
      loggerName: 'build',
      origin: 'cli.dart:12',
      level: LogLevel.info,
      message: 'Compiled 14 packages',
      timestamp: '2026-11-25T20:01:00',
      context: {'durationMs': 840},
    ),
    LogEntry(
      loggerName: 'test',
      origin: 'runner.dart:88',
      level: LogLevel.warning,
      message: 'Retry | flaky network socket',
      timestamp: '2026-11-25T20:01:05',
    ),
  ];

  final ctx = HandlerContext();
  for (var i = 0; i < entries.length; i++) {
    final doc = factory.checkoutDocument();
    formatter.format(entries[i], doc, factory);
    final encoder = doc.metadata[AutoEncoder.encoderKey]! as LogEncoder;
    if (i == 0) {
      encoder.preamble(ctx, entries[i].level, factory, document: doc);
    }
    encoder.encode(entries[i], doc, entries[i].level, ctx, factory);
    ctx.addByte(0x0A);
  }

  print(utf8.decode(ctx.takeBytes()).trim());
  print('');
}

void _demo3SafeJsonContext() {
  print('--- Scenario 3: Safe JSON Context Code Fence ---');

  const factory = StandardPipelineFactory();
  const encoder = MarkdownEncoder();
  final entry = LogEntry(
    loggerName: 'metrics',
    origin: 'main.dart:10',
    level: LogLevel.info,
    message: 'Snapshot captured',
    timestamp: '2026-11-25T20:02:00',
  );
  final doc = factory.checkoutDocument()
    ..writeNode(
      MapNode({
        'service': 'auth',
        'recordedAt': DateTime.utc(2026, 11, 25, 20, 2),
        'timer': Stopwatch(),
      }),
    );

  final ctx = HandlerContext();
  encoder.encode(entry, doc, entry.level, ctx, factory);
  print(utf8.decode(ctx.takeBytes()).trim());
  print('');
}

Future<void> _demo4GitHubStepSummary() async {
  print('--- Scenario 4: CI Step Summary (GitHubStepSummaryHandler) ---');

  final dir = await Directory.systemTemp.createTemp('logd_md_showcase_');
  try {
    final summaryFile = '${dir.path}/step_summary.md';
    final handler = GitHubStepSummaryHandler(
      title: 'Monorepo CI Run',
      path: summaryFile,
    );

    Logger.configure('showcase.ci', handlers: [handler]);
    final logger = Logger.get('showcase.ci');

    logger.info('Static analysis passed', context: {'packages': 7});
    logger.warning('1 optional benchmark skipped');
    logger.error(
      'Integration check failed',
      error: 'Connection refused on port 8080',
      stackTrace: StackTrace.fromString(
        '#0 main (test/integration_test.dart:14)',
      ),
    );

    await handler.dispose();

    final rendered = await File(summaryFile).readAsString();
    print(rendered.trim());
    print('');
  } finally {
    await dir.delete(recursive: true);
  }
}
