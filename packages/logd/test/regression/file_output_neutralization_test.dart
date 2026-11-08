import 'dart:io';

import 'package:logd/logd.dart';
import 'package:test/test.dart';

void main() {
  group('PlainFileHandler neutralizes untrusted text', () {
    late Directory tempDir;
    late String path;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_neutral_');
      path = '${tempDir.path}/out.log';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<String> logAndRead(final String message) async {
      final handler = PlainFileHandler(path: path);
      Logger.configure('test.neutral.file', handlers: [handler]);
      Logger.get('test.neutral.file').info(message);
      await handler.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return File(path).readAsStringSync();
    }

    test('terminal escape sequences do not reach the file', () async {
      const esc = '\u001B';
      final contents =
          await logAndRead('before $esc[2J$esc]0;owned\u0007 after');
      expect(contents.contains(esc), isFalse);
      expect(contents.contains('\u0007'), isFalse);
      expect(contents, contains('before'));
      expect(contents, contains('after'));
    });

    test('other C0 control characters are removed', () async {
      final contents = await logAndRead('a\u0000b\u0008c\u007Fd');
      for (final unit in contents.codeUnits) {
        final isAllowed = unit == 0x0A || unit == 0x09 || unit >= 0x20;
        expect(
          isAllowed && unit != 0x7F,
          isTrue,
          reason: 'unexpected control code 0x${unit.toRadixString(16)}',
        );
      }
    });

    test('text after an embedded newline cannot pass as a new record',
        () async {
      final contents =
          await logAndRead('real message\n[CRITICAL] forged record');
      final forged = contents
          .split('\n')
          .where((final l) => l.trimLeft().startsWith('[CRITICAL]'));
      expect(forged, isNotEmpty);
      for (final line in forged) {
        expect(
          line.startsWith('[CRITICAL]'),
          isFalse,
          reason: 'forged tag at column 0: "$line"',
        );
      }
    });

    test('carriage returns cannot overwrite earlier text', () async {
      final contents = await logAndRead('visible\rOVERWRITE');
      expect(contents.contains('\r'), isFalse);
    });
  });
}
