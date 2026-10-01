part of 'encoder.dart';

/// A simple encoder that joins lines with newlines, ignoring styles.
///
/// This is the default encoder for file sinks where usually raw text is
/// preferred over ANSI codes.
class PlainTextEncoder implements LogEncoder {
  /// Creates a [PlainTextEncoder].
  const PlainTextEncoder();

  @override
  WrappingStrategy get wrappingStrategy => WrappingStrategy.none;

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
    if (document.nodes.isEmpty) {
      return;
    }

    // 1. Calculate physical layout
    final totalWidth = width ?? 80;
    final layoutEngine = TerminalLayout(width: totalWidth, factory: factory);
    final physicalDoc = layoutEngine.layout(document, level);

    // 2. Encode
    for (int i = 0; i < physicalDoc.lines.length; i++) {
      context.writeString(physicalDoc.lines[i].toString());
      if (i < physicalDoc.lines.length - 1) {
        context.addToken(RenderTokens.newline);
      }
    }

    physicalDoc.releaseRecursive(factory);
  }
}
