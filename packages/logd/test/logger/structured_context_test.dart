// ignore_for_file: cascade_invocations
import 'dart:convert';
import 'package:logd/logd.dart';
import 'package:logd/src/handler/handler.dart';
import 'package:test/test.dart';

import '../handler/test_helpers.dart';

void main() {
  group('Structured Context Support', () {
    setUp(() {
      Logger.reset();
    });

    test('Log methods propagate context to LogEntry', () async {
      final logCollector = _MemorySink();
      Logger.configure(
        'context_test',
        handlers: [
          Handler(
            formatter: const JsonFormatter(metadata: {}),
            sink: logCollector,
          ),
        ],
      );

      final logger = Logger.get('context_test');
      logger.info('User login', context: {'userId': 42, 'role': 'admin'});

      // Allow async handler dispatch
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(logCollector.entries, isNotEmpty);
      final entry = logCollector.entries.first;
      expect(entry.message, equals('User login'));
      expect(entry.context, equals({'userId': 42, 'role': 'admin'}));

      final jsonMap = logCollector.decodedOutputs.first;
      expect(jsonMap['message'], equals('User login'));
      expect(jsonMap['context'], equals({'userId': 42, 'role': 'admin'}));
    });

    test('All logging levels support context', () async {
      final logCollector = _MemorySink();
      Logger.configure(
        'context_all',
        logLevel: LogLevel.trace,
        handlers: [
          Handler(
            formatter: const JsonFormatter(metadata: {}),
            sink: logCollector,
          ),
        ],
      );

      final logger = Logger.get('context_all');
      logger.trace('msg1', context: {'a': 1});
      logger.debug('msg2', context: {'b': 2});
      logger.warning('msg3', context: {'c': 3});
      logger.error('msg4', context: {'d': 4});

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(logCollector.entries, hasLength(4));
      expect(logCollector.entries[0].context, equals({'a': 1}));
      expect(logCollector.entries[1].context, equals({'b': 2}));
      expect(logCollector.entries[2].context, equals({'c': 3}));
      expect(logCollector.entries[3].context, equals({'d': 4}));
    });

    test('LogEntry reset clears context', () {
      final entry = Arena.instance.checkoutLogEntry(
        loggerName: 'test',
        origin: 'test.dart:1',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2026-03-22',
        context: {'userId': 42},
      );

      expect(entry.context, equals({'userId': 42}));

      Arena.instance.releaseLogEntry(entry);

      // Verify the next checkout gets a clean entry (either recycled or fresh)
      final cleanEntry = Arena.instance.checkoutLogEntry(
        loggerName: 'test2',
        origin: 'test.dart:1',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2026-03-22',
      );
      expect(cleanEntry.context, isNull);
    });

    test('LogEntry copyWith copies context', () {
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'test.dart:1',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2026-03-22',
        context: {'userId': 42},
      );

      final copy = entry.copyWith();
      expect(copy.context, equals({'userId': 42}));

      final modified = entry.copyWith(context: {'role': 'user'});
      expect(modified.context, equals({'role': 'user'}));
    });

    group('LogBuffer Context Integration', () {
      test('LogBuffer merges and flushes context map', () async {
        final logCollector = _MemorySink();
        Logger.configure(
          'buf_context',
          handlers: [
            Handler(
              formatter: const PlainFormatter(metadata: {}),
              sink: logCollector,
            ),
          ],
        );

        final logger = Logger.get('buf_context');
        final buffer = logger.infoBuffer!
          ..writeln('line 1')
          ..writeln('line 2');

        buffer.context = {'initial': 'value'};
        buffer.addContext({'extra': 'info'});

        buffer.sink();

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(logCollector.entries, isNotEmpty);
        final entry = logCollector.entries.first;
        expect(entry.context, equals({'initial': 'value', 'extra': 'info'}));
      });
    });

    group('Formatter Outputs', () {
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'main.dart:10',
        level: LogLevel.info,
        message: 'Hello',
        timestamp: '2026-06-21',
        context: {
          'userId': 42,
          'nested': {'active': true},
        },
      );

      test('JsonFormatter nests context', () {
        const formatter = JsonFormatter(metadata: {});
        final doc = formatDoc(formatter, entry);
        try {
          final layout = TerminalLayout(width: 1024, factory: Arena.instance);
          final lines = layout.layout(doc, LogLevel.info).lines;
          final json = lines.first.toString();
          final decoded = jsonDecode(json) as Map<String, dynamic>;

          expect(decoded['message'], equals('Hello'));
          expect(
            decoded['context'],
            equals({
              'userId': 42,
              'nested': {'active': true},
            }),
          );
        } finally {
          doc.releaseRecursive(Arena.instance);
        }
      });

      test('JsonPrettyFormatter nests context', () {
        const formatter = JsonPrettyFormatter(metadata: {});
        final doc = formatDoc(formatter, entry);
        try {
          final layout = TerminalLayout(width: 1024, factory: Arena.instance);
          final output = layout
              .layout(doc, LogLevel.info)
              .lines
              .map((final l) => l.toString())
              .join('\n');

          expect(output, contains('"context": {'));
          expect(output, contains('"userId": 42'));
          expect(output, contains('"nested": {'));
          expect(output, contains('"active":true'));
        } finally {
          doc.releaseRecursive(Arena.instance);
        }
      });

      test('PlainFormatter appends context to message', () {
        const formatter = PlainFormatter(metadata: {});
        final doc = formatDoc(formatter, entry);
        try {
          final layout = TerminalLayout(width: 1024, factory: Arena.instance);
          final lines = layout.layout(doc, LogLevel.info).lines;
          final output = lines.first.toString();

          expect(
            output,
            contains('Hello {userId: 42, nested: {active: true}}'),
          );
        } finally {
          doc.releaseRecursive(Arena.instance);
        }
      });
    });
  });
}

base class _MemorySink extends LogSink<LogDocument> {
  final List<LogEntry> entries = [];
  final List<Map<String, dynamic>> decodedOutputs = [];

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    // Preserve entry by copying (as the original is recycled in the pool)
    entries.add(entry.copyWith());

    const encoder = JsonEncoder();
    final context = HandlerContext();
    encoder.encode(entry, document, level, context, factory, width: 80);
    final output = const Utf8Decoder().convert(context.takeBytes());
    try {
      final decoded = jsonDecode(output) as Map<String, dynamic>;
      decodedOutputs.add(decoded);
    } catch (_) {}
  }
}
