part of 'layout.dart';

/// An internal engine for calculating physical terminal geometry.
///
/// [TerminalLayout] flattens the logical [LogDocument] tree into a sequence
/// of physical lines based on a target width. It handles structural elements
/// like boxes, indentation, and decorations, as well as content elements
/// like word-wrapped text using adaptive, width-agnostic logic.
@internal
class TerminalLayout {
  /// Creates a [TerminalLayout].
  const TerminalLayout({
    required this.width,
    required this.factory,
  });

  /// The target physical width in characters.
  final int width;

  /// The factory used to checkout physical layout objects.
  final LogPipelineFactory factory;

  /// Lays out a [LogDocument] into a [PhysicalDocument].
  PhysicalDocument layout(final LogDocument document, final LogLevel level) {
    final physicalDoc = factory.checkoutPhysicalDocument();
    if (document.nodes.isEmpty) {
      return physicalDoc;
    }

    for (final node in document.nodes) {
      _renderNode(node, document, level, width, physicalDoc.lines);
    }

    return physicalDoc;
  }

  void _renderNode(
    final LogNode node,
    final LogDocument document,
    final LogLevel level,
    final int availableWidth,
    final List<PhysicalLine> out,
  ) {
    switch (node) {
      case final ContentNode n:
        _renderContent(n, availableWidth, out);
      case final BoxNode n:
        _renderBox(n, document, level, availableWidth, out);
      case final IndentationNode n:
        _renderIndentation(n, document, level, availableWidth, out);
      case final DecoratedNode n:
        _renderDecorated(n, document, level, availableWidth, out);
      case final GroupNode n:
        for (final child in n.children) {
          _renderNode(child, document, level, availableWidth, out);
        }
      case final ParagraphNode n:
        _renderParagraph(n, document, level, availableWidth, out);
      case final FillerNode n:
        _renderFiller(n, availableWidth, out);
      case final RowNode n:
        _renderRow(n, document, level, availableWidth, out);
      case final MapNode n:
        final temp = factory.checkoutHeader()
          ..segments.add(StyledText(n.toString()));
        _renderContent(temp, availableWidth, out);
        temp.releaseRecursive(factory);
      case final ListNode n:
        final temp = factory.checkoutHeader()
          ..segments.add(StyledText(n.toString()));
        _renderContent(temp, availableWidth, out);
        temp.releaseRecursive(factory);
      case final SectionNode n:
        _renderNode(n.summary, document, level, availableWidth, out);
        for (final child in n.children) {
          _renderNode(child, document, level, availableWidth, out);
        }
      case final AlignmentNode n:
        _renderAlignment(n, document, level, availableWidth, out);
      case final TableNode n:
        _renderTable(n, document, level, availableWidth, out);
      case final TableRowNode n:
        for (final child in n.children) {
          _renderNode(child, document, level, availableWidth, out);
        }
      case final TableCellNode n:
        for (final child in n.children) {
          _renderNode(child, document, level, availableWidth, out);
        }
    }
  }

  void _renderRow(
    final RowNode node,
    final LogDocument document,
    final LogLevel level,
    final int availableWidth,
    final List<PhysicalLine> out,
  ) {
    if (availableWidth <= 0) {
      return;
    }

    // For a row, we want everything on one line if possible.
    // If it exceeds width, we fall back to paragraph-style wrapping
    //(Adaptive Stacking).
    final segments = <StyledText>[];
    String? fillerChar;
    int fillerTags = LogTag.none;
    LogStyle? fillerStyle;

    for (final child in node.children) {
      if (child is ContentNode) {
        segments.addAll(child.segments);
      } else if (child is FillerNode) {
        fillerChar = child.char;
        fillerTags = child.tags;
        fillerStyle = child.style;
      }
    }

    // Render as flow first
    final startIndex = out.length;
    final temp = factory.checkoutHeader()..segments.addAll(segments);
    _renderContent(temp, availableWidth, out);
    temp.releaseRecursive(factory);

    if (fillerChar != null) {
      // Add filler to each line to ensure it reaches full width
      for (int i = startIndex; i < out.length; i++) {
        final line = out[i];
        final currentLen = line.visibleLength;
        final fillerLen =
            (availableWidth - currentLen).clamp(0, availableWidth);
        if (fillerLen > 0) {
          line.segments.add(
            StyledText(
              fillerChar * fillerLen,
              tags: fillerTags,
              style: fillerStyle,
            ),
          );
        }
      }
    }
  }

