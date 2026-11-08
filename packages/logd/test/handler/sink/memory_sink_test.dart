import 'package:logd/logd.dart';
import 'package:test/test.dart';

void main() {
  group('MemorySink Tests', () {
    const factory = StandardPipelineFactory();
    final doc = StandardDocument();

    test('constructor validates capacity', () {
      expect(() => MemorySink(capacity: 0), throwsArgumentError);
      expect(() => MemorySink(capacity: -10), throwsArgumentError);
      final sink = MemorySink(capacity: 50);
      expect(sink.capacity, equals(50));
    });

    test('retains log entries up to capacity', () async {
      final sink = MemorySink(capacity: 3);
      final entry1 = LogEntry(
        message: 'log 1',
        level: LogLevel.info,
        loggerName: 'test',
        origin: 'test',
        timestamp: '2026-07-29T11:00:00Z',
      );
      final entry2 = LogEntry(
        message: 'log 2',
        level: LogLevel.debug,
        loggerName: 'test',
        origin: 'test',
        timestamp: '2026-07-29T11:00:01Z',
      );

      await sink.output(doc, entry1, LogLevel.info, factory);
      await sink.output(doc, entry2, LogLevel.debug, factory);

      expect(sink.entries, hasLength(2));
      expect(sink.entries[0].message, equals('log 1'));
      expect(sink.entries[1].message, equals('log 2'));
    });

    test('drops oldest entry on capacity overflow (FIFO)', () async {
      final sink = MemorySink(capacity: 2);

      for (var i = 1; i <= 4; i++) {
        final entry = LogEntry(
          message: 'msg $i',
          level: LogLevel.info,
          loggerName: 'test',
          origin: 'test',
          timestamp: '2026-07-29T11:00:00Z',
        );
        await sink.output(doc, entry, LogLevel.info, factory);
      }

      expect(sink.entries, hasLength(2));
      expect(sink.entries[0].message, equals('msg 3'));
      expect(sink.entries[1].message, equals('msg 4'));
    });

    test('clear() removes all retained entries', () async {
      final sink = MemorySink(capacity: 10);
      final entry = LogEntry(
        message: 'to clear',
        level: LogLevel.warning,
        loggerName: 'test',
        origin: 'test',
        timestamp: '2026-07-29T11:00:00Z',
      );

      await sink.output(doc, entry, LogLevel.warning, factory);
      expect(sink.entries, hasLength(1));

      sink.clear();
      expect(sink.entries, isEmpty);
    });

    test('enabled: false ignores incoming logs', () async {
      final sink = MemorySink(capacity: 10, enabled: false);
      final entry = LogEntry(
        message: 'ignored',
        level: LogLevel.error,
        loggerName: 'test',
        origin: 'test',
        timestamp: '2026-07-29T11:00:00Z',
      );

      await sink.output(doc, entry, LogLevel.error, factory);
      expect(sink.entries, isEmpty);
    });

    test('equality and hashcode (identity equality for stateful sink)', () {
      final sink1 = MemorySink(capacity: 100);
      final sink2 = MemorySink(capacity: 100);

      expect(sink1, equals(sink1));
      expect(sink1.hashCode, equals(sink1.hashCode));
      expect(sink1, isNot(equals(sink2)));
    });
  });
}
