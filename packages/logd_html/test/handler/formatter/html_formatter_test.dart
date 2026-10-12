// ignore_for_file: experimental_member_use

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlFormatter', () {
    final entry = LogEntry(
      loggerName: 'web.service',
      origin: 'server.dart',
      level: LogLevel.info,
      message: 'Server started on port 8080',
      timestamp: '2026-08-15 12:00:00.000',
    );

    test('instantiates with defaults', () {
      const formatter = HtmlFormatter();

      expect(formatter.title, equals('Log Output'));
      expect(formatter.stylesheet, isA<DefaultHtmlStylesheet>());
      expect(
        formatter.metadata,
        unorderedEquals([
          LogMetadata.timestamp,
          LogMetadata.logger,
          LogMetadata.origin,
        ]),
      );
    });

    test('supports custom title and metadata', () {
      const customMeta = {LogMetadata.timestamp};
      const formatter = HtmlFormatter(
        title: 'Custom Dashboard',
        metadata: customMeta,
      );

      expect(formatter.title, equals('Custom Dashboard'));
      expect(formatter.metadata, equals(customMeta));
    });

    test('formats entry and attaches HtmlEncoder to document metadata', () {
      const formatter = HtmlFormatter(title: 'Audit Log');
      const factory = StandardPipelineFactory();
      final doc = factory.checkoutDocument();

      try {
        formatter.format(entry, doc, factory);

        expect(doc.metadata.containsKey(AutoEncoder.encoderKey), isTrue);
        final encoder = doc.metadata[AutoEncoder.encoderKey];
        expect(encoder, isA<HtmlEncoder>());
        expect((encoder! as HtmlEncoder).title, equals('Audit Log'));

        // Check that structured nodes were populated in document
        expect(doc.nodes.isNotEmpty, isTrue);
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('equality and hashCode contracts', () {
      const formatter1 = HtmlFormatter(title: 'Same Title');
      const formatter2 = HtmlFormatter(title: 'Same Title');
      const formatter3 = HtmlFormatter(title: 'Different Title');

      expect(formatter1, equals(formatter2));
      expect(formatter1.hashCode, equals(formatter2.hashCode));
      expect(formatter1, isNot(equals(formatter3)));
    });
  });
}
