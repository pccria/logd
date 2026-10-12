import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

void main() {
  group('ToonFormatter Serialization', () {
    setUpAll(() {
      registerLogdToonSerializers();
    });

    test('round-trip serialization preserves all properties', () {
      const original = ToonFormatter(
        delimiter: '|',
        arrayName: 'test_logs',
        explicitSchema: true,
        sortKeys: true,
        maxDepth: 10,
        dialect: ToonDialect.strict,
        metadata: {LogMetadata.origin, LogMetadata.logger},
      );

      final json = LoggerSerializationRegistry.serializeFormatter(original);

      final config = json['config'] as Map<String, dynamic>;

      expect(config['delimiter'], equals('|'));
      expect(config['arrayName'], equals('test_logs'));
      expect(config['explicitSchema'], isTrue);
      expect(config['sortKeys'], isTrue);
      expect(config['maxDepth'], equals(10));
      expect(config['dialect'], equals('strict'));
      expect(config['metadata'], containsAll(['origin', 'logger']));

      final recovered = LoggerSerializationRegistry.deserializeFormatter(json)
          as ToonFormatter;

      expect(recovered.delimiter, equals(original.delimiter));
      expect(recovered.arrayName, equals(original.arrayName));
      expect(recovered.explicitSchema, equals(original.explicitSchema));
      expect(recovered.sortKeys, equals(original.sortKeys));
      expect(recovered.maxDepth, equals(original.maxDepth));
      expect(recovered.dialect, equals(original.dialect));
      expect(recovered.metadata, containsAll(original.metadata));
      expect(recovered.metadata.length, equals(original.metadata.length));
    });

    test('round-trip serialization with default properties', () {
      const original = ToonFormatter();

      final json = LoggerSerializationRegistry.serializeFormatter(original);
      final recovered = LoggerSerializationRegistry.deserializeFormatter(json)
          as ToonFormatter;

      expect(recovered.delimiter, equals('\t'));
      expect(recovered.arrayName, equals('logs'));
      expect(recovered.explicitSchema, isFalse);
      expect(recovered.sortKeys, isFalse);
      expect(recovered.maxDepth, equals(5));
      expect(recovered.dialect, equals(ToonDialect.compact));
      expect(
          recovered.metadata,
          containsAll(
              [LogMetadata.timestamp, LogMetadata.logger, LogMetadata.origin]));
    });
  });
}
