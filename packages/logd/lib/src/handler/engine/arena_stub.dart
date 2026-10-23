library;

import 'package:meta/meta.dart';

import '../../logger/logger.dart';
import '../../stack_trace/stack_trace.dart';
import '../document/document.dart';
import '../engine/engine.dart';
import '../layout/layout.dart';

/// A fallback implementation of the [Arena] resource pool for web/browser runtimes.
///
/// Under environments where FFI/IO is unsupported (such as Web/JS/WASM), this class
/// transparently falls back to using standard heap allocations
/// ([StandardDocument.pooled], etc.)
/// rather than native memory page pools. This allows logging code targeting
/// [Arena] to execute without runtime crashes on all platforms.
@experimental
class Arena implements LogPipelineFactory {
  Arena._();
  static final Arena instance = Arena._();

  LogEntry checkoutLogEntry({
    required final String loggerName,
    required final String origin,
    required final LogLevel level,
    required final String message,
    required final String timestamp,
    final List<CallbackInfo>? stackFrames,
    final Object? error,
    final StackTrace? stackTrace,
    final Map<String, dynamic>? context,
  }) =>
      LogEntry(
        loggerName: loggerName,
        origin: origin,
        level: level,
        message: message,
        timestamp: timestamp,
        stackFrames: stackFrames,
        error: error,
        stackTrace: stackTrace,
        context: context,
      );

  void releaseLogEntry(final LogEntry entry) {}

  @override
  LogDocument checkoutDocument() => StandardDocument.pooled();

  @override
  HeaderNode checkoutHeader() => HeaderNode.pooled();

  @override
  MessageNode checkoutMessage() => MessageNode.pooled();

  @override
  ErrorNode checkoutError() => ErrorNode.pooled();

  @override
  FooterNode checkoutFooter() => FooterNode.pooled();

  @override
  MetadataNode checkoutMetadata() => MetadataNode.pooled();

  @override
  BoxNode checkoutBox() => BoxNode.pooled();

  @override
  IndentationNode checkoutIndentation() => IndentationNode.pooled();

  @override
  GroupNode checkoutGroup() => GroupNode.pooled();

  @override
  DecoratedNode checkoutDecorated() => DecoratedNode.pooled();

  @override
  ParagraphNode checkoutParagraph() => ParagraphNode.pooled();

  @override
  RowNode checkoutRow() => RowNode.pooled();

  @override
  SectionNode checkoutSection() => SectionNode.pooled();

  @override
  FillerNode checkoutFiller() => FillerNode.pooled();

  @override
  MapNode checkoutMap() => MapNode.pooled();

  @override
  ListNode checkoutList() => ListNode.pooled();

  @override
  AlignmentNode checkoutAlignment() => AlignmentNode.pooled();

  @override
  TableNode checkoutTable() => TableNode.pooled();

  @override
  TableRowNode checkoutTableRow() => TableRowNode.pooled();

  @override
  TableCellNode checkoutTableCell() => TableCellNode.pooled();

  @override
  Map<K, V> checkoutDataMap<K, V>() => <K, V>{};

  @override
  List<T> checkoutDataList<T>() => <T>[];

  @override
  Set<T> checkoutDataSet<T>() => <T>{};

  @override
  HandlerContext checkoutContext() => HandlerContext.pooled();

  @override
  PhysicalDocument checkoutPhysicalDocument() => PhysicalDocument.pooled();

  @override
  PhysicalLine checkoutPhysicalLine() => PhysicalLine.pooled();

  @override
  void release(final Object obj) {}

  Future<void> waitForPoolCapacity() async {}
  void reclaimInFlightBuffers() {}

  int get poolSize => 0;
  @internal
  int get totalAllocatedBytes => 0;

  void clear() {}
  void disposeNative() {}
}

class ArenaDocument extends StandardDocument {
  ArenaDocument.pooled();
}
