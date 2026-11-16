import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:test/test.dart';

void main() {
  group('Multiple Headers & Footers Resolution', () {
    late Directory tempDir;
    late String filePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_multi_header_test_');
      filePath = '${tempDir.path}/test.html';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'guarantees single DOCTYPE, single </html> and session delimiter on sequential runs',
      () async {
        // Run 1: Application starts, logs, and disposes
        final handler1 = HtmlFileHandler(path: filePath, title: 'Run 1');
        final logger1 = Logger.get('run1');
        Logger.configure('run1', handlers: [handler1]);

        logger1.info('Message from run 1');
        await handler1.dispose();

        final contentAfterRun1 = File(filePath).readAsStringSync();
        expect('<!DOCTYPE html>'.allMatches(contentAfterRun1).length, 1);
        expect('</html>'.allMatches(contentAfterRun1).length, 1);
        expect(
          '<div class="log-session-delimiter">'
              .allMatches(contentAfterRun1)
              .length,
          0,
        );

        // Run 2: Application restarts and logs to the same file in
        // appendSession mode.
        final handler2 = HtmlFileHandler(
          path: filePath,
          title: 'Run 2',
          fileMode: HtmlFileMode.appendSession,
        );
        final logger2 = Logger.get('run2');
        Logger.configure('run2', handlers: [handler2]);

        logger2.info('Message from run 2');
        await handler2.dispose();

        final contentAfterRun2 = File(filePath).readAsStringSync();
        final doctypeCount = '<!DOCTYPE html>'
            .allMatches(contentAfterRun2)
            .length;
        final htmlCloseCount = '</html>'.allMatches(contentAfterRun2).length;
        final dividerCount = '<div class="log-session-delimiter">'
            .allMatches(contentAfterRun2)
            .length;
        final footerCount = '<footer class="log-page-footer">'
            .allMatches(contentAfterRun2)
            .length;

        expect(
          doctypeCount,
          equals(1),
          reason: 'Document shell must exist exactly once across runs',
        );
        expect(
          htmlCloseCount,
          equals(1),
          reason: 'Document closing tag must exist exactly once across runs',
        );
        expect(
          dividerCount,
          equals(1),
          reason: 'A session divider must separate Run 1 from Run 2',
        );
        expect(
          footerCount,
          equals(1),
          reason: 'Footer must be closed exactly once at end of document',
        );
        expect(contentAfterRun2, contains('Message from run 1'));
        expect(contentAfterRun2, contains('Message from run 2'));
      },
    );

    test(
      'guarantees single DOCTYPE when two loggers share a file in same process',
      () async {
        final handlerA = HtmlFileHandler(path: filePath, title: 'Service A');
        final handlerB = HtmlFileHandler(path: filePath, title: 'Service B');

        Logger.configure('serviceA', handlers: [handlerA]);
        Logger.configure('serviceB', handlers: [handlerB]);

        Logger.get('serviceA').info('Hello from Service A');
        Logger.get('serviceB').info('Hello from Service B');

        await handlerA.dispose();
        await handlerB.dispose();

        final content = File(filePath).readAsStringSync();
        final doctypeCount = '<!DOCTYPE html>'.allMatches(content).length;
        final htmlCloseCount = '</html>'.allMatches(content).length;

        expect(
          doctypeCount,
          equals(1),
          reason: 'Shared file coordinator must emit only one DOCTYPE',
        );
        expect(
          htmlCloseCount,
          equals(1),
          reason: 'Shared file coordinator must emit only one </html>',
        );
        expect(content, contains('Hello from Service A'));
        expect(content, contains('Hello from Service B'));
      },
    );

    test(
      'HtmlFileMode.overwrite starts fresh and discards previous contents',
      () async {
        final handler1 = HtmlFileHandler(path: filePath, title: 'First Run');
        Logger.configure('overwrite.test1', handlers: [handler1]);
        Logger.get('overwrite.test1').info('Initial old message');
        await handler1.dispose();

        // Second run with overwrite mode
        final handler2 = HtmlFileHandler(
          path: filePath,
          title: 'Second Run',
          fileMode: HtmlFileMode.overwrite,
        );
        Logger.configure('overwrite.test2', handlers: [handler2]);
        Logger.get('overwrite.test2').info('Fresh new message');
        await handler2.dispose();

        final content = File(filePath).readAsStringSync();
        expect('<!DOCTYPE html>'.allMatches(content).length, 1);
        expect('</html>'.allMatches(content).length, 1);
        expect(content, isNot(contains('Initial old message')));
        expect(content, contains('Fresh new message'));
      },
    );

    test(
      'HtmlFileMode.fragment emits raw entries without document shell',
      () async {
        final handler = HtmlFileHandler(
          path: filePath,
          fileMode: HtmlFileMode.fragment,
        );
        Logger.configure('fragment.test', handlers: [handler]);
        Logger.get('fragment.test').info('Fragment log message');
        await handler.dispose();

        final content = File(filePath).readAsStringSync();
        expect(content, isNot(contains('<!DOCTYPE html>')));
        expect(content, isNot(contains('</html>')));
        expect(content, isNot(contains('<header')));
        expect(content, isNot(contains('<footer')));
        expect(content, contains('log-entry'));
        expect(content, contains('Fragment log message'));
      },
    );
  });
}
