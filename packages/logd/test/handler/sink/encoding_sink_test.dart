import 'package:logd/src/handler/handler.dart';
import 'package:logd/src/logger/logger.dart';
import 'package:test/test.dart';

class CustomTestEncoder implements LogEncoder {
  const CustomTestEncoder(this.wrappingStrategy);

  @override
  final WrappingStrategy wrappingStrategy;

  @override
  void preamble(
    final HandlerContext context,
    final LogLevel level,
    final LogPipelineFactory factory, {
    final LogDocument? document,
  }) {}

  @override
  void postamble(
    final HandlerContext context,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) {}

  @override
  void encode(
    final LogEntry entry,
    final LogDocument document,
    final LogLevel level,
    final HandlerContext context,
    final LogPipelineFactory factory, {
    final int? width,
  }) {}
}

void main() {
  group('EncodingSink strategy', () {
    test('uses encoder.wrappingStrategy when document', () {
      const encoder = CustomTestEncoder(WrappingStrategy.document);
      final sink = EncodingSink(
        encoder: encoder,
        delegate: (final data) {},
      );
      expect(sink.strategy, equals(WrappingStrategy.document));
    });

    test('uses encoder.wrappingStrategy when none', () {
      const encoder = CustomTestEncoder(WrappingStrategy.none);
      final sink = EncodingSink(
        encoder: encoder,
        delegate: (final data) {},
      );
      expect(sink.strategy, equals(WrappingStrategy.none));
    });

    test('AutoConsoleEncoder wrappingStrategy is WrappingStrategy.document',
        () {
      final sink = EncodingSink(
        encoder: const AutoConsoleEncoder(),
        delegate: (final data) {},
      );
      expect(sink.strategy, equals(WrappingStrategy.document));
    });

    test('EncodingSink asserts preferredWidth is positive', () {
      expect(
        () => EncodingSink(
          encoder: const CustomTestEncoder(WrappingStrategy.none),
          delegate: (final data) {},
          preferredWidth: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Handler asserts timeout is non-negative during log', () {
      const handler = Handler(
        formatter: PlainFormatter(),
        sink: ConsoleSink(),
        timeout: Duration(seconds: -1),
      );
      final entry = LogEntry(
        message: 'test',
        level: LogLevel.info,
        loggerName: 'test',
        origin: 'test',
        timestamp: '2026-07-29T11:00:00Z',
      );
      expect(
        () => handler.log(entry),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
