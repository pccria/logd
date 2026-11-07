import 'dart:async';
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

        final count = RegExp('===PREAMBLE===').allMatches(activeContent).length;
        expect(
          count,
          equals(1),
          reason: 'Preamble should appear exactly once in the new active file',
        );
      },
    );

    test(
      '(b1) when a second FileSink with a document-wrapping encoder writes '
      'while another active FileSink with a wrapping encoder has also written, '
      'a warning is logged',
      () async {
        final sink1 = FileSink(
          filePath,
          encoder: const _WrappingTestEncoder(),
        );
        final sink2 = FileSink(
          filePath,
          encoder: const _WrappingTestEncoder(),
        );

        final capturedWarnings = <String>[];

        await runZoned(
          () async {
            const factory = StandardPipelineFactory();
            final entry1 = LogEntry(
              level: LogLevel.info,
              message: 'First sink writes',
              loggerName: 'test',
              origin: 'test',
              timestamp: '2026-11-07T00:00:00Z',
            );
            final doc1 = StandardDocument();
            await sink1.output(doc1, entry1, LogLevel.info, factory);

            final entry2 = LogEntry(
              level: LogLevel.info,
              message: 'Second sink writes',
              loggerName: 'test',
              origin: 'test',
              timestamp: '2026-11-07T00:00:00Z',
            );
            final doc2 = StandardDocument();
            await sink2.output(doc2, entry2, LogLevel.info, factory);
          },
          zoneSpecification: ZoneSpecification(
            print: (final self, final parent, final zone, final line) {
              capturedWarnings.add(line);
            },
          ),
        );

        expect(
          capturedWarnings,
          anyElement(
            allOf(
              contains('[WARNING]'),
              contains('document-wrapping'),
            ),
          ),
          reason: 'Internal warning should be emitted when multiple writing '
              'wrapping FileSinks are active for the same path',
        );

        await sink1.dispose();
        await sink2.dispose();
      },
    );

    test(
      '(b3) reconfiguring a logger to a new wrapped FileSink on the same path '
      'does not emit a warning',
      () async {
        final capturedWarnings = <String>[];

        await runZoned(
          () async {
            final sink1 = FileSink(
              filePath,
              encoder: const _WrappingTestEncoder(),
            );
            final handler1 = Handler(
              formatter: const PlainFormatter(),
              sink: sink1,
            );
            Logger.configure('test.f72.reconfig', handlers: [handler1]);
            Logger.get('test.f72.reconfig').info('First handler write');
            await handler1.flush();

            // Reconfiguration: create new handler before disposing old handler
            final sink2 = FileSink(
              filePath,
              encoder: const _WrappingTestEncoder(),
            );
            final handler2 = Handler(
              formatter: const PlainFormatter(),
              sink: sink2,
            );
            await handler1.dispose();

            Logger.configure('test.f72.reconfig', handlers: [handler2]);
            Logger.get('test.f72.reconfig').info('Second handler write');
            await handler2.flush();
            await handler2.dispose();
          },
          zoneSpecification: ZoneSpecification(
            print: (final self, final parent, final zone, final line) {
              capturedWarnings.add(line);
            },
          ),
        );

        expect(
          capturedWarnings.where((final l) => l.contains('document-wrapping')),
          isEmpty,
          reason: 'No warning should be emitted during normal reconfiguration',
        );
      },
    );

    test(
      '(b2) two FileSinks on the same path with a NON-wrapping '
      '(plain text) encoder both write their entries and rotation '
      'produces valid files',
      () async {
        final sink1 = FileSink(
          filePath,
          encoder: const PlainTextEncoder(),
          fileRotation: SizeRotation(maxSize: '800 B', backupCount: 2),
        );
        final sink2 = FileSink(
          filePath,
          encoder: const PlainTextEncoder(),
          fileRotation: SizeRotation(maxSize: '800 B', backupCount: 2),
        );

        final handler1 = Handler(
          formatter: const PlainFormatter(),
          sink: sink1,
        );
        final handler2 = Handler(
          formatter: const PlainFormatter(),
          sink: sink2,
        );

        final logger1 = Logger.get('test.f72.b2_1');
        Logger.configure('test.f72.b2_1', handlers: [handler1]);

        final logger2 = Logger.get('test.f72.b2_2');
        Logger.configure('test.f72.b2_2', handlers: [handler2]);

        // Write through logger1 (~288 B)
        logger1.info('Entry 1 from sink1 - ${'A' * 100}');
        await handler1.flush();

        // Write through logger2 (~288 B, total ~576 B < 800 B)
        logger2.info('Entry 1 from sink2 - ${'B' * 100}');
        await handler2.flush();

        // Write through logger1 to exceed 800 B and trigger rotation
        logger1.info('Entry 2 from sink1 - ${'C' * 100}');
        await handler1.flush();

        // Write through logger2 into active file (total 576 B < 800 B)
        logger2.info('Entry 2 from sink2 - ${'D' * 100}');
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
        expect(rotatedContent, isNotEmpty);
        expect(rotatedContent, contains('Entry 1 from sink1'));
        expect(rotatedContent, contains('Entry 1 from sink2'));

        final activeFile = File(filePath);
        expect(
          activeFile.existsSync(),
          isTrue,
          reason: 'Active log file should exist',
        );
        final activeContent = activeFile.readAsStringSync();
        expect(activeContent, isNotEmpty);
        expect(activeContent, contains('Entry 2 from sink1'));
        expect(activeContent, contains('Entry 2 from sink2'));
      },
    );
  });
}
