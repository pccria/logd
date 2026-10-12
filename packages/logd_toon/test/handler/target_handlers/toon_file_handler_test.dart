import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

void main() {
  group('ToonFileHandler', () {
    late Directory tempDir;
    late String testLogPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_toon_test_');
      testLogPath = '${tempDir.path}/handler_test.toon';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('synchronous handler writes TOON to file', () async {
      final handler = ToonFileHandler(
        path: testLogPath,
        formatter: const ToonFormatter(explicitSchema: true),
      );

      Logger.configure('test.sync', handlers: [handler]);
      final logger = Logger.get('test.sync');

      logger.info('hello file');
      await handler.dispose();

      await Future.delayed(const Duration(milliseconds: 100));

      final file = File(testLogPath);
      expect(file.existsSync(), isTrue);

      final contents = file.readAsStringSync();
      expect(contents, contains('logs[]{'));
      expect(contents, contains('hello file'));
    });

    test('asynchronous handler offloads to isolate', () async {
      registerLogdToonSerializers();

      final handler = ToonFileHandler.async(
        path: testLogPath,
        formatter: const ToonFormatter(explicitSchema: true),
      );

      expect(handler, isA<AsyncHandler>());

      Logger.configure('test.async', handlers: [handler]);
      final logger = Logger.get('test.async');

      await handler.ready;

      logger.info('hello async file');
      await handler.dispose();

      await Future.delayed(const Duration(milliseconds: 100));

      final file = File(testLogPath);
      expect(file.existsSync(), isTrue);

      final contents = file.readAsStringSync();
      expect(contents, contains('logs[]{'));
      expect(contents, contains('hello async file'));
    });
  });
}
