import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownFileHandler', () {
    late Directory tempDir;
    late String testLogPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_markdown_test_');
      testLogPath = '${tempDir.path}/handler_test.md';
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('MarkdownFileHandler creates a valid synchronous Handler', () async {
      final handler = MarkdownFileHandler(path: testLogPath);

      expect(handler, isA<Handler>());
      expect(handler.formatter, isA<MarkdownFormatter>());
      expect(handler.sink, isA<FileSink>());

      Logger.configure('test.sync', handlers: [handler]);
      final logger = Logger.get('test.sync');

      logger.info('hello markdown file');
      await handler.dispose();

      await Future.delayed(const Duration(milliseconds: 100));

      final file = File(testLogPath);
      expect(file.existsSync(), isTrue);

      final contents = file.readAsStringSync();
      expect(contents, contains('hello markdown file'));
      expect(contents, contains('###'));
    });

    test('MarkdownFileHandler.async creates a valid AsyncHandler', () async {
      registerLogdMarkdownSerializers();

      final handler = MarkdownFileHandler.async(path: testLogPath);

      expect(handler, isA<AsyncHandler>());

      Logger.configure('test.async', handlers: [handler]);
      final logger = Logger.get('test.async');

      await handler.ready;

      logger.info('hello async markdown file');
      await handler.dispose();

      await Future.delayed(const Duration(milliseconds: 100));

      final file = File(testLogPath);
      expect(file.existsSync(), isTrue);

      final contents = file.readAsStringSync();
      expect(contents, contains('hello async markdown file'));
      expect(contents, contains('###'));
    });
  });
}
