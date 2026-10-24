import 'dart:convert' as convert;

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

/// An encoder that transforms [LogDocument] into Markdown (GFM) markup.
///
/// It translates the semantic structure of the log into Markdown elements:
/// - [HeaderNode]: Headers (###) + Emojis based on [LogLevel].
/// - [MessageNode]: Bold text (**message**)
/// - [ErrorNode]: Alert blocks (`> [!ERROR]`)
/// - [LogTag.collapsible]: `<details>` blocks for collapsible content.
/// - [LogTag.stackFrame]: Code blocks (```).
@immutable
class MarkdownEncoder implements LogEncoder {
  /// Creates a [MarkdownEncoder].
  const MarkdownEncoder();

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
    // 1. Header Extraction Pass: Find all text intended for headers.
    final headers = <String>[];
    for (final node in document.nodes) {
      _extractHeaders(node, headers);
    }

    // 2. Render Single Header with Emoji
    if (headers.isNotEmpty) {
      final emoji = _levelEmoji(entry.level);
      final joined = headers.join(' • ');
      context.writeString('### $emoji $joined\n\n');
    }

    // 3. Render Body Pass: Render all nodes, but specialized skipping.
    for (final node in document.nodes) {
      _renderNode(context, node, document, entry, isBodyPass: true);
    }

