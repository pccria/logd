import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('GitHubStepSummaryHandler & MarkdownRunSummary Tests', () {
    test(
      'collects severity counts, bounds failures, and writes rollup',
      () async {
        final dir = await Directory.systemTemp.createTemp('logd_gh_summary_');
        addTearDown(() => dir.delete(recursive: true));
        final summaryPath = '${dir.path}/step_summary.md';

        final handler = GitHubStepSummaryHandler(
          title: 'CI Build & Test',
          path: summaryPath,
          maxFailures: 2,
        );

        Logger.configure('ci_summary_test', handlers: [handler]);
        final logger = Logger.get('ci_summary_test');

        logger.info('Dependencies resolved');
        logger.warning('Deprecated API usage detected');
        logger.error(
          'Unit test failed',
          error: 'Expected true, got false',
          stackTrace: StackTrace.fromString('#0 testMain (test.dart:12)'),
        );
        logger.error('Second error dropped from details due to maxFailures: 2');

        await handler.flush();

        final snap = handler.summary;
        expect(snap.totalEntries, 4);
        expect(snap.infoCount, 1);
        expect(snap.warningCount, 1);
        expect(snap.errorCount, 2);
        expect(snap.hasErrors, isTrue);
        expect(snap.failures.length, 2);

        // Calling writeSummary and dispose should write rollup idempotently
        await handler.writeSummary();
        await handler.dispose();

        final content = await File(summaryPath).readAsString();
        expect(
          content,
          contains('| Timestamp | Level | Logger | Message | Context |'),
        );
        expect(content, contains('## ❌ CI Build & Test'));
        expect(content, contains('| Total Entries | 4 |'));
        expect(content, contains('| ❌ Errors | 2 |'));
        expect(content, contains('| ⚠️ Warnings | 1 |'));
        expect(
          content,
          contains('<summary>Failure &amp; Warning Details (2)</summary>'),
        );
        expect(content, contains('Expected true, got false'));
        // Verify idempotency (only one summary heading)
        expect('## ❌ CI Build & Test'.allMatches(content).length, 1);
      },
    );

    test(
      'operates safely as in-memory collector when no path or env is set',
      () async {
        final handler = GitHubStepSummaryHandler(title: 'Local Run');
        Logger.configure('ci_local_noop', handlers: [handler]);
        Logger.get('ci_local_noop').info('Local log');

        await handler.dispose();
        expect(handler.summary.totalEntries, 1);
        expect(handler.summary.infoCount, 1);
        expect(handler.summary.hasErrors, isFalse);
        expect(
          handler.summary.toMarkdown(
            title: 'Local Run',
            dialect: MarkdownDialect.commonmark,
          ),
          contains('## ✅ Local Run'),
        );
      },
    );
  });
}
