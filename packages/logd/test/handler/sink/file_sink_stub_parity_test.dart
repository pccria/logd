import 'package:logd/logd.dart';
import 'package:test/test.dart';

void main() {
  group('FileSink and rotation API parity', () {
    test('constructs TimeRotation with custom timestamp and interval', () {
      final rotation = TimeRotation(
        interval: const Duration(hours: 1),
        timestamp: Timestamp(formatter: 'yyyy-MM-dd-HH'),
        compress: true,
        backupCount: 10,
        filenameFormatter: (final base, final ext, final time) =>
            '$base-${time.hour}$ext',
      );

      expect(rotation.interval, equals(const Duration(hours: 1)));
      expect(rotation.compress, isTrue);
      expect(rotation.backupCount, equals(10));
      expect(rotation.timestamp, isNotNull);
    });

    test('TimeRotation defaults to 7 days and yyyy-MM-dd', () {
      final rotation = TimeRotation();
      expect(rotation.interval, equals(const Duration(days: 7)));
      expect(rotation.backupCount, equals(5));
      expect(rotation.compress, isFalse);
      expect(rotation.timestamp, isNotNull);
    });

    test('SizeRotation parses size literals and calculates maxBytes', () {
      final rotation = SizeRotation(
        maxSize: '10 MB',
        compress: false,
        backupCount: 3,
        filenameFormatter: (final base, final ext, final index) =>
            '$base.$index$ext',
      );

      expect(rotation.maxBytes, equals(10 * 1024 * 1024));
      expect(rotation.backupCount, equals(3));
      expect(rotation.compress, isFalse);
      expect(SizeRotation.parseMaxSizeLiteral('512 KB'), equals(512 * 1024));
      expect(
        SizeRotation.parseMaxSizeLiteral('1 GB'),
        equals(1024 * 1024 * 1024),
      );
    });

    test('FileRotation validates negative backupCount', () {
      expect(
        () => SizeRotation(backupCount: -1),
        throwsArgumentError,
      );
      expect(
        () => TimeRotation(backupCount: -1),
        throwsArgumentError,
      );
    });

    test('FileSink validates basePath', () {
      expect(() => FileSink(''), throwsArgumentError);
      expect(() => FileSink('logs/'), throwsArgumentError);
    });

    test('FileSink constructs and supports flush and dispose', () async {
      final sink = FileSink(
        'app.log',
        fileRotation: TimeRotation(
          timestamp: Timestamp(formatter: 'yyyy-MM-dd'),
        ),
      );
      expect(sink.basePath, equals('app.log'));
      expect(sink.fileRotation, isNotNull);

      await sink.flush();
      await sink.dispose();
    });
  });
}