    // 4. Thematic Separator
    context.writeString('\n---\n\n');
  }

  /// Recursively collects text segments that should belong in the GFM header.
  void _extractHeaders(final LogNode node, final List<String> target) {
    final text = _getHeaderText(node);
    if (text != null && text.isNotEmpty) {
      target.add(text);
    }
  }

  /// Returns semantic text if the node is header-like, otherwise null.
  String? _getHeaderText(final LogNode node) {
    if (node is HeaderNode) {
      final text = _renderContent(node).trim();
      return _isPureFiller(text) ? null : text;
    }

    if (node is DecoratedNode) {
      final parts = <String>[];
      if (node.leading != null) {
        final text = node.leading!.map((final s) => s.text).join().trim();
        if (text.isNotEmpty && !_isPureFiller(text)) {
          parts.add(text);
        }
      }
      for (final child in node.children) {
        final part = _getHeaderText(child);
        if (part != null && part.isNotEmpty) {
          parts.add(part);
        }
      }
      return parts.isEmpty ? null : parts.join(' ');
    }

    if (node is RowNode || node is GroupNode) {
      final parts = <String>[];
      final children = (node as LayoutNode).children;
      for (final child in children) {
        final part = _getHeaderText(child);
        if (part != null && part.isNotEmpty) {
          parts.add(part);
        }
      }
      return parts.isEmpty ? null : parts.join(' ');
    }

    return null;
  }

  bool _isPureFiller(final String text) {
    // Filter out typical terminal-only filler patterns.
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return true;
    }
    if (trimmed.split('').every(
          (final char) =>
              char == '_' || char == '-' || char == ' ' || char == '|',
        )) {
      return true;
    }
    return false;
  }

  void _renderNode(
    final HandlerContext context,
    final LogNode node,
    final LogDocument document,
    final LogEntry entry, {
    final bool isBodyPass = false,
  }) {
    if ((node.tags & LogTag.collapsible) != 0) {
      _renderCollapsible(context, node, document, entry);
      return;
    }

    switch (node) {
      case HeaderNode():
        // In body pass, we suppress nodes that were completely moved to the header.
        if (!isBodyPass) {
          context.writeString('### ${_renderContent(node).trim()}\n');
        }
      case MessageNode():
        context.writeString('**${_renderContent(node).trim()}**\n');
      case ErrorNode():
        context
          ..writeString('\n> [!ERROR]\n')
          ..writeString('> ${_renderContent(node)}\n');
      case FooterNode():
        _renderFooter(context, node);
      case MetadataNode():
        context.writeString('> [!NOTE]\n> ${_renderContent(node).trim()}\n');
      case IndentationNode():
        context.writeString('> ');
        for (final child in node.children) {
          _renderNode(context, child, document, entry, isBodyPass: isBodyPass);
        }
      case DecoratedNode():
        // If the leading decoration was likely consumed by the header, we skip it
        // in the body to avoid duplication.
        final leadingText = (node.leading != null)
            ? node.leading!.map((final s) => s.text).join().trim()
            : '';

        final skipLeading = isBodyPass &&
            leadingText.isNotEmpty &&
            (_getHeaderText(node) != null || _isPureFiller(leadingText));

        if (!skipLeading && node.leading != null) {
          context
              .writeString('${node.leading!.map((final s) => s.text).join()} ');
        }

        for (final child in node.children) {
          _renderNode(context, child, document, entry, isBodyPass: isBodyPass);
        }

        if (node.trailing != null) {
          context.writeString(
              ' ${node.trailing!.map((final s) => s.text).join()}');
        }
      case BoxNode():
        context.writeString('\n> [!NOTE]\n');
        if (node.title != null) {
          context.writeString('> **${node.title!.text}**\n');
        }
        for (final child in node.children) {
          context.writeString('> ');
          _renderNode(context, child, document, entry, isBodyPass: isBodyPass);
        }
        context.writeString('\n');
      case SectionNode():
        context.writeString('\n<details>\n<summary>');
        _renderNode(context, node.summary, document, entry);
        context.writeString('</summary>\n\n');
        for (final child in node.children) {
          _renderNode(context, child, document, entry, isBodyPass: isBodyPass);
        }
        context.writeString('\n</details>\n');
      case ParagraphNode():
        for (final child in node.children) {
          _renderNode(context, child, document, entry, isBodyPass: isBodyPass);
        }
        context.writeString('\n');
      case GroupNode():
        for (final child in node.children) {
          _renderNode(context, child, document, entry, isBodyPass: isBodyPass);
        }
      case RowNode():
        for (final child in node.children) {
          _renderNode(context, child, document, entry, isBodyPass: isBodyPass);
        }
      case AlignmentNode():
        for (final child in node.children) {
          _renderNode(context, child, document, entry, isBodyPass: isBodyPass);
        }
      case TableNode():
        _renderTable(context, node, document, entry);
      case TableRowNode():
        for (final child in node.children) {
          _renderNode(context, child, document, entry, isBodyPass: isBodyPass);
        }
      case TableCellNode():
        for (final child in node.children) {
          _renderNode(context, child, document, entry, isBodyPass: isBodyPass);
        }
      case MapNode():
        final toonColumns = document.metadata['toon_columns'] as List<String>?;
        if (toonColumns != null) {
          final delimiter =
              document.metadata['toon_delimiter'] as String? ?? '\t';
          final row = toonColumns
              .map((final col) => node.map[col]?.toString() ?? '')
              .join(delimiter);

          _writeFencedBlock(context, row, 'text');
        } else {
          _writeFencedBlock(context, node.toString(), 'json');
        }
      case ListNode():
        _renderList(context, node);
      case FillerNode():
        // Typically ignored in MD except within headers.
        break;
    }
  }

  void _renderList(final HandlerContext context, final ListNode node) {
    if (node.list.isEmpty) {
      return;
    }
    context.writeString('\n');
    for (final item in node.list) {
      context.writeString('- $item\n');
    }
    context.writeString('\n');
  }

  void _renderTable(
    final HandlerContext context,
    final TableNode node,
    final LogDocument document,
    final LogEntry entry,
  ) {
    if (node.children.isEmpty) {
      return;
    }

    if (node.title != null) {
      context.writeString('**${node.title!.text}**\n');
    }

    final rows = <List<String>>[];
    for (final child in node.children) {
      if (child is TableRowNode) {
        final rowCells = <String>[];
        for (final cell in child.children) {
          final cellCtx = HandlerContext();
          if (cell is TableCellNode) {
            for (final cellChild in cell.children) {
              _renderNode(cellCtx, cellChild, document, entry);
            }
          } else {
            _renderNode(cellCtx, cell, document, entry);
          }
          final text = convert.utf8
              .decode(cellCtx.takeBytes(), allowMalformed: true)
              .trim()
              .replaceAll('\n', ' ')
              .replaceAll('|', r'\|');
          rowCells.add(text.isEmpty ? ' ' : text);
        }
        rows.add(rowCells);
      }
    }

    if (rows.isEmpty) {
      return;
    }

    int colCount = 0;
    for (final r in rows) {
      if (r.length > colCount) {
        colCount = r.length;
      }
    }
    if (colCount == 0) {
      return;
    }

    context.writeString('\n');
    final firstRow = rows.first;
    final headerPadded = List<String>.generate(
      colCount,
      (final i) => i < firstRow.length ? firstRow[i] : ' ',
    );
    context.writeString('| ${headerPadded.join(' | ')} |\n');
    context.writeString('| ${List.filled(colCount, '---').join(' | ')} |\n');

    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      final rowPadded = List<String>.generate(
        colCount,
        (final j) => j < r.length ? r[j] : ' ',
      );
      context.writeString('| ${rowPadded.join(' | ')} |\n');
    }
    context.writeString('\n');
  }

  void _renderCollapsible(
    final HandlerContext context,
    final LogNode node,
    final LogDocument document,
    final LogEntry entry,
  ) {
    final summary =
        (node.tags & LogTag.stackFrame) != 0 ? 'Stack Trace' : 'Details';
    context
      ..writeString('\n<details>\n')
      ..writeString('<summary>$summary</summary>\n\n');

    if (node is ContentNode) {
      if ((node.tags & LogTag.stackFrame) != 0) {
        _writeFencedBlock(context, _renderContent(node));
      } else {
        context.writeString('${_renderContent(node)}\n');
      }
    } else if (node is LayoutNode) {
      for (final child in node.children) {
        _renderNode(context, child, document, entry);
      }
    }

    context.writeString('\n</details>\n');
  }

  void _renderFooter(final HandlerContext context, final FooterNode node) {
    if ((node.tags & LogTag.stackFrame) != 0) {
      _writeFencedBlock(context, _renderContent(node));
    } else {
      context.writeString('${_renderContent(node)}\n');
    }
  }

  void _writeFencedBlock(
    final HandlerContext context,
    final String content, [
    final String lang = '',
  ]) {
    var fence = '```';
    while (content.contains(fence)) {
      fence += '`';
    }
    context
      ..writeString('\n$fence$lang\n')
      ..writeString(content)
      ..writeString('\n$fence\n');
  }

  String _renderContent(final ContentNode node) =>
      node.segments.map((final s) => s.text).join();

  String _levelEmoji(final LogLevel level) => switch (level) {
        LogLevel.trace => '🧬',
        LogLevel.debug => '🔍',
        LogLevel.info => 'ℹ️',
        LogLevel.warning => '⚠️',
        LogLevel.error => '❌',
      };
}