  void _renderParagraph(
    final ParagraphNode node,
    final LogDocument document,
    final LogLevel level,
    final int availableWidth,
    final List<PhysicalLine> out,
  ) {
    // For now, treat ParagraphNode children as a single flow.
    // We flatten all content children into one virtual ContentNode and render
    // it.
    final allSegments = <StyledText>[];
    for (final child in node.children) {
      if (child is ContentNode) {
        allSegments.addAll(child.segments);
      } else {
        // Nested layout nodes in paragraphs are not yet supported for inline
        // flow. We render them as separate lines.
      }
    }

    final temp = factory.checkoutHeader()..segments.addAll(allSegments);
    _renderContent(temp, availableWidth, out);
    temp.releaseRecursive(factory);
  }

  void _renderFiller(
    final FillerNode node,
    final int availableWidth,
    final List<PhysicalLine> out,
  ) {
    if (availableWidth <= 0) {
      return;
    }
    final line = factory.checkoutPhysicalLine();
    line.segments.add(
      StyledText(
        node.char * availableWidth,
        tags: node.tags,
        style: node.style,
      ),
    );
    out.add(line);
  }

  void _renderContent(
    final ContentNode node,
    final int availableWidth,
    final List<PhysicalLine> out,
  ) {
    // Fast Path: Single segment, simple ASCII message that fits width.
    if (node.segments.length == 1) {
      final segment = node.segments.first;
      final text = segment.text;
      if (text.length <= availableWidth &&
          (segment.tags & LogTag.noWrap) == 0) {
        bool isSimple = true;
        for (var i = 0; i < text.length; i++) {
          final code = text.codeUnitAt(i);
          if (code < 0x20 || code > 0x7E) {
            isSimple = false;
            break;
          }
        }
        if (isSimple) {
          final line = factory.checkoutPhysicalLine();
          line.segments.add(segment);
          out.add(line);
          return;
        }
      }
    }

    var currentLine = factory.checkoutPhysicalLine();
    var currentLength = 0;

    void commitLine() {
      if (currentLine.segments.isNotEmpty) {
        out.add(currentLine);
        currentLine = factory.checkoutPhysicalLine();
        currentLength = 0;
      }
    }

    for (final segment in node.segments) {
      if ((segment.tags & LogTag.preview) != 0) {
        continue;
      }
      final resolvedText = resolveFileUris(segment.text);
      // If segment is tagged noWrap, we bypass width constraints.
      if ((segment.tags & LogTag.noWrap) != 0) {
        // Just append the whole text. If there are newlines, respect them.
        final physicalLines = resolvedText.split('\n');
        for (var l = 0; l < physicalLines.length; l++) {
          if (l > 0) {
            commitLine();
          }
          final lineText = physicalLines[l];
          if (lineText.isEmpty) {
            continue;
          }

          currentLine.segments.add(
            StyledText(lineText, style: segment.style, tags: segment.tags),
          );
          currentLength += _getVisibleLength(lineText, currentLength);
        }
        continue;
      }

      final physicalLines = resolvedText.split('\n');

      for (var l = 0; l < physicalLines.length; l++) {
        if (l > 0) {
          // Explicit newline in segment
          commitLine();
        }

        final lineText = physicalLines[l];
        if (lineText.isEmpty) {
          continue;
        }

        final words = lineText.split(' ');

        for (var i = 0; i < words.length; i++) {
          final isLastWord = i == words.length - 1;
          var word = words[i];
          if (!isLastWord) {
            word = '$word ';
          }

          // If even the single word is too long, we must break it
          final wordLen = _getVisibleLength(word, currentLength);
          if (wordLen > availableWidth) {
            // Finish current line if not empty
            commitLine();

            // Break the word into chunks
            var remaining = word;
            while (remaining.isNotEmpty &&
                _getVisibleLength(remaining) > availableWidth) {
              // Find how many characters fit
              var fitLen = 0;
              var takeCount = 0;
              for (final char in remaining.characters) {
                final clen =
                    (char == '\t') ? 8 - (fitLen % 8) : (isWide(char) ? 2 : 1);
                if (fitLen + clen > availableWidth && takeCount > 0) {
                  break;
                }
                fitLen += clen;
                takeCount += char.length;
              }

              final chunk = remaining.substring(0, takeCount);
              final chunkLine = factory.checkoutPhysicalLine();
              chunkLine.segments.add(
                StyledText(chunk, style: segment.style, tags: segment.tags),
              );
              out.add(chunkLine);
              remaining = remaining.substring(takeCount);
            }
            if (remaining.isNotEmpty) {
              currentLine.segments.add(
                StyledText(
                  remaining,
                  style: segment.style,
                  tags: segment.tags,
                ),
              );
              currentLength = _getVisibleLength(remaining);
            }
            continue;
          }

          final wordLenTrimmed = _getVisibleLength(
            word.replaceFirst(RegExp(r' +$'), ''),
            currentLength,
          );
          if (currentLength + wordLenTrimmed > availableWidth &&
              currentLength > 0) {
            commitLine();
          }

          currentLine.segments
              .add(StyledText(word, style: segment.style, tags: segment.tags));
          currentLength += _getVisibleLength(word, currentLength);
        }
      }
    }

    if (currentLine.segments.isNotEmpty) {
      out.add(currentLine);
    } else {
      factory.release(currentLine);
    }

    // Post-process to trim trailing spaces from each physical line
    // to match legacy wrapVisible behavior.
    for (final line in out) {
      if (line.segments.isEmpty) {
        continue;
      }
      final last = line.segments.last;
      final trimmedText = last.text.replaceFirst(RegExp(r' +$'), '');
      if (trimmedText != last.text) {
        line.segments[line.segments.length - 1] =
            StyledText(trimmedText, style: last.style, tags: last.tags);
      }
    }
  }

