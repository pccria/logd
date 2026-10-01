part of 'encoder.dart';

/// An encoder that serializes [LogDocument]s into structured JSON.
///
/// It prioritizes [MapNode] and [ListNode] for direct serialization.
/// If multiple nodes are present, they are joined with newlines.
class JsonEncoder implements LogEncoder {
  /// Creates a [JsonEncoder].
  ///
  /// - [indent]: Indentation for pretty printing. If null, compact JSON is
  /// used.
  const JsonEncoder({this.indent});

  @override
  WrappingStrategy get wrappingStrategy => WrappingStrategy.none;

  /// Optional indentation for pretty printing.
  final String? indent;

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
  }) {
    final nodes = document.nodes;
    if (nodes.isEmpty) {
      return;
    }

    final encoder = indent != null
        ? convert.JsonEncoder.withIndent(indent)
        : const convert.JsonCodec().encoder;

    // Optimization: If there's exactly one MapNode or ListNode, serialize its
    // raw data.
    if (nodes.length == 1) {
      final node = nodes.first;
      if (node is MapNode) {
        context.writeString(encoder.convert(node.map));
        return;
      }
      if (node is ListNode) {
        context.writeString(encoder.convert(node.list));
        return;
      }
    }

    final list = nodes.map(_serializeNode).toList();

    context.writeString(
      encoder.convert(
        list.length == 1 ? list.first : list,
      ),
    );
  }

  Object? _serializeNode(final LogNode node) => switch (node) {
        final MessageNode n => {
            'type': 'message',
            'text': n.segments.map((final s) => s.text).join(),
            if (n.tags != LogTag.none) 'tags': n.tags,
          },
        final ErrorNode n => {
            'type': 'error',
            'text': n.segments.map((final s) => s.text).join(),
            if (n.tags != LogTag.none) 'tags': n.tags,
          },
        final FooterNode n => {
            'type': 'footer',
            'text': n.segments.map((final s) => s.text).join(),
            if (n.tags != LogTag.none) 'tags': n.tags,
          },
        final HeaderNode n => {
            'type': 'header',
            'text': n.segments.map((final s) => s.text).join(),
            if (n.tags != LogTag.none) 'tags': n.tags,
          },
        final MapNode n => n.map,
        final ListNode n => n.list,
        final BoxNode n => {
            'type': 'box',
            'border': n.border.name,
            if (n.title != null) 'title': n.title!.text,
            'children': n.children.map(_serializeNode).toList(),
          },
        final IndentationNode n => {
            'type': 'indent',
            'value': n.indentString,
            'children': n.children.map(_serializeNode).toList(),
          },
        final AlignmentNode n => {
            'type': 'alignment',
            'value': n.alignment.name,
            'children': n.children.map(_serializeNode).toList(),
          },
        final TableNode n => {
            'type': 'table',
            if (n.columnWidths.isNotEmpty) 'columnWidths': n.columnWidths,
            'rows': n.children.map(_serializeNode).toList(),
          },
        final TableRowNode n => n.children.map(_serializeNode).toList(),
        final TableCellNode n => {
            'type': 'cell',
            if (n.colSpan > 1) 'colSpan': n.colSpan,
            if (n.rowSpan > 1) 'rowSpan': n.rowSpan,
            'children': n.children.map(_serializeNode).toList(),
          },
        final LayoutNode n => {
            'type':
                n.runtimeType.toString().toLowerCase().replaceAll('node', ''),
            'children': n.children.map(_serializeNode).toList(),
          },
        final FillerNode n => {
            'type': 'filler',
            'char': n.char,
            'count': n.count,
          },
        _ => node.toString(),
      };
}
