import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlFileHandler rotation document integrity', () {
    late Directory tempDir;
    late String basePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_html_rot_');
      basePath = '${tempDir.path}/rot.html';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('rotated file gets postamble and new file gets preamble', () async {
      final handler = HtmlFileHandler(
        path: basePath,
        title: 'Rotation Test',
        fileRotation: SizeRotation(
          maxSize: '10KB',
          backupCount: 3,
        ),
      );

      final logger = Logger.get('test.html.rot');
      Logger.configure('test.html.rot', handlers: [handler]);

      // Emit first log: writes preamble + first record to rot.html
      // (> 1024 bytes).
      logger.info('Entry 1 - This will initialize the first file.');
      await handler.flush();

      // Emit second log: triggers rotation because current rot.html size > 1024
      logger.info('Entry 2 - This should trigger rotation into a new file.');
      await handler.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final activeFile = File(basePath);
      expect(activeFile.existsSync(), isTrue);
      final activeContent = activeFile.readAsStringSync();

      // Find the rotated backup file (rot.1.html)
      final rotatedFile = File('${tempDir.path}/rot.1.html');
      expect(
        rotatedFile.existsSync(),
        isTrue,
        reason: 'rot.1.html should exist after rotation',
      );
      final rotatedContent = rotatedFile.readAsStringSync();

      // Verify the OLD rotated file got closed with a footer and closing tags
      expect(
        rotatedContent,
        contains('<!DOCTYPE html>'),
        reason: 'Rotated file must have opening HTML preamble',
      );
      expect(
        rotatedContent,
        contains('<footer class="log-page-footer">'),
        reason: 'Rotated file must have closing footer postamble',
      );
      expect(
        rotatedContent,
        contains('</body>'),
        reason: 'Rotated file must have closing body tag',
      );
      expect(
        rotatedContent.trimRight(),
        endsWith('</html>'),
        reason: 'Rotated file must end with closing html tag',
      );

      // Verify the NEW active file got an opening preamble and a closing footer
      expect(
        activeContent,
        contains('<!DOCTYPE html>'),
        reason: 'New active file must start with opening HTML preamble',
      );
      expect(
        activeContent,
        contains('<footer class="log-page-footer">'),
        reason: 'New active file must have closing footer postamble on dispose',
      );
      expect(
        activeContent,
        contains('</body>'),
        reason: 'New active file must have closing body tag',
      );
      expect(
        activeContent.trimRight(),
        endsWith('</html>'),
        reason: 'New active file must end with closing html tag',
      );
    });
  });
}