  void _renderBox(
    final BoxNode node,
    final LogDocument document,
    final LogLevel level,
    final int availableWidth,
    final List<PhysicalLine> out,
  ) {
    final border = node.border;

    // Top Border
    if (border != BoxBorderStyle.none) {
      out.add(
        _renderBorderLine(
          border,
          BoxBorderPosition.top,
          availableWidth,
          node.style,
        ),
      );
    }

    // Title (if any)
    if (node.title != null) {
      final titleBar = border.getChar(BoxBorderPosition.vertical);
      final titleLen = _getVisibleLength(node.title!.text);
      final padding = availableWidth - titleLen - 4;
      final padLeft = padding ~/ 2;
      final padRight = padding - padLeft;

      final titleLine = factory.checkoutPhysicalLine();
      titleLine.segments.addAll([
        StyledText(
          titleBar,
          style: node.style,
          tags: LogTag.border,
        ),
        StyledText(
          '  ${' ' * padLeft}${node.title!.text}${' ' * padRight}  ',
          tags: LogTag.header,
        ),
        StyledText(
          titleBar,
          style: node.style,
          tags: LogTag.border,
        ),
      ]);
      out.add(titleLine);

      if (border != BoxBorderStyle.none) {
        out.add(
          _renderBorderLine(
            border,
            BoxBorderPosition.middle,
            availableWidth,
            node.style,
          ),
        );
      }
    }

    // Content
    final contentWidth = max(0, availableWidth - 4);
    final contentLines = <PhysicalLine>[];
    for (final child in node.children) {
      _renderNode(child, document, level, contentWidth, contentLines);
    }

    for (final rawLine in contentLines) {
      // Truncate assuming line starts at index 2 (border + space)
      final line = rawLine.truncate(factory, contentWidth, startX: 2);
      final sideChar = border.getChar(BoxBorderPosition.vertical);

      // Calculate visible length assuming line starts at index 2
      // (border + space)
      // This is crucial for correct TAB expansion inside boxes.
      final visibleLen = line.getVisibleLength(startX: 2);

      final paddingNeeded = contentWidth - visibleLen;
      final padding = ' ' * (paddingNeeded > 0 ? paddingNeeded : 0);

      final boxLine = factory.checkoutPhysicalLine();
      boxLine.segments.addAll([
        StyledText(
          sideChar,
          style: node.style,
          tags: LogTag.border,
        ),
        StyledText(' ', style: node.style, tags: LogTag.none),
        ..._expandTabs(line.segments, 2),
        StyledText('$padding ', style: node.style, tags: LogTag.none),
        StyledText(
          sideChar,
          style: node.style,
          tags: LogTag.border,
        ),
      ]);
      out.add(boxLine);

      // If truncate returned a new line, we need to release the rawLine.
      // But truncate current implementation returns 'this' if no truncation
      // needed, or a NEW PhysicalLine.
      // Wait, PhysicalLine.truncate currently returns a NEW PhysicalLine.
      // I should update PhysicalLine.truncate to also use the arena!
      if (!identical(line, rawLine)) {
        rawLine.releaseRecursive(factory);
      }
    }
    // We don't need contentLines anymore as they are now either in 'out'
    // or were released. But wait, rawLine is NOT released if truncation
    // happened.
    // Actually, contentLines just contains references.
    // The loop above releases rawLine if a new 'line' was created.
    // If NO new line was created, rawLine is now effectively part of 'out'?
    // NO, because we checkoutPhysicalLine() for boxLine and COPY segments.
    // So rawLine is ALWAYS redundant after the loop.
    for (final rawLine in contentLines) {
      rawLine.releaseRecursive(factory);
    }

    // Bottom Border
    if (border != BoxBorderStyle.none) {
      out.add(
        _renderBorderLine(
          border,
          BoxBorderPosition.bottom,
          availableWidth,
          node.style,
        ),
      );
    }
  }

