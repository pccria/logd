import 'package:logd/logd.dart';
import 'package:test/test.dart';

void main() {
  group('LogFilter Equality & HashCode', () {
    test('LevelFilter equality and hashCode', () {
      final filter1 = LevelFilter(LogLevel.values[1]);
      final filter2 = LevelFilter(LogLevel.values[1]);
      final filterDiff = LevelFilter(LogLevel.values[2]);

      expect(filter1, equals(filter2));
      expect(filter1.hashCode, equals(filter2.hashCode));
      expect(filter1, isNot(equals(filterDiff)));
    });

    test('ContextFilter equality and hashCode', () {
      final key = ['user', 'id'].join('_');
      final filter1 = ContextFilter(key, value: '42', exclude: false);
      final filter2 = ContextFilter(key, value: '42', exclude: false);
      final filterDiffKey = ContextFilter(
        ['tenant', 'id'].join('_'),
        value: '42',
        exclude: false,
      );
      final filterDiffVal = ContextFilter(key, value: '99', exclude: false);
      final filterDiffExclude = ContextFilter(key, value: '42', exclude: true);

      expect(filter1, equals(filter2));
      expect(filter1.hashCode, equals(filter2.hashCode));
      expect(filter1, isNot(equals(filterDiffKey)));
      expect(filter1, isNot(equals(filterDiffVal)));
      expect(filter1, isNot(equals(filterDiffExclude)));
    });

    test('Handler equality preserves match when filters are recreated', () {
      final sink = MemorySink();
      final filterA = LevelFilter(LogLevel.values[1]);
      final filterB = LevelFilter(LogLevel.values[1]);
      final envKey = ['env', 'name'].join('_');
      final handler1 = Handler(
        formatter: const PlainFormatter(),
        sink: sink,
        filters: [
          filterA,
          ContextFilter(envKey, value: 'prod'),
        ],
      );

      final handler2 = Handler(
        formatter: const PlainFormatter(),
        sink: sink,
        filters: [
          filterB,
          ContextFilter(envKey, value: 'prod'),
        ],
      );

      expect(handler1, equals(handler2));
      expect(handler1.hashCode, equals(handler2.hashCode));
    });
  });
}
