import 'dart:io';

import 'package:logd/logd.dart';
import 'package:test/test.dart';

class _WrappingTestEncoder implements LogEncoder {
  const _WrappingTestEncoder();

  static const String preambleText = '===PREAMBLE===\n';
  static const String postambleText = '===POSTAMBLE===\n';

  @override
  WrappingStrategy get wrappingStrategy => WrappingStrategy.document;

  @override
  void preamble(
    final HandlerContext context,
    final LogLevel level,
    final LogPipelineFactory factory, {
    final LogDocument? document,
  }) {
    context.writeString(preambleText);
  }

  @override
  void postamble(
    final HandlerContext context,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) {
    context.writeString(postambleText);
  }

  @override
  void encode(
    final LogEntry entry,
    final LogDocument document,
    final LogLevel level,
    final HandlerContext context,
    final LogPipelineFactory factory, {
    final int? width,
  }) {
    context.writeString('RECORD: ${entry.message}\n');
  }
}

void main() {
  group('F-72 rotation preamble edge cases', () {
    late Directory tempDir;
    late String filePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_f72_test_');
      filePath = '${tempDir.path}/app.log';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      '(a) existing file larger than maxSize, log once, '
      'preamble appears once in new file',
      () async {
        // Create an existing file larger than maxSize (maxSize: 100 B)
        final existingFile = File(filePath);
        final initialContent = '${_WrappingTestEncoder.preambleText}'
            '${'X' * 200}\n'
            '${_WrappingTestEncoder.postambleText}';
        existingFile.writeAsStringSync(initialContent);
        expect(existingFile.lengthSync(), greaterThan(100));

        final sink = FileSink(
          filePath,
          encoder: const _WrappingTestEncoder(),
          fileRotation: SizeRotation(maxSize: '100 B', backupCount: 2),
        );
        final handler = Handler(
          formatter: const PlainFormatter(),
          sink: sink,
        );

        final logger = Logger.get('test.f72.a');
        Logger.configure('test.f72.a', handlers: [handler]);

        logger.info('Entry triggering rotation on existing oversized file');
        await handler.flush();
        await handler.dispose();

        final activeFile = File(filePath);
        expect(activeFile.existsSync(), isTrue);
        final activeContent = activeFile.readAsStringSync();

        final count =
            RegExp('===PREAMBLE===').allMatches(activeContent).length;
        expect(
          count,
          equals(1),
          reason: 'Preamble should appear exactly once in the new active file',
        );
      },
    );

    test(
      '(b) two FileSinks on the same path, rotate one, '
      'check both files are still valid documents',
      () async {
        final sink1 = FileSink(
          filePath,
          encoder: const _WrappingTestEncoder(),
          fileRotation: SizeRotation(maxSize: '100 B', backupCount: 2),
        );
        final sink2 = FileSink(
          filePath,
          encoder: const _WrappingTestEncoder(),
          fileRotation: SizeRotation(maxSize: '100 B', backupCount: 2),
        );

        final handler1 = Handler(
          formatter: const PlainFormatter(),
          sink: sink1,
        );
        final handler2 = Handler(
          formatter: const PlainFormatter(),
          sink: sink2,
        );

        final logger1 = Logger.get('test.f72.b1');
        Logger.configure('test.f72.b1', handlers: [handler1]);

        final logger2 = Logger.get('test.f72.b2');
        Logger.configure('test.f72.b2', handlers: [handler2]);

        // Write through logger1
        logger1.info('Entry from sink1 - ${'A' * 60}');
        await handler1.flush();

        // Write again through logger1 to exceed 100 B and trigger rotation
        logger1.info('Entry from sink1 causing rotation - ${'B' * 60}');
        await handler1.flush();

        // Write through logger2
        logger2.info('Entry from sink2 - ${'C' * 30}');
        await handler2.flush();

        await handler1.dispose();
        await handler2.dispose();

        final rotatedFile = File(filePath.replaceAll('.log', '.1.log'));
        expect(
          rotatedFile.existsSync(),
          isTrue,
          reason: 'Rotated backup file should exist',
        );
        final rotatedContent = rotatedFile.readAsStringSync();

        final activeFile = File(filePath);
        expect(
          activeFile.existsSync(),
          isTrue,
          reason: 'Active log file should exist',
        );
        final activeContent = activeFile.readAsStringSync();

        // Check rotated file validity as a document
        expect(
          rotatedContent.startsWith('===PREAMBLE==='),
          isTrue,
          reason: 'Rotated file must start with preamble',
        );
        expect(
          rotatedContent.trimRight().endsWith('===POSTAMBLE==='),
          isTrue,
          reason: 'Rotated file must end with postamble',
        );
        expect(
          RegExp('===PREAMBLE===').allMatches(rotatedContent).length,
          equals(1),
          reason: 'Rotated file should have exactly 1 preamble',
        );

        // Check active file validity as a document
        expect(
          activeContent.startsWith('===PREAMBLE==='),
          isTrue,
          reason: 'Active file must start with preamble',
        );
        expect(
          activeContent.trimRight().endsWith('===POSTAMBLE==='),
          isTrue,
          reason: 'Active file must end with postamble',
        );
        expect(
          RegExp('===PREAMBLE===').allMatches(activeContent).length,
          equals(1),
          reason: 'Active file should have exactly 1 preamble',
        );
      },
    );

  });
}