  List<StyledText> _expandTabs(
    final List<StyledText> segments,
    final int startX,
  ) {
    bool hasTab = false;
    for (final seg in segments) {
      if (seg.text.contains('\t')) {
        hasTab = true;
        break;
      }
    }
    if (!hasTab) {
      return segments;
    }

    final result = <StyledText>[];
    var currentPos = startX;
    for (final seg in segments) {
      if (!seg.text.contains('\t')) {
        result.add(seg);
        currentPos += _getVisibleLength(seg.text, currentPos);
        continue;
      }
      final buf = StringBuffer();
      for (final char in seg.text.characters) {
        if (char == '\t') {
          final advance = 8 - (currentPos % 8);
          buf.write(' ' * advance);
          currentPos += advance;
        } else {
          buf.write(char);
          final advance = isWide(char) ? 2 : 1;
          currentPos += advance;
        }
      }
      result.add(StyledText(buf.toString(), style: seg.style, tags: seg.tags));
    }
    return result;
  }

  PhysicalLine _renderBorderLine(
    final BoxBorderStyle border,
    final BoxBorderPosition pos,
    final int width,
    final LogStyle? style,
  ) {
    final left = border.getCorner(pos, BoxBorderCorner.left);
    final right = border.getCorner(pos, BoxBorderCorner.right);
    final horizontal = border.getChar(BoxBorderPosition.horizontal);

    final line = factory.checkoutPhysicalLine();
    line.segments.add(
      StyledText(
        '$left${horizontal * (width - 2)}$right',
        style: style,
        tags: LogTag.border,
      ),
    );
    return line;
  }

  void _renderIndentation(
    final IndentationNode node,
    final LogDocument document,
    final LogLevel level,
    final int availableWidth,
    final List<PhysicalLine> out,
  ) {
    final indentWidth = _getVisibleLength(node.indentString);

    for (final child in node.children) {
      final childContentWidth =
          (availableWidth - indentWidth).clamp(0, 1000000);
      final rawLines = <PhysicalLine>[];
      _renderNode(child, document, level, childContentWidth, rawLines);
      for (final rawLine in rawLines) {
        if (childContentWidth <= 0) {
          // Narrow space recovery: Drop indent if it would push content
          // off-screen
          out.add(rawLine);
        } else {
          final line = rawLine.truncate(factory, childContentWidth);
          final indentLine = factory.checkoutPhysicalLine();
          indentLine.segments.add(
            StyledText(
              node.indentString,
              style: node.style,
              tags: LogTag.hierarchy,
            ),
          );
          indentLine.segments.addAll(line.segments);
          out.add(indentLine);

          if (!identical(line, rawLine)) {
            line.releaseRecursive(factory);
          }
          rawLine.releaseRecursive(factory);
        }
      }
    }
  }

