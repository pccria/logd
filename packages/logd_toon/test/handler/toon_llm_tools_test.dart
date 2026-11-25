import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

void main() {
  group('ToonTokenEstimator & ToonTokenMetrics Tests', () {
    test('estimates token count on raw strings', () {
      expect(ToonTokenEstimator.estimateTokens(''), equals(0));
      expect(ToonTokenEstimator.estimateTokens('hello'), greaterThan(0));

      final shortTokens = ToonTokenEstimator.estimateTokens('short log');
      final longTokens = ToonTokenEstimator.estimateTokens(
        'a significantly longer log message with complex attributes and details',
      );
      expect(longTokens, greaterThan(shortTokens));
    });

    test('analyzes token metrics and demonstrates savings vs equivalent JSON', () {
      const sampleToon =
          'logs[]{timestamp,logger,level,message,context}:\n'
          '2026-11-25T12:00:00.000\tauth\tINFO\tUser login\t{userId:1001,ip:"192.168.1.1"}\n'
          '2026-11-25T12:00:01.000\tauth\tINFO\tToken refreshed\t{userId:1001,token:"xyz"}\n'
          '2026-11-25T12:00:02.000\tauth\tWARNING\tRate limit approaching\t{userId:1001,reqs:95}\n'
          '2026-11-25T12:00:03.000\tauth\tERROR\tRate limit exceeded\t{userId:1001,reqs:101}\n';

      final metrics = ToonTokenEstimator.analyze(sampleToon);

      expect(metrics.rowCount, equals(4));
      expect(metrics.toonTokens, greaterThan(0));
      expect(metrics.jsonTokens, greaterThan(metrics.toonTokens));
      expect(metrics.savedTokens, greaterThan(0));
      expect(metrics.savingsPercent, greaterThan(15.0));
      expect(metrics.savedBytes, greaterThan(0));

      final jsonMap = metrics.toJson();
      expect(jsonMap['savingsPercent'], equals(metrics.savingsPercent));
      expect(jsonMap['savedTokens'], equals(metrics.savedTokens));
    });
  });

  group('ToonContextWindow Sliding-Window Slicing Tests', () {
    const sampleToon =
        'logs[]{timestamp,logger,level,message}:\n'
        '2026-11-25T10:00:00\tsystem\tINFO\tEvent 1\n'
        '2026-11-25T10:00:01\tsystem\tINFO\tEvent 2\n'
        '2026-11-25T10:00:02\tsystem\tINFO\tEvent 3\n'
        '2026-11-25T10:00:03\tsystem\tINFO\tEvent 4\n'
        '2026-11-25T10:00:04\tsystem\tINFO\tEvent 5\n';

    test('slices to exact maxRows preserving preamble at line 1', () {
      final slice = ToonContextWindow.slice(sampleToon, maxRows: 2);

      expect(slice.isTruncated, isTrue);
      expect(slice.includedRows, equals(2));
      expect(slice.droppedRows, equals(3));

      final lines = slice.content.split('\n');
      expect(lines.first, equals('logs[]{timestamp,logger,level,message}:'));
      expect(slice.content, contains('Event 4'));
      expect(slice.content, contains('Event 5'));
      expect(slice.content, isNot(contains('Event 1')));
    });

    test('slices to token budget and includes truncation indicator', () {
      final slice = ToonContextWindow.slice(
        sampleToon,
        maxTokens: 50,
        truncationIndicator: '... [TRUNCATED] ...',
      );

      expect(
        slice.content.startsWith('logs[]{timestamp,logger,level,message}:'),
        isTrue,
      );
      expect(slice.estimatedTokens, lessThanOrEqualTo(50));
      if (slice.isTruncated) {
        expect(slice.content, contains('... [TRUNCATED] ...'));
      }
    });

    test('retains all rows when budget exceeds total content', () {
      final slice = ToonContextWindow.slice(sampleToon, maxTokens: 5000);

      expect(slice.isTruncated, isFalse);
      expect(slice.includedRows, equals(5));
      expect(slice.droppedRows, equals(0));
      expect(slice.content, contains('Event 1'));
      expect(slice.content, contains('Event 5'));
      expect(slice.content, isNot(contains('truncated')));
    });

    test('throws FormatException on invalid source', () {
      expect(
        () => ToonContextWindow.slice(''),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
