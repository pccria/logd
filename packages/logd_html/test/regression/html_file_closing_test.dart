// Place at: packages/logd_html/test/regression/html_file_closing_test.dart
//
// Regression test for F-53 (LOGD-REVIEW-1.0, updated in the 1.1 verification):
// AutoEncoder.postamble resolves its delegate with no document, so a
// metadata-selected HtmlEncoder never writes its postamble. The existing
// html_file_handler_test only checks for '<!DOCTYPE html>' and the message,
// so it cannot see that the footer, the interactive <script> block and the
// closing tags are missing.
//
// EXPECTED TODAY: both tests fail until the postamble is written.

import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlFileHandler output is a complete document', () {
    late Directory tempDir;
    late String path;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_html_close_');
      path = '${tempDir.path}/closing.html';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    void expectComplete(final String contents) {
      expect(contents, contains('<!DOCTYPE html>'));
      expect(contents, contains('first entry'));
      expect(
        contents,
        contains('<footer class="log-page-footer">'),
        reason: 'footer comes from HtmlEncoder.postamble',
      );
      expect(
        contents,
        contains('<script>'),
        reason: 'search and filter JavaScript comes from postamble',
      );
      expect(contents, contains('</script>'));
      expect(contents, contains('</body>'));
      expect(contents.trimRight(), endsWith('</html>'));
      expect(
        '</html>'.allMatches(contents).length,
        1,
        reason: 'the document must be closed exactly once',
      );
    }

    test('synchronous handler closes the document on dispose', () async {
      final handler = HtmlFileHandler(path: path, title: 'Close Test');
      Logger.configure('test.html.close.sync', handlers: [handler]);

      Logger.get('test.html.close.sync').info('first entry');
      await handler.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expectComplete(File(path).readAsStringSync());
    });

    test('asynchronous handler closes the document on dispose', () async {
      final handler = HtmlFileHandler.async(path: path, title: 'Close Test');
      Logger.configure('test.html.close.async', handlers: [handler]);
      await handler.ready;

      Logger.get('test.html.close.async').info('first entry');
      await handler.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expectComplete(File(path).readAsStringSync());
    });
  });
}