  void _renderDecorated(
    final DecoratedNode node,
    final LogDocument document,
    final LogLevel level,
    final int availableWidth,
    final List<PhysicalLine> out,
  ) {
    final contentWidth =
        max(0, availableWidth - node.leadingWidth - node.trailingWidth);

    // Fallback: If decoration consumes too much space, switch to vertical
    // stack. This is crucial for PlainFormatter's hanging indents in
    // narrow/deep layouts. We only do this if repeatLeading is false
    // (typical for headers), because repeating prefixes meant for every line
    // generally shouldn't be stack-broken.
    // We use a threshold of 12 to ensure content has enough space to
    // be readable.
    if (contentWidth < 12 && !node.repeatLeading && node.leading != null) {
      // 1. Render Leading (Header) with full width
      _renderContent(HeaderNode(segments: node.leading!), availableWidth, out);
      // 2. Render Children (Message) with full width
      for (final child in node.children) {
        _renderNode(child, document, level, availableWidth, out);
      }
      return;
    }

    final childLines = <PhysicalLine>[];
    for (final child in node.children) {
      _renderNode(child, document, level, contentWidth, childLines);
    }

    if (childLines.isEmpty) {
      childLines.add(factory.checkoutPhysicalLine());
    }

    for (var i = 0; i < childLines.length; i++) {
      final rawLine = childLines[i];
      final line =
          rawLine.truncate(factory, contentWidth, startX: node.leadingWidth);
      final isFirst = i == 0;

      final leadingSegments =
          (node.leading != null && (isFirst || node.repeatLeading))
              ? node.leading!
              : (node.leadingWidth > 0
                  ? [
                      StyledText(
                        _getDecorationString(
                          node.leadingHint,
                          node.leadingWidth,
                          isContinuation: !isFirst,
                        ),
                        style: node.style,
                        tags: LogTag.hierarchy,
                      ),
                    ]
                  : const <StyledText>[]);

      final trailingSegments =
          (node.trailing != null && (isFirst || node.repeatTrailing))
              ? node.trailing!
              : (node.trailingWidth > 0
                  ? [
                      StyledText(
                        _getDecorationString(
                          node.trailingHint,
                          node.trailingWidth,
                          isContinuation: !isFirst,
                        ),
                        style: node.style,
                        tags: LogTag.hierarchy,
                      ),
                    ]
                  : const <StyledText>[]);

      final paddingNeeded =
          contentWidth - line.getVisibleLength(startX: node.leadingWidth);
      final padChar =
          node.leadingHint == DecorationHint.structuredSeparator ? '_' : ' ';
      final padding = (node.alignTrailing && paddingNeeded > 0)
          ? (padChar * paddingNeeded)
          : '';

      final pLine = factory.checkoutPhysicalLine();
      pLine.segments.addAll(leadingSegments);
      pLine.segments.addAll(line.segments);
      if (padding.isNotEmpty) {
        pLine.segments.add(StyledText(padding, tags: LogTag.none));
      }
      pLine.segments.addAll(trailingSegments);
      out.add(pLine);

      if (!identical(line, rawLine)) {
        line.releaseRecursive(factory);
      }
      rawLine.releaseRecursive(factory);
    }
  }

  String _getDecorationString(
    final String? hint,
    final int width, {
    final bool isContinuation = false,
  }) {
    if (width <= 0) {
      return '';
    }
    if (hint == DecorationHint.structuredSeparator) {
      return '_' * width;
    }
    if (hint == DecorationHint.structuredHeader) {
      return '_' * width;
    }
    if (hint == DecorationHint.structuredMessage && isContinuation) {
      return ' ' * width;
    }
    if (hint == DecorationHint.hierarchyTrace) {
      return isContinuation ? '│${' ' * (width - 1)}' : '│${' ' * (width - 1)}';
    }
    return ' ' * width;
  }

  int _getVisibleLength(final String text, [final int startX = 0]) {
    var x = startX;
    for (final char in text.characters) {
      if (char == '\t') {
        x += 8 - (x % 8);
      } else {
        x += isWide(char) ? 2 : 1;
      }
    }
    return x - startX;
  }

  void _renderAlignment(
    final AlignmentNode node,
    final LogDocument document,
    final LogLevel level,
    final int availableWidth,
    final List<PhysicalLine> out,
  ) {
    final tempLines = <PhysicalLine>[];
    for (final child in node.children) {
      _renderNode(child, document, level, availableWidth, tempLines);
    }

    for (final line in tempLines) {
      final visibleLen = line.visibleLength;
      final padding = (availableWidth - visibleLen).clamp(0, availableWidth);

      final alignedLine = factory.checkoutPhysicalLine();
      switch (node.alignment) {
        case LogAlignment.left:
          alignedLine.segments.addAll(line.segments);
          break;
        case LogAlignment.center:
          final leftPad = padding ~/ 2;
          if (leftPad > 0) {
            alignedLine.segments.add(StyledText(' ' * leftPad));
          }
          alignedLine.segments.addAll(line.segments);
          break;
        case LogAlignment.right:
          if (padding > 0) {
            alignedLine.segments.add(StyledText(' ' * padding));
          }
          alignedLine.segments.addAll(line.segments);
          break;
        case LogAlignment.justify:
          // Justify is tricky in terminal, fall back to left for now
          alignedLine.segments.addAll(line.segments);
          break;
      }
      out.add(alignedLine);
      line.releaseRecursive(factory);
    }
  }

