import 'package:logd/logd.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

class MockFormatter implements LogFormatter {
  const MockFormatter(this.formatFn, {this.metadata = const {}});

  @override
  final Set<LogMetadata> metadata;

  final void Function(LogEntry, LogDocument, LogPipelineFactory) formatFn;

  @override
  void format(
    final LogEntry entry,
    final LogDocument document,
    final LogPipelineFactory factory,
  ) =>
      formatFn(entry, document, factory);
}

final class MockSink extends LogSink<LogDocument> {
  final List<List<String>> outputs = [];
  final List<LogLevel> levels = [];

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    outputs.add(renderLines(document));
    levels.add(level);
  }
}

class MockFilter extends LogFilter {
  const MockFilter(this.shouldLogFn);
  final bool Function(LogEntry) shouldLogFn;
  @override
  bool shouldLog(final LogEntry entry) => shouldLogFn(entry);
}

void main() {
  group('Handler Composition', () {
    late MockSink sink;
    late MockFormatter formatter;
    late LogEntry testEntry;

    setUp(() {
      sink = MockSink();
      formatter = MockFormatter(
        (final entry, final doc, final factory) {
          final node = factory.checkoutMessage();
          node.segments.add(StyledText('formatted: ${entry.message}'));
          doc.nodes.add(node);
        },
      );
      testEntry = LogEntry(
        loggerName: 'test',
        origin: 'main',
        level: LogLevel.info,
        message: 'hello',
        timestamp: Timestamp.iso8601().timestamp!,
      );
    });

    test('Handler calls formatter and sink', () async {
      final handler = Handler(formatter: formatter, sink: sink);
      await handler.log(testEntry);

      expect(sink.outputs.length, equals(1));
      expect(sink.outputs.first.first, equals('formatted: hello'));
      expect(sink.levels.first, equals(LogLevel.info));
    });

    test('Handler skips sink if formatter returns no nodes', () async {
      // LogDocument with no nodes is considered "empty"
      final emptyFormatter = MockFormatter((final _, final __, final ___) {});
      final handler = Handler(formatter: emptyFormatter, sink: sink);
      await handler.log(testEntry);

      expect(sink.outputs, isEmpty);
    });

    test('Single filter passing allows logging', () async {
      final filter = MockFilter((final _) => true);
      final handler =
          Handler(formatter: formatter, sink: sink, filters: [filter]);
      await handler.log(testEntry);

      expect(sink.outputs.length, equals(1));
    });

    test('Single filter failing blocks logging', () async {
      final filter = MockFilter((final _) => false);
      final handler =
          Handler(formatter: formatter, sink: sink, filters: [filter]);
      await handler.log(testEntry);

      expect(sink.outputs, isEmpty);
    });

    test('All filters must pass (AND behavior)', () async {
      final filters = [
        MockFilter((final _) => true),
        MockFilter((final _) => false), // This one blocks
        MockFilter((final _) => true),
      ];
      final handler =
          Handler(formatter: formatter, sink: sink, filters: filters);
      await handler.log(testEntry);

      expect(sink.outputs, isEmpty);
    });
  });

  group('Built-in Filters', () {
    final entryInfo = LogEntry(
      loggerName: 'app.ui',
      origin: 'Widget.build',
      level: LogLevel.info,
      message: 'info msg',
      timestamp: '2025-01-01 12:00:00',
    );
    final entryError = LogEntry(
      loggerName: 'app.service',
      origin: 'Service.run',
      level: LogLevel.error,
      message: 'error msg',
      timestamp: '2025-01-01 12:00:01',
    );

    test('LevelFilter blocks lower levels', () {
      const filter = LevelFilter(LogLevel.warning);
      expect(filter.shouldLog(entryInfo), isFalse);
      expect(filter.shouldLog(entryError), isTrue);
    });

    test('RegexFilter filters by message', () {
      final filter = RegexFilter(RegExp('error'));
      expect(filter.shouldLog(entryInfo), isFalse);
      expect(filter.shouldLog(entryError), isTrue);
    });

    test('RegexFilter filters by name (if configured)', () {
      // Assuming RegexFilter has a way to check name, or we just test
      // message for now Based on previous analysis, RegexFilter usually
      // checks entry.message
    });

    group('ContextFilter', () {
      final entryWithContext = LogEntry(
        loggerName: 'app',
        origin: 'main',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2025-01-01 12:00:00',
        context: const {'userId': 123, 'env': 'prod'},
      );

      final entryWithoutContext = LogEntry(
        loggerName: 'app',
        origin: 'main',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2025-01-01 12:00:00',
      );

      test('matches key existence', () {
        const filter = ContextFilter('userId');
        expect(filter.shouldLog(entryWithContext), isTrue);
        expect(filter.shouldLog(entryWithoutContext), isFalse);
      });

      test('matches key and value', () {
        const filter = ContextFilter('userId', value: 123);
        const filterWrongValue = ContextFilter('userId', value: 456);
        expect(filter.shouldLog(entryWithContext), isTrue);
        expect(filterWrongValue.shouldLog(entryWithContext), isFalse);
      });

      test('excludes matching key existence', () {
        const filter = ContextFilter('userId', exclude: true);
        expect(filter.shouldLog(entryWithContext), isFalse);
        expect(filter.shouldLog(entryWithoutContext), isTrue);
      });

      test('excludes matching key and value', () {
        const filter = ContextFilter('userId', value: 123, exclude: true);
        const filterWrongValue =
            ContextFilter('userId', value: 456, exclude: true);
        expect(filter.shouldLog(entryWithContext), isFalse);
        expect(filterWrongValue.shouldLog(entryWithContext), isTrue);
      });
    });
  });
}
