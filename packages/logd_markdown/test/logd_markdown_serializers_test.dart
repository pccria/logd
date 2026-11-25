import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('LoggerSerializationRegistry for logd_markdown', () {
    setUp(() {
      registerLogdMarkdownSerializers();
    });

    test('round-trips MarkdownFormatter correctly', () {
      const original = MarkdownFormatter(
        metadata: {LogMetadata.timestamp, LogMetadata.logger},
        dialect: MarkdownDialect.commonmark,
        contextLanguage: 'yaml',
      );

      final json = LoggerSerializationRegistry.serializeFormatter(original);

      expect(json['type'], 'MarkdownFormatter');

      final deserialized = LoggerSerializationRegistry.deserializeFormatter(
        json,
      );
      expect(deserialized, equals(original));
    });

    test('round-trips MarkdownTableFormatter correctly', () {
      const original = MarkdownTableFormatter(
        metadata: {LogMetadata.timestamp, LogMetadata.origin},
        includeContext: false,
        dialect: MarkdownDialect.gitlab,
      );

      final json = LoggerSerializationRegistry.serializeFormatter(original);

      expect(json['type'], 'MarkdownTableFormatter');

      final deserialized = LoggerSerializationRegistry.deserializeFormatter(
        json,
      );
      expect(deserialized, equals(original));
    });
  });
}