  void _renderTable(
    final TableNode node,
    final LogDocument document,
    final LogLevel level,
    final int availableWidth,
    final List<PhysicalLine> out,
  ) {
    if (availableWidth <= 0) {
      return;
    }

    // 1. Calculate column widths
    final columnWidths = _calculateColumnWidths(node, availableWidth);
    final totalCols = columnWidths.length;
    if (totalCols == 0) {
      return;
    }

    // 2. Render rows
    for (final row in node.children) {
      if (row is! TableRowNode) {
        continue;
      }

      // Each row is rendered by "zipping" its cells
      final cellLinesLists = <List<PhysicalLine>>[];
      int colIndex = 0;

      for (final cell in row.children) {
        if (cell is! TableCellNode) {
          continue;
        }

        // Calculate cell width based on colSpan
        int cellWidth = 0;
        final span = min(cell.colSpan, totalCols - colIndex);
        for (int i = 0; i < span; i++) {
          cellWidth += columnWidths[colIndex + i];
        }

        final rawLines = <PhysicalLine>[];
        _renderNode(cell, document, level, cellWidth, rawLines);

        // Truncate if needed and ensure we have fresh lines to modify
        final processedLines = rawLines.map((final l) {
          final t = l.truncate(factory, cellWidth);
          if (identical(t, l)) {
            // If truncate didn't create a new line, we should copy segments
            // because we will be modifying this line's length by padding it.
            // Actually, we create a NEW line in the zip phase, so we don't
            // need to copy here.
          }
          return t;
        }).toList();

        cellLinesLists.add(processedLines);

        // Important: release original rawLines if truncate created new ones
        for (int i = 0; i < rawLines.length; i++) {
          if (!identical(rawLines[i], processedLines[i])) {
            rawLines[i].releaseRecursive(factory);
          }
        }

        colIndex += span;
      }

      // 3. Zip lines together
      int maxLines = 0;
      for (final lines in cellLinesLists) {
        if (lines.length > maxLines) {
          maxLines = lines.length;
        }
      }

      for (int i = 0; i < maxLines; i++) {
        final rowLine = factory.checkoutPhysicalLine();
        int currentCellColIndex = 0;

        for (int c = 0; c < cellLinesLists.length; c++) {
          final lines = cellLinesLists[c];
          final cell = row.children[c] as TableCellNode;
          final span = min(cell.colSpan, totalCols - currentCellColIndex);

          int cellWidth = 0;
          for (int k = 0; k < span; k++) {
            cellWidth += columnWidths[currentCellColIndex + k];
          }

          if (i < lines.length) {
            final line = lines[i];
            rowLine.segments.addAll(line.segments);
            final len = line.visibleLength;
            if (len < cellWidth) {
              rowLine.segments.add(StyledText(' ' * (cellWidth - len)));
            }
          } else {
            rowLine.segments.add(StyledText(' ' * cellWidth));
          }
          currentCellColIndex += span;
        }
        out.add(rowLine);
      }

      // Cleanup temporary cell lines
      for (final lines in cellLinesLists) {
        for (final line in lines) {
          line.releaseRecursive(factory);
        }
      }
    }
  }

  List<int> _calculateColumnWidths(
    final TableNode node,
    final int availableWidth,
  ) {
    if (node.columnWidths.isNotEmpty) {
      // Simple validation: if sum exceeds width, scale down.
      // If sum is less, we might want to expand the last column.
      final sum = node.columnWidths.reduce((final a, final b) => a + b);
      if (sum == availableWidth) {
        return node.columnWidths;
      }

      final scaled = node.columnWidths
          .map((final w) => (w * availableWidth) ~/ sum)
          .toList();
      final newSum = scaled.fold<int>(0, (final a, final b) => a + b);
      if (newSum < availableWidth && scaled.isNotEmpty) {
        scaled[scaled.length - 1] += availableWidth - newSum;
      }
      return scaled;
    }

    // Heuristic: Equal distribution based on max column count
    int maxCols = 0;
    for (final child in node.children) {
      if (child is TableRowNode) {
        int cols = 0;
        for (final cell in child.children) {
          if (cell is TableCellNode) {
            cols += cell.colSpan;
          }
        }
        if (cols > maxCols) {
          maxCols = cols;
        }
      }
    }

    if (maxCols == 0) {
      return const [];
    }

    final widthPerCol = availableWidth ~/ maxCols;
    final result = List<int>.filled(maxCols, widthPerCol);
    result[maxCols - 1] += availableWidth % maxCols;

    return result;
  }
}
