import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('LoggerSerializationRegistry for logd_markdown', () {
    setUp(() {
      registerLogdMarkdownSerializers();
    });

    test('round-trips MarkdownFormatter correctly', () {
      final original = const MarkdownFormatter(
        metadata: {LogMetadata.timestamp, LogMetadata.logger},
      );

      final json = LoggerSerializationRegistry.serializeFormatter(original);

      expect(json['type'], 'MarkdownFormatter');

      final deserialized =
          LoggerSerializationRegistry.deserializeFormatter(json);
      expect(deserialized, equals(original));
    });
  });
}
