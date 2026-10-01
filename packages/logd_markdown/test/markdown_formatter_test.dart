// ignore_for_file: experimental_member_use

import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownFormatter', () {
    final entry = LogEntry(
      loggerName: 'doc.builder',
      origin: 'build.dart',
      level: LogLevel.info,
      message: 'Compiling markdown docs',
      timestamp: '2026-08-15 12:00:00.000',
    );

    test('instantiates with defaults', () {
      const formatter = MarkdownFormatter();

      expect(
        formatter.metadata,
        unorderedEquals([
          LogMetadata.timestamp,
          LogMetadata.logger,
          LogMetadata.origin,
        ]),
      );
    });

    test('supports custom metadata', () {
      const customMeta = {LogMetadata.timestamp};
      const formatter = MarkdownFormatter(metadata: customMeta);

      expect(formatter.metadata, equals(customMeta));
    });

    test('formats entry and attaches MarkdownEncoder to document metadata', () {
      const formatter = MarkdownFormatter();
      const factory = StandardPipelineFactory();
      final doc = factory.checkoutDocument();

      try {
        formatter.format(entry, doc, factory);

        expect(doc.metadata.containsKey(AutoEncoder.encoderKey), isTrue);
        final encoder = doc.metadata[AutoEncoder.encoderKey];
        expect(encoder, isA<MarkdownEncoder>());

        // Check that structured nodes were populated in document
        expect(doc.nodes.isNotEmpty, isTrue);
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('equality and hashCode contracts', () {
      const formatter1 = MarkdownFormatter(metadata: {LogMetadata.timestamp});
      const formatter2 = MarkdownFormatter(metadata: {LogMetadata.timestamp});
      const formatter3 = MarkdownFormatter(metadata: {LogMetadata.logger});

      expect(formatter1, equals(formatter2));
      expect(formatter1.hashCode, equals(formatter2.hashCode));
      expect(formatter1, isNot(equals(formatter3)));
    });
  });
}
