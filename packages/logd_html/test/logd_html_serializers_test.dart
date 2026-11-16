import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:test/test.dart';

void main() {
  group('LoggerSerializationRegistry for logd_html', () {
    setUp(() {
      registerLogdHtmlSerializers();
    });

    test('round-trips HtmlFormatter with properties intact', () {
      const original = HtmlFormatter(title: 'Custom HTML Output');

      final json = LoggerSerializationRegistry.serializeFormatter(original);

      expect(json['type'], 'HtmlFormatter');
      expect((json['config'] as Map)['title'], 'Custom HTML Output');

      final deserialized = LoggerSerializationRegistry.deserializeFormatter(
        json,
      );
      expect(deserialized, isA<HtmlFormatter>());
      expect((deserialized as HtmlFormatter).title, 'Custom HTML Output');
    });
  });
}
