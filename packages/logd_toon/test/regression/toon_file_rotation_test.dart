import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

void main() {
  group('ToonFileHandler rotation document integrity', () {
    late Directory tempDir;
    late String basePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_toon_rot_');
      basePath = '${tempDir.path}/rot.toon';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'write past rotation size and check new active file starts with TOON header',
      () async {
        final handler = ToonFileHandler(
          path: basePath,
          fileRotation: SizeRotation(
            maxSize: '100B',
            backupCount: 3,
          ),
        );

        final logger = Logger.get('test.toon.rot');
        Logger.configure('test.toon.rot', handlers: [handler]);

        // Emit first log: writes preamble + first record to rot.toon (> 100 bytes).
        logger.info(
          'Entry 1 - This will initialize the first file and exceed rotation size.',
        );
        await handler.flush();

        // Emit second log: triggers rotation because current rot.toon size > 100B
        logger.info('Entry 2 - This should trigger rotation into a new file.');
        await handler.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final activeFile = File(basePath);
        expect(activeFile.existsSync(), isTrue);
        final activeContent = activeFile.readAsStringSync();

        // Verify the new active file starts with the TOON header
        expect(
          activeContent.trimLeft(),
          startsWith('logs[]'),
          reason: 'New active file must start with TOON header',
        );
      },
    );
  });
}
