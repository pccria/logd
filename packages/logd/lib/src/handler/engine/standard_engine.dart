part of 'engine.dart';

/// A [LogEngine] that utilizes Dart language's standard heap allocation.
///
/// This implementation relies on the language's native garbage collector for
/// object lifecycle management. It is designed for optimal readability and
/// maintainability, making it the suitable default for most applications where
/// main-thread GC pressure is not a primary constraint.
class StandardEngine implements LogEngine {
  /// A [LogEngine] that uses standard heap allocation.
  ///
  /// This engine is optimized for readability and maintainability. It is the
  /// recommended starting point for new features or non-performance-critical
  /// environments.
  const StandardEngine();

  @override
  LogPipelineFactory get factory => const StandardPipelineFactory();

  @override
  Future<void> execute(
    final LogEntry entry,
    final LogFormatter formatter,
    final List<LogDecorator> decorators,
    final LogSink sink,
  ) async {
    final document = factory.checkoutDocument();

    try {
      // 1. Format
      formatter.format(entry, document, factory);

      // 2. Decorate
      if (decorators.isNotEmpty) {
        DecoratorPipeline.of(decorators).apply(document, entry, factory);
      }

      // 3. Output
      if (document.nodes.isNotEmpty) {
        await sink.output(document, entry, entry.level, factory);
      }
    } finally {
      factory.release(document);
    }
  }
}

/// A [LogPipelineFactory] that uses standard heap allocation (no pooling).
///
/// This is used by the [StandardEngine] for simple, readable, but
/// higher-churn logging.
class StandardPipelineFactory implements LogPipelineFactory {
  const StandardPipelineFactory();

  @override
  LogDocument checkoutDocument() => StandardDocument();

  @override
  HeaderNode checkoutHeader() => HeaderNode(segments: []);

  @override
  MessageNode checkoutMessage() => MessageNode(segments: []);

  @override
  ErrorNode checkoutError() => ErrorNode(segments: []);

  @override
  FooterNode checkoutFooter() => FooterNode(segments: []);

  @override
  MetadataNode checkoutMetadata() => MetadataNode(segments: []);

  @override
  BoxNode checkoutBox() => BoxNode(children: []);

  @override
  IndentationNode checkoutIndentation() => IndentationNode(children: []);

  @override
  GroupNode checkoutGroup() => GroupNode(children: []);

  @override
  DecoratedNode checkoutDecorated() => DecoratedNode(children: []);

  @override
  ParagraphNode checkoutParagraph() => ParagraphNode(children: []);

  @override
  RowNode checkoutRow() => RowNode(children: []);

  @override
  SectionNode checkoutSection() =>
      SectionNode(summary: ParagraphNode(children: []), children: []);

  @override
  FillerNode checkoutFiller() => FillerNode('');

  @override
  MapNode checkoutMap() => MapNode({});

  @override
  ListNode checkoutList() => ListNode([]);

  @override
  AlignmentNode checkoutAlignment() => AlignmentNode(children: []);

  @override
  TableNode checkoutTable() => TableNode(children: []);

  @override
  TableRowNode checkoutTableRow() => TableRowNode(children: []);

  @override
  TableCellNode checkoutTableCell() => TableCellNode(children: []);

  @override
  Map<K, V> checkoutDataMap<K, V>() => <K, V>{};

  @override
  List<T> checkoutDataList<T>() => <T>[];

  @override
  Set<T> checkoutDataSet<T>() => <T>{};

  @override
  HandlerContext checkoutContext() => HandlerContext();

  @override
  // ignore: prefer_const_constructors
  PhysicalDocument checkoutPhysicalDocument() => PhysicalDocument(lines: []);

  @override
  // ignore: prefer_const_constructors
  PhysicalLine checkoutPhysicalLine() => PhysicalLine(segments: []);

  @override
  void release(final Object obj) {
    // No-op for standard heap allocation Engines.
  }
}
