import 'package:logd/logd.dart';
import 'package:logd/src/handler/handler.dart';

/// Helper to create a simplified LogDocument from strings.
LogDocument createTestDocument(
  final List<String> lines, {
  final LogPipelineFactory? factory,
  final int tags = 0,
}) {
  final f = factory ?? Arena.instance;
  final doc = f.checkoutDocument();
  for (final line in lines) {
    doc.nodes.add(
      f.checkoutMessage()..segments.add(StyledText(line, tags: tags)),
    );
  }
  return doc;
}


/// Helper for testing formatters: checks out a doc, formats it, and returns it.
/// REMEMBER: The caller must release the document.
LogDocument formatDoc(
  final LogFormatter formatter,
  final LogEntry entry, {
  final LogPipelineFactory? factory,
}) {
  final f = factory ?? Arena.instance;
  final doc = f.checkoutDocument();
  formatter.format(entry, doc, f);
  return doc;
}

/// Helper for testing decorators: applies the decorator in-place.
void decorateDoc(
  final LogDecorator decorator,
  final LogDocument document,
  final LogEntry entry, {
  final LogPipelineFactory? factory,
}) {
  decorator.decorate(document, entry, factory ?? Arena.instance);
}

/// Renders a LogDocument to a list of strings with ANSI codes.
///
/// Simulates a terminal rendering.
List<String> renderLines(
  final LogDocument document, {
  final int width = 80,
  final LogPipelineFactory factory = const StandardPipelineFactory(),
}) {
  // Use TerminalLayout to flatten logic to physical lines
  final layout = TerminalLayout(width: width, factory: factory);
  final physical = layout.layout(document, LogLevel.info);

  final result = <String>[];
  for (final line in physical.lines) {
    final buffer = StringBuffer();
    for (final segment in line.segments) {
      final style = segment.style;
      if (style != null) {
        if (style.bold == true) {
          buffer.write('\x1B[1m');
        }
        if (style.dim == true) {
          buffer.write('\x1B[2m');
        }
        if (style.italic == true) {
          buffer.write('\x1B[3m');
        }
        if (style.inverse == true) {
          buffer.write('\x1B[7m');
        }
        if (style.color != null) {
          buffer.write(_getAnsiColor(style.color!));
        }

        buffer
          ..write(segment.text)
          ..write('\x1B[0m'); // Reset
      } else {
        buffer.write(segment.text);
      }
    }
    result.add(buffer.toString());
  }
  return result;
}

String _getAnsiColor(final LogColor color) => switch (color) {
      LogColor.black => '\x1B[30m',
      LogColor.red => '\x1B[31m',
      LogColor.green => '\x1B[32m',
      LogColor.yellow => '\x1B[33m',
      LogColor.blue => '\x1B[34m',
      LogColor.magenta => '\x1B[35m',
      LogColor.cyan => '\x1B[36m',
      LogColor.white => '\x1B[37m',
      LogColor.brightBlack => '\x1B[90m',
      LogColor.brightRed => '\x1B[91m',
      LogColor.brightGreen => '\x1B[92m',
      LogColor.brightYellow => '\x1B[93m',
      LogColor.brightBlue => '\x1B[94m',
      LogColor.brightMagenta => '\x1B[95m',
      LogColor.brightCyan => '\x1B[96m',
      LogColor.brightWhite => '\x1B[97m',
    };
