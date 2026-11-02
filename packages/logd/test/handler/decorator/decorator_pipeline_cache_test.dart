import 'package:logd/logd.dart';
import 'package:logd/src/handler/decorator/decorator.dart';
import 'package:test/test.dart';

void main() {
  group('DecoratorPipeline Allocation & Caching Optimization', () {
    final entry = LogEntry(
      loggerName: 'test',
      origin: 'main',
      level: LogLevel.info,
      message: 'test message',
      timestamp: '2026-11-02T00:00:00',
    );

    test('DecoratorPipeline.of returns cached canonical instance', () {
      const decorators = [BoxDecorator(), StyleDecorator()];

      final pipeline1 = DecoratorPipeline.of(decorators);
      final pipeline2 = DecoratorPipeline.of(decorators);

      expect(identical(pipeline1, pipeline2), isTrue);
      expect(pipeline1.sortedDecorators.length, equals(2));
      // BoxDecorator (priority 1) must precede StyleDecorator (priority 4)
      expect(pipeline1.sortedDecorators.first, isA<BoxDecorator>());
      expect(pipeline1.sortedDecorators.last, isA<StyleDecorator>());
    });

    test('Handler exposes pre-compiled decoratorPipeline', () {
      const handler = Handler(
        formatter: PlainFormatter(),
        sink: ConsoleSink(),
        decorators: [StyleDecorator(), BoxDecorator()],
      );

      final pipeline = handler.decoratorPipeline;
      expect(pipeline.sortedDecorators.length, equals(2));
      expect(pipeline.sortedDecorators.first, isA<BoxDecorator>());
      expect(pipeline.sortedDecorators.last, isA<StyleDecorator>());
    });

    test('DecoratorPipeline.apply correctly decorates document using cache',
        () {
      const decorators = [BoxDecorator()];
      final pipeline = DecoratorPipeline.of(decorators);

      const factory = StandardPipelineFactory();
      final doc = factory.checkoutDocument()..text('hello cached pipeline');

      pipeline.apply(doc, entry, factory);

      // BoxDecorator adds BoxNode
      expect(doc.nodes.any((final n) => n is BoxNode), isTrue);
    });
  });
}
