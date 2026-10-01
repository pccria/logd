import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlFileHandler', () {
    late Directory tempDir;
    late String testLogPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_html_test_');
      testLogPath = '${tempDir.path}/handler_test.html';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('synchronous handler writes HTML to file', () async {
      final handler = HtmlFileHandler(
        path: testLogPath,
        title: 'Sync Test',
      );

      Logger.configure('test.sync', handlers: [handler]);

      Logger.get('test.sync').info('hello html');
      await handler.dispose();

      await Future.delayed(const Duration(milliseconds: 100));

      final file = File(testLogPath);
      expect(file.existsSync(), isTrue);

      final contents = file.readAsStringSync();
      expect(contents, contains('<!DOCTYPE html>'));
      expect(contents, contains('hello html'));
    });

    test('asynchronous handler offloads to isolate', () async {
      final handler = HtmlFileHandler.async(
        path: testLogPath,
        title: 'Async Test',
      );

      expect(handler, isA<AsyncHandler>());

      Logger.configure('test.async', handlers: [handler]);
      final logger = Logger.get('test.async');

      await handler.ready;

      logger.info('hello async html');
      await handler.dispose();

      await Future.delayed(const Duration(milliseconds: 100));

      final file = File(testLogPath);
      expect(file.existsSync(), isTrue);

      final contents = file.readAsStringSync();
      expect(contents, contains('<!DOCTYPE html>'));
      expect(contents, contains('hello async html'));
    });
  });
}
