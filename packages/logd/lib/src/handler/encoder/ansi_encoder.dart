part of 'encoder.dart';

/// An encoder that produces colorized ANSI output for terminals.
///
/// This encoder uses [TerminalLayout] to calculate the physical geometry of the
/// log and applies [LogStyle]s present on the segments using ANSI escape
/// sequences.
class AnsiEncoder implements LogEncoder {
  /// Creates an [AnsiEncoder].
  const AnsiEncoder();

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

    LogStyle? activeStyle;

    void applyStyle(final String text, final LogStyle style) {
      if (text.isEmpty) {
        return;
      }
      if (activeStyle == style) {
        context.writeString(text);
        return;
      }
      if (activeStyle != null) {
        context.addToken(RenderTokens.ansiReset);
        activeStyle = null;
      }
      final codes = <int>[];
      if (style.bold == true) {
        codes.add(1);
      }
      if (style.dim == true) {
        codes.add(2);
      }
      if (style.italic == true) {
        codes.add(3);
      }
      if (style.inverse == true) {
        codes.add(7);
      }
      if (style.underline == true) {
        codes.add(4);
      }
      if (style.color != null) {
        codes.add(_getColorCode(style.color!, background: false));
      }
      if (style.backgroundColor != null) {
        codes.add(_getColorCode(style.backgroundColor!, background: true));
      }
      if (codes.isEmpty) {
        context.writeString(text);
      } else {
        context
          ..addByte(0x1B) // ESC
          ..addByte(0x5B) // '['
          ..writeString(codes.join(';'))
          ..addByte(0x6D) // 'm'
          ..writeString(text);
        activeStyle = style;
      }
    }

    void resetStyle() {
      if (activeStyle != null) {
        context.addToken(RenderTokens.ansiReset);
        activeStyle = null;
      }
    }

    // 2. Encode with styles
    for (int i = 0; i < physicalDoc.lines.length; i++) {
      final line = physicalDoc.lines[i];
      for (final segment in line.segments) {
        final style = segment.style;
        if (style != null) {
          applyStyle(segment.text, style);
        } else {
          context.writeString(segment.text);
        }
      }
      resetStyle();
      if (i < physicalDoc.lines.length - 1) {
        context.addByte(0x0A); // '\n'
      }
    }
    resetStyle();

    physicalDoc.releaseRecursive(factory);
  }

  int _getColorCode(final LogColor color, {required final bool background}) {
    final base = background ? 40 : 30;
    return switch (color) {
      LogColor.black => base + 0,
      LogColor.red => base + 1,
      LogColor.green => base + 2,
      LogColor.yellow => base + 3,
      LogColor.blue => base + 4,
      LogColor.magenta => base + 5,
      LogColor.cyan => base + 6,
      LogColor.white => base + 7,
      LogColor.brightBlack => base + 60,
      LogColor.brightRed => base + 61,
      LogColor.brightGreen => base + 62,
      LogColor.brightYellow => base + 63,
      LogColor.brightBlue => base + 64,
      LogColor.brightMagenta => base + 65,
      LogColor.brightCyan => base + 66,
      LogColor.brightWhite => base + 67,
    };
  }
}
