library;

import 'dart:convert' as convert;
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:math' show max;

import 'package:characters/characters.dart';
import 'package:meta/meta.dart';

import '../../core/log_level.dart';
import '../../core/theme/log_theme.dart';
import '../../core/utils/utils.dart';
import '../../logger/logger.dart';
import '../decorator/decorator.dart';
import '../document/document.dart';
import '../encoder/encoder.dart';
import '../engine/arena_native.dart';

/// Specification for the logd Binary Intermediate Representation (B-IR) v2.
///
/// B-IR is a linearized, instruction-based memory format designed for
/// zero-copy transfer between the Dart VM and Native engines (C, Rust, Zig).
///
/// ## Memory Layout
/// A B-IR buffer consists of a fixed-size header followed by a stream of
/// variable-length OpCode blocks. Each block is 8-byte aligned.
///
/// Standard 16-byte OpCode Header:
/// [0]: opcode (uint8)
/// [1-3]: opcode-specific small payload
/// [4-7]: tags (uint32 bitmask)
/// [8-11]: primary payload (e.g. style bitmask)
/// [12-15]: secondary payload (e.g. length, count)
@internal
abstract final class BinaryIR {
  const BinaryIR._();

  /// Magic bytes identifying the format ('LOGD' in ASCII).
  static const int magic = 0x4C4F4744;

  /// Current specification version.
  static const int version = 2;

  /// Header size in bytes.
  static const int headerSize = 16;

  // --- OpCodes (1 byte) ---

  /// A block of styled text.
  /// Payload: [uint32 tags][uint32 style][uint32 length][char[] utf8_data]
  static const int opText = 0x01;

  /// A structural newline.
  static const int opNewline = 0x02;

  /// Start of a visual box or border.
  /// Payload: [uint8 type][uint32 tags][uint32 style]
  static const int opBoxStart = 0x03;

  /// End of a visual box.
  static const int opBoxEnd = 0x04;

  /// Start of an indented block.
  /// Payload: [uint32 tags][uint32 length][char[] indent_text]
  static const int opIndentStart = 0x05;

  /// End of an indented block.
  static const int opIndentEnd = 0x06;

  /// A repeated filler character.
  /// Payload: [uint8 char][uint32 tags][uint32 style][uint32 count]
  static const int opFiller = 0x07;

  /// Metadata key-value pair block.
  /// Payload: [uint32 tags][uint32 count][entries...]
  static const int opMetadata = 0x08;

  /// A potential point where the line can be wrapped.
  /// Payload: [uint8 priority]
  static const int opWrapPoint = 0x09;

  /// Resets all styling and structural state.
  static const int opReset = 0x0A;

  /// Start of a decorated block (leading/trailing).
  /// Payload: [uint8 leadingWidth][uint8 trailingWidth][uint8 flags]
  /// [uint32 tags][uint32 hintIdx][uint32 leadingCount][uint32 trailingCount]
  static const int opDecoratedStart = 0x0B;

  /// End of a decorated block.
  static const int opDecoratedEnd = 0x0C;

  /// Global document metadata.
  static const int opGlobalMetadata = 0x0D;

  /// Explicit content alignment.
  /// Payload: [uint8 alignment_type][uint32 tags]
  static const int opAlignmentStart = 0x0E;
  static const int opAlignmentEnd = 0x13;

  /// Start of a grid layout (table).
  /// Payload: [uint8 columns][uint32 tags][uint16 columnWidths[]]
  static const int opTableStart = 0x0F;

  /// End of a grid layout.
  static const int opTableEnd = 0x10;

  /// Start of a table cell.
  /// Payload: [uint8 colSpan][uint8 rowSpan][uint32 tags]
  static const int opTableCellStart = 0x11;

  /// End of a table cell.
  static const int opTableCellEnd = 0x12;

  /// Start of a table row.
  /// Payload: [uint32 tags]
  static const int opTableRowStart = 0x15;

  /// End of a table row.
  static const int opTableRowEnd = 0x16;

  /// Start of a layout row.
  /// Payload: [uint8 char][uint32 tags][uint32 styleBitmask]
  static const int opRowStart = 0x17;

  /// End of a layout row.
  static const int opRowEnd = 0x18;

  // --- Metadata Types ---
  static const int metaString = 0x01;
  static const int metaInt = 0x02;
  static const int metaBool = 0x03;
  static const int metaJson = 0x04;

  // --- Alignment Types ---
  static const int alignLeft = 0x00;
  static const int alignCenter = 0x01;
  static const int alignRight = 0x02;
  static const int alignJustify = 0x03;
}

/// An internal utility that standardizes a [LogDocument] into a [BinaryIR]
/// buffer.
///
/// This writer performs a single-pass traversal of the semantic tree and
/// linearizes it into a contiguous block of native memory, suitable for
/// zero-copy consumption by FFI-based engines.
@internal
final class BinaryIRWriter {
  BinaryIRWriter(this._document);

  final ArenaDocument _document;
  Arena get _arena => _document.arena;
  int _nodeCount = 0;
  bool _isStarted = false;

  /// Starts a new Binary IR session.
  void start() {
    _arena.resetNative(_document);
    _nodeCount = 0;

    // Write Header (16 bytes)
    final header = _arena.allocateNative(BinaryIR.headerSize, _document);
    header.cast<ffi.Uint32>()[0] = BinaryIR.magic;
    header.cast<ffi.Uint16>()[2] = BinaryIR.version;
    header.cast<ffi.Uint16>()[3] = 0; // Reserved
    _isStarted = true;
  }

  /// Resets writer state without finalizing.
  void reset() {
    _isStarted = false;
    _nodeCount = 0;
  }

  /// Finalizes the session and returns the head pointer.
  ffi.Pointer<ffi.Uint8> finalize() {
    final header = _document.nativeBufferPointer;
    if (!_isStarted || header == null) {
      throw StateError('BinaryIRWriter not started');
    }
    header.cast<ffi.Uint32>()[2] = _nodeCount;
    header.cast<ffi.Uint32>()[3] = _document.nativeBufferOffset;
    _isStarted = false;
    return header;
  }

  /// Linearizes [document] into a native buffer and returns the head pointer.
  ffi.Pointer<ffi.Uint8> write(final LogDocument document) {
    start();
    writeDocumentMetadata(document.metadata);
    for (final node in document.nodes) {
      _writeNode(node);
    }
    return finalize();
  }

  /// Linearizes a single [node] into the current buffer.
  void writeNode(final LogNode node) {
    _writeNode(node);
  }

  void _writeNode(final LogNode node) {
    switch (node) {
      case final ContentNode n:
        _writeContentNode(n);
      case final BoxNode n:
        writeBoxStart(border: n.border, style: n.style, tags: n.tags);
        for (final child in n.children) {
          _writeNode(child);
        }
        writeBoxEnd();
      case final IndentationNode n:
        writeIndentStart(n.indentString, style: n.style, tags: n.tags);
        for (final child in n.children) {
          _writeNode(child);
        }
        writeIndentEnd();
      case final FillerNode n:
        writeFiller(char: n.char, count: n.count, style: n.style, tags: n.tags);
      case final MapNode n:
        writeMap(n.map, tags: n.tags);
      case final ListNode n:
        final map = <String, Object?>{};
        for (int i = 0; i < n.list.length; i++) {
          map[i.toString()] = n.list[i];
        }
        writeMap(map, tags: n.tags);
      case final GroupNode n:
        for (final child in n.children) {
          _writeNode(child);
        }
      case final ParagraphNode n:
        for (final child in n.children) {
          _writeNode(child);
        }
        writeNewline();
      case final SectionNode n:
        _writeNode(n.summary);
        writeNewline();
        for (final child in n.children) {
          _writeNode(child);
        }
        writeNewline();
      case final DecoratedNode n:
        writeDecoratedStart(
          leading: n.leading ?? [],
          leadingWidth: n.leadingWidth,
          leadingHint: n.leadingHint,
          tags: n.tags,
          repeatLeading: n.repeatLeading,
          repeatTrailing: n.repeatTrailing,
          alignTrailing: n.alignTrailing,
          trailing: n.trailing ?? [],
          trailingWidth: n.trailingWidth,
        );
        for (final child in n.children) {
          _writeNode(child);
        }
        writeDecoratedEnd();
      case final RowNode n:
        FillerNode? filler;
        for (final child in n.children) {
          if (child is FillerNode) {
            filler = child;
            break;
          }
        }
        if (filler != null) {
          writeLayoutRowStart(
            char: filler.char,
            style: filler.style,
            tags: filler.tags,
          );
        }
        for (final child in n.children) {
          if (child != filler) {
            _writeNode(child);
          }
        }
        if (filler != null) {
          writeLayoutRowEnd();
        } else {
          writeNewline();
        }
      case final AlignmentNode n:
        writeAlignmentStart(n.alignment, tags: n.tags);
        for (final child in n.children) {
          _writeNode(child);
        }
        writeAlignmentEnd();
      case final TableNode n:
        writeTableStart(columnWidths: n.columnWidths, tags: n.tags);
        for (final child in n.children) {
          _writeNode(child);
        }
        writeTableEnd();
      case final TableRowNode n:
        writeRowStart(tags: n.tags);
        for (final child in n.children) {
          _writeNode(child);
        }
        writeRowEnd();
      case final TableCellNode n:
        writeCellStart(
          columnSpan: n.colSpan,
          rowSpan: n.rowSpan,
          tags: n.tags,
        );
        for (final child in n.children) {
          _writeNode(child);
        }
        writeCellEnd();
    }
  }

  void _writeContentNode(final ContentNode node) {
    for (final segment in node.segments) {
      writeText(
        segment.text,
        style: segment.style,
        tags: segment.tags,
      );
    }
  }

  // --- Public Emitters (Streaming API) ---

  void writeDocumentMetadata(final Map<String, Object?> metadata) {
    if (metadata.isEmpty) {
      return;
    }
    // Standardize GlobalMetadata to 16-byte header
    final ptr = _arena.allocateNative(16, _document);
    ptr[0] = BinaryIR.opGlobalMetadata;
    ptr.cast<ffi.Uint32>()[2] = metadata.length;
    _nodeCount++;

    for (final entry in metadata.entries) {
      final keyBytes = convert.utf8.encode(entry.key);
      final valStr = entry.value.toString();
      final valBytes = convert.utf8.encode(valStr);

      final entryPtr = _arena.allocateNative(
        8 + keyBytes.length + valBytes.length,
        _document,
      );
      entryPtr.cast<ffi.Uint16>()[0] = 0;
      entryPtr.cast<ffi.Uint16>()[1] = keyBytes.length;
      entryPtr.cast<ffi.Uint32>()[1] = valBytes.length;

      final keyPtr = entryPtr + 8;
      for (int i = 0; i < keyBytes.length; i++) {
        keyPtr[i] = keyBytes[i];
      }
      final valPtr = keyPtr + keyBytes.length;
      for (int i = 0; i < valBytes.length; i++) {
        valPtr[i] = valBytes[i];
      }
    }
  }

  void writeText(
    final String text, {
    final Object? style,
    final int tags = LogTag.none,
  }) {
    final mask = style is LogStyle ? style.bitmask : (style is int ? style : 0);
    final bytes = convert.utf8.encode(text);
    final ptr = _arena.allocateNative(16 + bytes.length, _document);
    ptr[0] = BinaryIR.opText;
    ptr.cast<ffi.Uint32>()[1] = tags;
    ptr.cast<ffi.Uint32>()[2] = mask;
    ptr.cast<ffi.Uint32>()[3] = bytes.length;

    final dataPtr = ptr + 16;
    for (int i = 0; i < bytes.length; i++) {
      dataPtr[i] = bytes[i];
    }
    _nodeCount++;
  }

  void writeNewline() {
    final ptr = _arena.allocateNative(8, _document);
    ptr[0] = BinaryIR.opNewline;
    _nodeCount++;
  }

  void writeBoxStart({
    final BoxBorderStyle border = BoxBorderStyle.rounded,
    final Object? style,
    final int tags = LogTag.none,
  }) {
    final mask = style is LogStyle ? style.bitmask : (style is int ? style : 0);
    final ptr = _arena.allocateNative(16, _document);
    ptr[0] = BinaryIR.opBoxStart;
    ptr[1] = border.index;
    ptr.cast<ffi.Uint32>()[1] = tags;
    ptr.cast<ffi.Uint32>()[2] = mask;
    _nodeCount++;
  }

  void writeBoxEnd() {
    final ptr = _arena.allocateNative(8, _document);
    ptr[0] = BinaryIR.opBoxEnd;
    _nodeCount++;
  }

  void writeIndentStart(
    final String indent, {
    final Object? style,
    final int tags = LogTag.none,
  }) {
    final bytes = convert.utf8.encode(indent);
    final ptr = _arena.allocateNative(16 + bytes.length, _document);
    ptr[0] = BinaryIR.opIndentStart;
    ptr.cast<ffi.Uint32>()[1] = tags;
    ptr.cast<ffi.Uint32>()[3] = bytes.length;

    final dataPtr = ptr + 16;
    for (int i = 0; i < bytes.length; i++) {
      dataPtr[i] = bytes[i];
    }
    _nodeCount++;
  }

  void writeIndentEnd() {
    final ptr = _arena.allocateNative(8, _document);
    ptr[0] = BinaryIR.opIndentEnd;
    _nodeCount++;
  }

  void writeMap(
    final Map<String, Object?> data, {
    final int tags = LogTag.none,
  }) {
    final metaPtr = _arena.allocateNative(16, _document);
    metaPtr[0] = BinaryIR.opMetadata;
    metaPtr.cast<ffi.Uint32>()[1] = tags;
    metaPtr.cast<ffi.Uint32>()[2] = data.length;
    _nodeCount++;

    for (final entry in data.entries) {
      final keyBytes = convert.utf8.encode(entry.key);
      final valStr = entry.value.toString();
      final valBytes = convert.utf8.encode(valStr);

      final entryPtr = _arena.allocateNative(
        8 + keyBytes.length + valBytes.length,
        _document,
      );
      entryPtr.cast<ffi.Uint16>()[0] = 0;
      entryPtr.cast<ffi.Uint16>()[1] = keyBytes.length;
      entryPtr.cast<ffi.Uint32>()[1] = valBytes.length;

      final keyPtr = entryPtr + 8;
      for (int i = 0; i < keyBytes.length; i++) {
        keyPtr[i] = keyBytes[i];
      }
      final valPtr = keyPtr + keyBytes.length;
      for (int i = 0; i < valBytes.length; i++) {
        valPtr[i] = valBytes[i];
      }
    }
  }

  void writeTableStart({
    final List<int>? columnWidths,
    final int tags = LogTag.none,
  }) {
    final widths = columnWidths ?? const [];
    final ptr = _arena.allocateNative(16 + (widths.length * 2), _document);
    ptr[0] = BinaryIR.opTableStart;
    ptr[1] = widths.length;
    ptr.cast<ffi.Uint32>()[1] = tags;

    final widthsPtr = ptr.cast<ffi.Uint16>() + 8;
    for (int i = 0; i < widths.length; i++) {
      widthsPtr[i] = widths[i];
    }
    _nodeCount++;
  }

  void writeTableEnd() {
    final ptr = _arena.allocateNative(8, _document);
    ptr[0] = BinaryIR.opTableEnd;
    _nodeCount++;
  }

  void writeCellStart({
    final int columnSpan = 1,
    final int rowSpan = 1,
    final int tags = LogTag.none,
  }) {
    final ptr = _arena.allocateNative(16, _document);
    ptr[0] = BinaryIR.opTableCellStart;
    ptr[1] = columnSpan;
    ptr[2] = rowSpan;
    ptr.cast<ffi.Uint32>()[1] = tags;
    _nodeCount++;
  }

  void writeCellEnd() {
    final ptr = _arena.allocateNative(8, _document);
    ptr[0] = BinaryIR.opTableCellEnd;
    _nodeCount++;
  }

  void writeRowStart({final int tags = LogTag.none}) {
    final ptr = _arena.allocateNative(16, _document);
    ptr[0] = BinaryIR.opTableRowStart;
    ptr.cast<ffi.Uint32>()[1] = tags;
    _nodeCount++;
  }

  void writeRowEnd() {
    final ptr = _arena.allocateNative(8, _document);
    ptr[0] = BinaryIR.opTableRowEnd;
    _nodeCount++;
  }

  void writeDecoratedStart({
    required final List<StyledText> leading,
    final int leadingWidth = 0,
    final String? leadingHint,
    final int tags = LogTag.none,
    final bool repeatLeading = false,
    final bool repeatTrailing = false,
    final bool alignTrailing = false,
    final List<StyledText> trailing = const [],
    final int trailingWidth = 0,
  }) {
    final ptr = _arena.allocateNative(24, _document);
    ptr[0] = BinaryIR.opDecoratedStart;
    ptr[1] = leadingWidth;
    ptr[2] = trailingWidth;

    int flags = 0;
    if (repeatLeading) {
      flags |= 1;
    }
    if (repeatTrailing) {
      flags |= 2;
    }
    if (alignTrailing) {
      flags |= 4;
    }
    ptr[3] = flags;

    ptr.cast<ffi.Uint32>()[1] = tags;

    int hintIdx = 0;
    switch (leadingHint) {
      case DecorationHint.structuredHeader:
        hintIdx = 1;
      case DecorationHint.structuredSeparator:
        hintIdx = 2;
      case DecorationHint.structuredMessage:
        hintIdx = 3;
      case DecorationHint.hierarchyTrace:
        hintIdx = 4;
      case _:
        break;
    }

    ptr.cast<ffi.Uint32>()[2] = hintIdx;
    ptr.cast<ffi.Uint32>()[3] = leading.length;
    ptr.cast<ffi.Uint32>()[4] = trailing.length;

    _nodeCount++;

    for (final segment in leading) {
      writeText(segment.text, style: segment.style, tags: segment.tags);
    }
    for (final segment in trailing) {
      writeText(segment.text, style: segment.style, tags: segment.tags);
    }
  }

  void writeDecoratedEnd() {
    final ptr = _arena.allocateNative(8, _document);
    ptr[0] = BinaryIR.opDecoratedEnd;
    _nodeCount++;
  }

  void writeFiller({
    required final String char,
    final int count = 0,
    final Object? style,
    final int tags = LogTag.none,
  }) {
    final mask = style is LogStyle ? style.bitmask : (style is int ? style : 0);
    final ptr = _arena.allocateNative(16, _document);
    ptr[0] = BinaryIR.opFiller;
    ptr[1] = char.codeUnitAt(0);
    ptr.cast<ffi.Uint32>()[1] = tags;
    ptr.cast<ffi.Uint32>()[2] = mask;
    ptr.cast<ffi.Uint32>()[3] = count;
    _nodeCount++;
  }

  void writeAlignmentStart(
    final LogAlignment alignment, {
    final int tags = LogTag.none,
  }) {
    int alignIdx = 0;
    switch (alignment) {
      case LogAlignment.center:
        alignIdx = 1;
      case LogAlignment.right:
        alignIdx = 2;
      case _:
        break;
    }

    final ptr = _arena.allocateNative(16, _document);
    ptr[0] = BinaryIR.opAlignmentStart;
    ptr[1] = alignIdx;
    ptr.cast<ffi.Uint32>()[1] = tags;
    _nodeCount++;
  }

  void writeAlignmentEnd() {
    final ptr = _arena.allocateNative(8, _document);
    ptr[0] = BinaryIR.opAlignmentEnd;
    _nodeCount++;
  }

  void writeLayoutRowStart({
    required final String char,
    final Object? style,
    final int tags = LogTag.none,
  }) {
    final mask = style is LogStyle ? style.bitmask : (style is int ? style : 0);
    final ptr = _arena.allocateNative(16, _document);
    ptr[0] = BinaryIR.opRowStart;
    ptr[1] = char.codeUnitAt(0);
    ptr.cast<ffi.Uint32>()[1] = tags;
    ptr.cast<ffi.Uint32>()[2] = mask;
    _nodeCount++;
  }

  void writeLayoutRowEnd() {
    final ptr = _arena.allocateNative(8, _document);
    ptr[0] = BinaryIR.opRowEnd;
    _nodeCount++;
  }
}

/// A lightweight reference to a native memory buffer containing Binary IR.
///
/// [NativePacket] is designed to be sent across isolates with zero-copy
/// efficiency. It contains the raw pointer, the length of the data, and
/// a completion port used to signal the main isolate when the buffer is
/// ready for reuse.
final class NativePacket {
  /// Creates a [NativePacket].
  const NativePacket({
    required this.address,
    required this.length,
    required this.terminalWidth,
    required this.completionPort,
  });

  /// The memory address of the native buffer.
  final int address;

  /// The length of the Binary IR data in bytes.
  final int length;

  /// The terminal width used for rendering.
  final int terminalWidth;

  /// The [SendPort] used to signal the [Arena] that this packet's memory
  /// can be recycled.
  final SendPort completionPort;

  /// Returns the native pointer.
  ffi.Pointer<ffi.Uint8> get pointer => ffi.Pointer.fromAddress(address);
}

/// A high-performance [LogEncoder] that renders a [BinaryIR] stream into ANSI
/// text.
///
/// This encoder serves as the reference implementation for the Native Engine.
/// It processes the linearized instruction stream (B-IR) in a single pass,
/// minimizing memory allocations and object traversal.
@internal
final class BinaryAnsiEncoder {
  const BinaryAnsiEncoder();

  /// Renders the [BinaryIR] buffer starting at [irPtr] into a string.
  String encode(
    final ffi.Pointer<ffi.Uint8> irPtr, {
    required final int terminalWidth,
    final LogLevel level = LogLevel.info,
    final int? length,
  }) {
    final buffer = StringBuffer();

    // 1. Read Header
    final magic = irPtr.cast<ffi.Uint32>()[0];
    if (magic != BinaryIR.magic) {
      return 'Error: Invalid Binary IR';
    }

    final nodeCount = irPtr.cast<ffi.Uint32>()[2];
    final totalLength = length ?? irPtr.cast<ffi.Uint32>()[3];
    int currentOffset = BinaryIR.headerSize;

    // 2. Rendering State
    int currentLineWidth = 0;
    LogStyle? activeStyle;

    void applyStyle(final StringBuffer _, final LogStyle? style) {
      if (activeStyle == style) {
        return;
      }
      if (activeStyle != null) {
        buffer.write('\x1B[0m');
        activeStyle = null;
      }
      if (style != null) {
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
        if (codes.isNotEmpty) {
          buffer.write('\x1B[${codes.join(';')}m');
          activeStyle = style;
        }
      }
    }

    void resetStyle(final StringBuffer buffer) {
      if (activeStyle != null) {
        buffer.write('\x1B[0m');
        activeStyle = null;
      }
    }

    void forceResetStyle() {
      resetStyle(buffer);
    }

    final indentStack = <_IndentEntry>[];
    final tableStack = <_TableState>[];
    final decoratedStack = <_DecoratedState>[];
    final rowFillerStack = <_RowFiller>[];
    _RowFiller? activeRowFiller() =>
        rowFillerStack.isNotEmpty ? rowFillerStack.last : null;

    int activeTrailingWidth() {
      int w = 0;
      for (final state in decoratedStack) {
        w += state.trailingWidth;
      }
      return w;
    }

    String fullIndent() {
      final base = indentStack.map((final e) => e.value).join();
      if (tableStack.isNotEmpty) {
        final state = tableStack.last;
        int tablePad = 0;
        for (int j = 0; j < state.currentColumn; j++) {
          tablePad += state.columnWidths[j] + 2; // +2 for column spacing
        }
        return base + (' ' * tablePad);
      }
      return base;
    }

    int getVisualLength(final String text, final int startPos) {
      int length = 0;
      int currentPos = startPos;
      for (final char in text.characters) {
        if (char == '\t') {
          final advance = 8 - (currentPos % 8);
          length += advance;
          currentPos += advance;
        } else {
          final advance = isWide(char) ? 2 : 1;
          length += advance;
          currentPos += advance;
        }
      }
      return length;
    }

    void writeContentText(final String str) {
      final boxCount = indentStack.whereType<_BoxIndent>().length;
      if (boxCount == 0 || !str.contains('\t')) {
        buffer.write(str);
        return;
      }
      int pos = currentLineWidth;
      for (final char in str.characters) {
        if (char == '\t') {
          final advance = 8 - (pos % 8);
          buffer.write(' ' * advance);
          pos += advance;
        } else {
          buffer.write(char);
          pos += isWide(char) ? 2 : 1;
        }
      }
    }

    void ensureIndent() {
      if (currentLineWidth == 0) {
        for (final entry in indentStack) {
          entry.write(buffer, applyStyle);
        }
        if (tableStack.isNotEmpty) {
          final state = tableStack.last;
          int tablePad = 0;
          for (int j = 0; j < state.currentColumn; j++) {
            tablePad += state.columnWidths[j] + 2;
          }
          if (tablePad > 0) {
            applyStyle(buffer, null);
            buffer.write(' ' * tablePad);
          }
        }
        final indent = fullIndent();
        currentLineWidth = getVisualLength(indent, 0);
      }
    }

    _WrappedSegment wrapSegmentText(
      final String text,
      final int startLength,
      final int availableWidth, {
      required final bool noWrap,
    }) {
      if (noWrap) {
        return _WrappedSegment(text.split('\n'), '');
      }

      final completedLines = <String>[];
      var currentLineText = '';
      var currentLength = startLength;

      final physicalLines = text.split('\n');
      for (var l = 0; l < physicalLines.length; l++) {
        if (l > 0) {
          completedLines.add(currentLineText);
          currentLineText = '';
          currentLength = 0;
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
          if (getVisualLength(word, 0) > availableWidth) {
            if (currentLineText.isNotEmpty) {
              completedLines.add(currentLineText);
              currentLineText = '';
              currentLength = 0;
            } else if (currentLength > 0) {
              completedLines.add('');
              currentLength = 0;
            }

            var remaining = word;
            while (remaining.isNotEmpty &&
                getVisualLength(remaining, 0) > availableWidth) {
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
              completedLines.add(chunk);
              remaining = remaining.substring(takeCount);
            }
            if (remaining.isNotEmpty) {
              currentLineText = remaining;
              currentLength = getVisualLength(remaining, 0);
            }
            continue;
          }

          final wordLenTrimmed = getVisualLength(
            word.replaceFirst(RegExp(r' +$'), ''),
            currentLength,
          );
          if (currentLength + wordLenTrimmed > availableWidth &&
              currentLength > 0) {
            if (currentLineText.isNotEmpty) {
              completedLines.add(currentLineText);
              currentLineText = '';
            } else {
              completedLines.add('');
            }
            currentLength = 0;
          }

          currentLineText += word;
          currentLength += getVisualLength(word, currentLength);
        }
      }

      return _WrappedSegment(completedLines, currentLineText);
    }

    void closeLine() {
      final filler = activeRowFiller();
      if (filler != null) {
        final boxCount = indentStack.whereType<_BoxIndent>().length;
        final maxContentWidth =
            terminalWidth - boxCount * 2 - activeTrailingWidth();
        final pad = maxContentWidth - currentLineWidth;
        if (pad > 0) {
          applyStyle(buffer, filler.style);
          buffer.write(filler.char * pad);
          currentLineWidth += pad;
        }
      }

      // 1. Render trailing decorations
      for (int i = decoratedStack.length - 1; i >= 0; i--) {
        final state = decoratedStack[i];
        final isFirst = state.isFirstLine;
        state.isFirstLine = false;

        final showTrailing = isFirst || state.repeatTrailing;
        if (state.alignTrailing) {
          int outerTrailingWidth = 0;
          for (int k = 0; k < i; k++) {
            final outerState = decoratedStack[k];
            outerTrailingWidth += outerState.trailingWidth;
          }
          final boxCount = indentStack.whereType<_BoxIndent>().length;
          final targetPos = terminalWidth -
              (boxCount * 2) -
              outerTrailingWidth -
              state.trailingWidth;
          final pad = targetPos - currentLineWidth;
          if (pad > 0) {
            final filler = activeRowFiller();
            if (filler != null) {
              applyStyle(buffer, filler.style);
              buffer.write(filler.char * pad);
            } else {
              final innermostBox =
                  indentStack.reversed.whereType<_BoxIndent>().firstOrNull;
              final LogStyle? style =
                  (innermostBox != null) ? innermostBox.style : null;
              applyStyle(buffer, style);
              buffer.write(' ' * pad);
            }
            currentLineWidth += pad;
          }
        }

        if (showTrailing && state.trailingSegments.isNotEmpty) {
          for (final seg in state.trailingSegments) {
            applyStyle(buffer, seg.style);
            buffer.write(seg.text);
            currentLineWidth += getVisualLength(seg.text, currentLineWidth);
          }
        } else if (state.trailingWidth > 0) {
          final filler = activeRowFiller();
          if (filler != null) {
            applyStyle(buffer, filler.style);
            buffer.write(filler.char * state.trailingWidth);
          } else {
            const LogStyle? style = null;
            applyStyle(buffer, style);
            buffer.write(' ' * state.trailingWidth);
          }
          currentLineWidth += state.trailingWidth;
        }
      }

      // 2. Pad to the right box borders and print them
      final boxCount = indentStack.whereType<_BoxIndent>().length;
      if (boxCount > 0) {
        ensureIndent();
        final suffixLen = boxCount * 2;
        final paddingNeeded = (terminalWidth - suffixLen - currentLineWidth)
            .clamp(0, terminalWidth);

        if (paddingNeeded > 0) {
          final filler = activeRowFiller();
          if (filler != null) {
            applyStyle(buffer, filler.style);
            buffer.write(filler.char * paddingNeeded);
          } else {
            final innermostBox =
                indentStack.reversed.whereType<_BoxIndent>().firstOrNull;
            final style = (innermostBox != null) ? innermostBox.style : null;
            applyStyle(buffer, style);
            buffer.write(' ' * paddingNeeded);
          }
          currentLineWidth += paddingNeeded;
        }

        for (int j = indentStack.length - 1; j >= 0; j--) {
          final entry = indentStack[j];
          if (entry is _BoxIndent) {
            final sideChar = entry.border.getChar(BoxBorderPosition.vertical);
            applyStyle(buffer, entry.style);
            buffer.write(' ');
            applyStyle(buffer, entry.style);
            buffer.write(sideChar);
            currentLineWidth += 2;
          }
        }
      }
      forceResetStyle();
      buffer.writeln();
      currentLineWidth = 0;
    }

    void renderJsonWrapped(final Map<String, String> map, final int tags) {
      final jsonStr = convert.jsonEncode(map);
      const LogStyle? style = null;

      if ((tags & LogTag.noWrap) != 0) {
        ensureIndent();
        applyStyle(buffer, style);
        buffer.write(jsonStr);
        currentLineWidth +=
            getVisualLength(_stripAnsi(jsonStr), currentLineWidth);
        closeLine();
        return;
      }

      final contentSegments = <StyledText>[];

      void flushContentSegments() {
        if (contentSegments.isNotEmpty) {
          final last = contentSegments.last;
          final trimmedText = last.text.replaceFirst(RegExp(r' +$'), '');
          if (trimmedText != last.text) {
            final diff = last.text.length - trimmedText.length;
            currentLineWidth -= diff;
            contentSegments[contentSegments.length - 1] =
                StyledText(trimmedText, style: last.style, tags: last.tags);
          }
          for (final seg in contentSegments) {
            if (seg.text.isEmpty) {
              continue;
            }
            applyStyle(buffer, seg.style ?? style);
            buffer.write(seg.text);
          }
          contentSegments.clear();
        }
      }

      final lines = jsonStr.split('\n');
      for (int l = 0; l < lines.length; l++) {
        if (l > 0) {
          flushContentSegments();
          closeLine();
        }

        final lineText = lines[l];
        if (lineText.isEmpty) {
          continue;
        }

        final boxCount = indentStack.whereType<_BoxIndent>().length;
        final maxContentWidth =
            terminalWidth - boxCount * 2 - activeTrailingWidth();

        final words = lineText.split(' ');
        for (var j = 0; j < words.length; j++) {
          final isLastWord = j == words.length - 1;
          final rawWord = words[j];
          final word = isLastWord ? rawWord : '$rawWord ';

          final indentWidth = getVisualLength(fullIndent(), 0);

          final trimmedWord = word.replaceFirst(RegExp(r' +$'), '');
          final wordLenTrimmed = getVisualLength(trimmedWord, currentLineWidth);

          if (currentLineWidth + wordLenTrimmed > maxContentWidth &&
              currentLineWidth > indentWidth) {
            flushContentSegments();
            closeLine();
            ensureIndent();
          }

          ensureIndent();

          final wordLen = getVisualLength(word, currentLineWidth);
          final availableWidth = maxContentWidth - indentWidth;

          if (wordLen > availableWidth) {
            if (currentLineWidth > indentWidth) {
              flushContentSegments();
              closeLine();
              ensureIndent();
            }

            var remaining = word;
            while (remaining.isNotEmpty) {
              final currentAvail = max(1, maxContentWidth - currentLineWidth);
              final remLen = getVisualLength(remaining, currentLineWidth);
              if (remLen <= currentAvail) {
                contentSegments.add(StyledText(remaining, style: style));
                currentLineWidth += remLen;
                break;
              } else {
                var chunk = '';
                var chunkWidth = 0;
                for (final char in remaining.characters) {
                  final charWidth =
                      getVisualLength(char, currentLineWidth + chunkWidth);
                  if (chunkWidth + charWidth <= currentAvail || chunk.isEmpty) {
                    chunk += char;
                    chunkWidth += charWidth;
                  } else {
                    break;
                  }
                }
                contentSegments.add(StyledText(chunk, style: style));
                currentLineWidth += chunkWidth;

                remaining = remaining.substring(chunk.length);
                flushContentSegments();
                closeLine();
                ensureIndent();
              }
            }
          } else {
            if (word.isNotEmpty) {
              contentSegments.add(StyledText(word, style: style));
              currentLineWidth += wordLen;
            }
          }
        }
      }
      flushContentSegments();
      closeLine();
    }

    // 3. Process Instructions
    int i = 0;
    while (i < nodeCount) {
      if (totalLength > 0 && currentOffset + 8 > totalLength) {
        break;
      }
      final opPtr = irPtr + currentOffset;
      final op = opPtr[0];

      switch (op) {
        case BinaryIR.opGlobalMetadata:
          if (totalLength > 0 && currentOffset + 16 > totalLength) {
            break;
          }
          final pairCount = opPtr.cast<ffi.Uint32>()[2];
          currentOffset += 16;
          for (int j = 0; j < pairCount; j++) {
            if (totalLength > 0 && currentOffset + 8 > totalLength) {
              break;
            }
            final entryPtr = irPtr + currentOffset;
            final keyLen = (entryPtr + 2).cast<ffi.Uint16>()[0];
            final valLen = (entryPtr + 4).cast<ffi.Uint32>()[0];
            final advance = (8 + keyLen + valLen + 7) & ~7;
            if (totalLength > 0 && currentOffset + advance > totalLength) {
              break;
            }
            currentOffset += advance;
          }
          break;

        case BinaryIR.opText:
          if (totalLength > 0 && currentOffset + 16 > totalLength) {
            break;
          }
          final tags = opPtr.cast<ffi.Uint32>()[1];
          final styleBitmask = opPtr.cast<ffi.Uint32>()[2];
          final len = opPtr.cast<ffi.Uint32>()[3];
          if (totalLength > 0 && currentOffset + 16 + len > totalLength) {
            break;
          }
          final dataPtr = opPtr + 16;

          if ((tags & LogTag.preview) != 0) {
            currentOffset += (16 + len + 7) & ~7;
            break;
          }

          final rawText = convert.utf8.decode(dataPtr.asTypedList(len));
          final text = resolveFileUris(rawText);
          final style =
              styleBitmask != 0 ? logStyleFromBitmask(styleBitmask) : null;

          void openStyle() {
            applyStyle(buffer, style);
          }

          final noWrap = (tags & LogTag.noWrap) != 0;
          final boxCount = indentStack.whereType<_BoxIndent>().length;
          final maxContentWidth =
              terminalWidth - boxCount * 2 - activeTrailingWidth();

          final indentWidth = getVisualLength(fullIndent(), 0);
          final textLen = currentLineWidth == 0
              ? getVisualLength(text, indentWidth)
              : getVisualLength(text, currentLineWidth);
          final expectedWidth = currentLineWidth == 0
              ? indentWidth + textLen
              : currentLineWidth + textLen;

          if (noWrap || (expectedWidth <= maxContentWidth)) {
            final lines = text.split('\n');
            for (int l = 0; l < lines.length; l++) {
              if (l > 0) {
                closeLine();
              }
              ensureIndent();
              final lineText = lines[l];
              if (lineText.isNotEmpty) {
                openStyle();
                writeContentText(lineText);
                currentLineWidth += getVisualLength(lineText, currentLineWidth);
              }
            }
          } else {
            final indentWidth = getVisualLength(fullIndent(), 0);
            final wrapped = wrapSegmentText(
              text,
              max(0, currentLineWidth - indentWidth),
              max(0, maxContentWidth - indentWidth),
              noWrap: noWrap,
            );

            for (final line in wrapped.completedLines) {
              ensureIndent();
              final trimmed = line.replaceFirst(RegExp(r' +$'), '');
              if (trimmed.isNotEmpty) {
                openStyle();
                writeContentText(trimmed);
                currentLineWidth += getVisualLength(trimmed, currentLineWidth);
              }
              closeLine();
            }

            if (wrapped.activeLine.isNotEmpty) {
              ensureIndent();
              openStyle();
              writeContentText(wrapped.activeLine);
              currentLineWidth +=
                  getVisualLength(wrapped.activeLine, currentLineWidth);
            }
          }

          currentOffset += (16 + len + 7) & ~7;
          break;

        case BinaryIR.opNewline:
          closeLine();
          currentOffset += 8;
          break;

        case BinaryIR.opBoxStart:
          final type = opPtr[1];
          final styleBitmask = opPtr.cast<ffi.Uint32>()[2];
          final border = BoxBorderStyle.values[type];
          final style =
              styleBitmask != 0 ? logStyleFromBitmask(styleBitmask) : null;

          ensureIndent();

          applyStyle(buffer, style);
          buffer
            ..write(
              border.getCorner(BoxBorderPosition.top, BoxBorderCorner.left),
            )
            ..write(
              border.getChar(BoxBorderPosition.horizontal) *
                  (terminalWidth - currentLineWidth - 2).clamp(0, 1000),
            )
            ..write(
              border.getCorner(BoxBorderPosition.top, BoxBorderCorner.right),
            );
          resetStyle(buffer);
          buffer.writeln();

          indentStack.add(_BoxIndent(border, style, this));
          currentLineWidth = 0;
          currentOffset += 16;
          break;

        case BinaryIR.opBoxEnd:
          if (indentStack.any((final e) => e is _BoxIndent)) {
            if (currentLineWidth > 0) {
              closeLine();
            }
            final idx = indentStack.lastIndexOf(
              indentStack.lastWhere((final e) => e is _BoxIndent),
            );
            final ctx = indentStack.removeAt(idx) as _BoxIndent;
            ensureIndent();
            applyStyle(buffer, ctx.style);
            buffer
              ..write(
                ctx.border
                    .getCorner(BoxBorderPosition.bottom, BoxBorderCorner.left),
              )
              ..write(
                ctx.border.getChar(BoxBorderPosition.horizontal) *
                    (terminalWidth - currentLineWidth - 2).clamp(0, 1000),
              )
              ..write(
                ctx.border
                    .getCorner(BoxBorderPosition.bottom, BoxBorderCorner.right),
              );
            resetStyle(buffer);
            buffer.writeln();
            currentLineWidth = 0;
          }
          currentOffset += 8;
          break;

        case BinaryIR.opIndentStart:
          if (totalLength > 0 && currentOffset + 16 > totalLength) {
            break;
          }
          // ignore: unused_local_variable
          final tags = opPtr.cast<ffi.Uint32>()[1];
          final len = opPtr.cast<ffi.Uint32>()[3];
          if (totalLength > 0 && currentOffset + 16 + len > totalLength) {
            break;
          }
          final dataPtr = opPtr + 16;
          final indent = convert.utf8.decode(dataPtr.asTypedList(len));
          indentStack.add(_StringIndent(indent));
          currentOffset += (16 + len + 7) & ~7;
          break;

        case BinaryIR.opIndentEnd:
          final idx =
              indentStack.lastIndexWhere((final e) => e is _StringIndent);
          if (idx != -1) {
            indentStack.removeAt(idx);
          }
          currentOffset += 8;
          break;

        case BinaryIR.opFiller:
          final char = String.fromCharCode(opPtr[1]);
          final styleBitmask = opPtr.cast<ffi.Uint32>()[2];
          final count = opPtr.cast<ffi.Uint32>()[3];
          final style =
              styleBitmask != 0 ? logStyleFromBitmask(styleBitmask) : null;

          ensureIndent();
          final boxCount = indentStack.whereType<_BoxIndent>().length;
          final maxContentWidth =
              terminalWidth - boxCount * 2 - activeTrailingWidth();
          final actualCount = (count == 0)
              ? (maxContentWidth - currentLineWidth).clamp(0, terminalWidth)
              : count;

          applyStyle(buffer, style);
          buffer.write(char * actualCount);
          currentLineWidth += actualCount;
          currentOffset += 16;
          break;

        case BinaryIR.opDecoratedStart:
          if (totalLength > 0 && currentOffset + 24 > totalLength) {
            break;
          }
          final leadingWidth = opPtr[1];
          final trailingWidth = opPtr[2];
          final flags = opPtr[3];
          final repeatLeading = (flags & 1) != 0;
          final repeatTrailing = (flags & 2) != 0;
          final alignTrailing = (flags & 4) != 0;
          // ignore: unused_local_variable
          final tags = opPtr.cast<ffi.Uint32>()[1];
          final hintIdx = opPtr.cast<ffi.Uint32>()[2];
          final leadingCount = opPtr.cast<ffi.Uint32>()[3];
          final trailingCount = opPtr.cast<ffi.Uint32>()[4];

          currentOffset += 24;
          ensureIndent();

          final boxCount = indentStack.whereType<_BoxIndent>().length;
          final maxContentWidth = terminalWidth -
              boxCount * 2 -
              activeTrailingWidth() -
              trailingWidth;
          final contentWidth =
              maxContentWidth - currentLineWidth - leadingWidth;
          final useFallback =
              contentWidth < 12 && !repeatLeading && leadingCount > 0;

          final leadingSegments = <StyledText>[];
          final initialWidth = currentLineWidth;

          for (int j = 0; j < leadingCount; j++) {
            if (totalLength > 0 && currentOffset + 16 > totalLength) {
              break;
            }
            final segPtr = irPtr + currentOffset;
            final segOp = segPtr[0];
            if (segOp == BinaryIR.opText) {
              final segTags = segPtr.cast<ffi.Uint32>()[1];
              final segStyleBitmask = segPtr.cast<ffi.Uint32>()[2];
              final segLen = segPtr.cast<ffi.Uint32>()[3];
              if (totalLength > 0 &&
                  currentOffset + 16 + segLen > totalLength) {
                break;
              }
              final segDataPtr = segPtr + 16;
              final segText =
                  convert.utf8.decode(segDataPtr.asTypedList(segLen));
              final segStyle = segStyleBitmask != 0
                  ? logStyleFromBitmask(segStyleBitmask)
                  : null;

              leadingSegments
                  .add(StyledText(segText, style: segStyle, tags: segTags));

              if (!useFallback) {
                applyStyle(buffer, segStyle);
                buffer.write(segText);
                currentLineWidth += getVisualLength(segText, currentLineWidth);
              }
              currentOffset += (16 + segLen + 7) & ~7;
            } else {
              currentOffset += 8;
            }
          }

          final trailingSegments = <StyledText>[];
          for (int j = 0; j < trailingCount; j++) {
            if (totalLength > 0 && currentOffset + 16 > totalLength) {
              break;
            }
            final segPtr = irPtr + currentOffset;
            final segOp = segPtr[0];
            if (segOp == BinaryIR.opText) {
              final segTags = segPtr.cast<ffi.Uint32>()[1];
              final segStyleBitmask = segPtr.cast<ffi.Uint32>()[2];
              final segLen = segPtr.cast<ffi.Uint32>()[3];
              if (totalLength > 0 &&
                  currentOffset + 16 + segLen > totalLength) {
                break;
              }
              final segDataPtr = segPtr + 16;
              final segText =
                  convert.utf8.decode(segDataPtr.asTypedList(segLen));
              final segStyle = segStyleBitmask != 0
                  ? logStyleFromBitmask(segStyleBitmask)
                  : null;

              trailingSegments
                  .add(StyledText(segText, style: segStyle, tags: segTags));
              currentOffset += (16 + segLen + 7) & ~7;
            } else {
              currentOffset += 8;
            }
          }

          i += leadingCount + trailingCount;

          final state = _DecoratedState(
            leadingWidth: useFallback ? 0 : leadingWidth,
            trailingSegments: useFallback ? const [] : trailingSegments,
            trailingWidth: useFallback ? 0 : trailingWidth,
            repeatTrailing: !useFallback && repeatTrailing,
            alignTrailing: !useFallback && alignTrailing,
          );
          decoratedStack.add(state);

          if (useFallback) {
            for (final segment in leadingSegments) {
              final text = resolveFileUris(segment.text);
              final style = segment.style;
              final lines = text.split('\n');
              for (int l = 0; l < lines.length; l++) {
                if (l > 0) {
                  closeLine();
                }

                final lineText = lines[l];
                if (lineText.isEmpty) {
                  continue;
                }

                final dynamicMaxContentWidth =
                    terminalWidth - boxCount * 2 - activeTrailingWidth();

                final words = lineText.split(' ');
                for (var j = 0; j < words.length; j++) {
                  final isLastWord = j == words.length - 1;
                  var word = words[j];

                  // 1. Check if the current word (without space) wraps.
                  final currentWordLen =
                      getVisualLength(word, currentLineWidth);

                  if (currentLineWidth + currentWordLen >
                      dynamicMaxContentWidth) {
                    final indentWidth = getVisualLength(fullIndent(), 0);
                    if (currentLineWidth > indentWidth) {
                      closeLine();
                    }
                  }

                  ensureIndent();

                  // 2. Now currentLineWidth is where the word will be printed.
                  final wordStartLineWidth = currentLineWidth;

                  // 3. Determine if we should append a space
                  bool appendSpace = !isLastWord;
                  bool forceCloseAfter = false;
                  if (appendSpace) {
                    final currentWordLenWithSpace =
                        getVisualLength('$word ', wordStartLineWidth);
                    final nextWord = words[j + 1];
                    final nextWordLen = getVisualLength(
                      nextWord,
                      wordStartLineWidth + currentWordLenWithSpace,
                    );
                    if (wordStartLineWidth +
                            currentWordLenWithSpace +
                            nextWordLen >
                        dynamicMaxContentWidth) {
                      appendSpace = false;
                      forceCloseAfter = true;
                    }
                  }

                  if (appendSpace) {
                    word = '$word ';
                  }
                  final wordLen = getVisualLength(word, currentLineWidth);

                  if (word.isNotEmpty) {
                    final avail = dynamicMaxContentWidth - currentLineWidth;
                    if (wordLen > avail) {
                      // Word is too long, we must chunk it
                      var remaining = word;
                      while (remaining.isNotEmpty) {
                        final currentAvail =
                            max(1, dynamicMaxContentWidth - currentLineWidth);
                        final remLen =
                            getVisualLength(remaining, currentLineWidth);
                        if (remLen <= currentAvail) {
                          applyStyle(buffer, style);
                          buffer.write(remaining);
                          currentLineWidth += remLen;
                          break;
                        } else {
                          var chunk = '';
                          var chunkWidth = 0;
                          for (final char in remaining.characters) {
                            final charWidth = getVisualLength(
                              char,
                              currentLineWidth + chunkWidth,
                            );
                            if (chunkWidth + charWidth <= currentAvail ||
                                chunk.isEmpty) {
                              chunk += char;
                              chunkWidth += charWidth;
                            } else {
                              break;
                            }
                          }
                          applyStyle(buffer, style);
                          buffer.write(chunk);
                          currentLineWidth += chunkWidth;

                          remaining = remaining.substring(chunk.length);
                          closeLine();
                          ensureIndent();
                        }
                      }
                    } else {
                      applyStyle(buffer, style);
                      buffer.write(word);
                      currentLineWidth += wordLen;
                    }
                  }

                  if (forceCloseAfter) {
                    closeLine();
                  }
                }
              }
            }
            closeLine();
            indentStack.add(_StringIndent(''));
          } else {
            if (currentLineWidth - initialWidth < leadingWidth) {
              final pad = leadingWidth - (currentLineWidth - initialWidth);
              buffer.write(' ' * pad);
              currentLineWidth += pad;
            }

            if (repeatLeading) {
              final segs = List<StyledText>.from(leadingSegments);
              int renderedWidth = 0;
              for (final seg in leadingSegments) {
                renderedWidth += getVisualLength(seg.text, renderedWidth);
              }
              if (renderedWidth < leadingWidth) {
                segs.add(StyledText(' ' * (leadingWidth - renderedWidth)));
              }
              indentStack.add(_DecoratedIndent(segs));
            } else {
              String rawDec = ' ' * leadingWidth;
              if (hintIdx == 1 || hintIdx == 2) {
                rawDec = '_' * leadingWidth;
              } else if (hintIdx == 4) {
                rawDec = '│${' ' * (leadingWidth - 1)}';
              }
              const LogStyle? decStyle = null;
              indentStack
                  .add(_DecoratedIndent([StyledText(rawDec, style: decStyle)]));
            }
          }
          break;

        case BinaryIR.opDecoratedEnd:
          if (decoratedStack.isNotEmpty) {
            decoratedStack.removeLast();
          }
          final idx = indentStack.lastIndexWhere(
            (final e) => e is _DecoratedIndent || e is _StringIndent,
          );
          if (idx != -1) {
            indentStack.removeAt(idx);
          }
          currentOffset += 8;
          break;

        case BinaryIR.opTableStart:
          if (totalLength > 0 && currentOffset + 16 > totalLength) {
            break;
          }
          final colCount = opPtr[1];
          final advance = (16 + colCount * 2 + 7) & ~7;
          if (totalLength > 0 && currentOffset + advance > totalLength) {
            break;
          }
          // ignore: unused_local_variable
          final tags = opPtr.cast<ffi.Uint32>()[1];
          final widthsPtr = opPtr.cast<ffi.Uint16>() + 8;
          final widths = <int>[];
          for (int j = 0; j < colCount; j++) {
            widths.add(widthsPtr[j]);
          }
          tableStack.add(_TableState(widths));
          currentOffset += advance;
          break;

        case BinaryIR.opTableEnd:
          if (tableStack.isNotEmpty) {
            tableStack.removeLast();
          }
          currentOffset += 8;
          break;

        case BinaryIR.opTableRowStart:
          if (tableStack.isNotEmpty) {
            tableStack.last.currentColumn = -1;
          }
          currentOffset += 16;
          break;

        case BinaryIR.opTableRowEnd:
          closeLine();
          currentOffset += 8;
          break;

        case BinaryIR.opTableCellStart:
          if (tableStack.isNotEmpty) {
            tableStack.last.currentColumn++;
            tableStack.last.cellStartWidth = currentLineWidth;
          }
          currentOffset += 16;
          break;

        case BinaryIR.opTableCellEnd:
          if (tableStack.isNotEmpty) {
            final state = tableStack.last;
            if (state.currentColumn < state.columnWidths.length) {
              final targetWidth = state.columnWidths[state.currentColumn];
              final cellWidth = currentLineWidth - state.cellStartWidth;
              if (cellWidth < targetWidth) {
                final pad = targetWidth - cellWidth;
                buffer.write(' ' * pad);
                currentLineWidth += pad;
              }
            }
            buffer.write('  '); // Column spacing
            currentLineWidth += 2;
          }
          currentOffset += 8;
          break;

        case BinaryIR.opAlignmentStart:
          final alignIdx = opPtr[1];
          ensureIndent();
          if (alignIdx == BinaryIR.alignCenter) {
            final pad = ((terminalWidth - currentLineWidth) ~/ 4)
                .clamp(0, terminalWidth);
            buffer.write(' ' * pad);
            currentLineWidth += pad;
          } else if (alignIdx == BinaryIR.alignRight) {
            final pad = ((terminalWidth - currentLineWidth) ~/ 2)
                .clamp(0, terminalWidth);
            buffer.write(' ' * pad);
            currentLineWidth += pad;
          }
          currentOffset += 16;
          break;

        case BinaryIR.opAlignmentEnd:
          currentOffset += 8;
          break;

        case BinaryIR.opMetadata:
          if (totalLength > 0 && currentOffset + 16 > totalLength) {
            break;
          }
          // ignore: unused_local_variable
          final tags = opPtr.cast<ffi.Uint32>()[1];
          final pairCount = opPtr.cast<ffi.Uint32>()[2];
          final map = <String, String>{};
          currentOffset += 16;
          for (int j = 0; j < pairCount; j++) {
            if (totalLength > 0 && currentOffset + 8 > totalLength) {
              break;
            }
            final entryPtr = irPtr + currentOffset;
            final keyLen = (entryPtr + 2).cast<ffi.Uint16>()[0];
            final valLen = (entryPtr + 4).cast<ffi.Uint32>()[0];
            final advance = (8 + keyLen + valLen + 7) & ~7;
            if (totalLength > 0 && currentOffset + advance > totalLength) {
              break;
            }

            final key = convert.utf8.decode((entryPtr + 8).asTypedList(keyLen));
            final val = convert.utf8
                .decode((entryPtr + 8 + keyLen).asTypedList(valLen));
            map[key] = val;

            currentOffset += advance;
          }

          renderJsonWrapped(map, tags);
          break;

        case BinaryIR.opRowStart:
          final char = String.fromCharCode(opPtr[1]);
          final styleBitmask = opPtr.cast<ffi.Uint32>()[2];
          final style =
              styleBitmask != 0 ? logStyleFromBitmask(styleBitmask) : null;
          rowFillerStack.add(_RowFiller(char, style));
          currentOffset += 16;
          break;

        case BinaryIR.opRowEnd:
          closeLine();
          if (rowFillerStack.isNotEmpty) {
            rowFillerStack.removeLast();
          }
          currentOffset += 8;
          break;

        default:
          currentOffset += 8;
          break;
      }
      i++;
    }

    if (currentLineWidth > 0) {
      closeLine();
    }
    forceResetStyle();

    return buffer.toString();
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

  String _stripAnsi(final String text) =>
      text.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
}

LogStyle logStyleFromBitmask(final int mask) {
  if (mask == 0) {
    return const LogStyle();
  }
  final fg = mask & 0xF;
  final bg = (mask >> 4) & 0xF;
  return LogStyle(
    color: fg == 15 ? null : LogColor.values[fg],
    backgroundColor: bg == 15 ? null : LogColor.values[bg],
    bold: (mask & (1 << 8)) != 0,
    dim: (mask & (1 << 9)) != 0,
    italic: (mask & (1 << 10)) != 0,
    inverse: (mask & (1 << 11)) != 0,
    underline: (mask & (1 << 12)) != 0,
  );
}

abstract class _IndentEntry {
  String get value;
  void write(
    final StringBuffer buffer,
    final void Function(StringBuffer, LogStyle?) applyStyle,
  );
}

class _StringIndent extends _IndentEntry {
  _StringIndent(this.value);
  @override
  final String value;
  @override
  void write(
    final StringBuffer buffer,
    final void Function(StringBuffer, LogStyle?) applyStyle,
  ) {
    if (value.isNotEmpty) {
      applyStyle(buffer, null);
      buffer.write(value);
    }
  }
}

class _BoxIndent extends _IndentEntry {
  _BoxIndent(this.border, this.style, this.encoder);
  final BoxBorderStyle border;
  final LogStyle? style;
  final BinaryAnsiEncoder encoder;

  @override
  String get value => '${border.getChar(BoxBorderPosition.vertical)} ';

  @override
  void write(
    final StringBuffer buffer,
    final void Function(StringBuffer, LogStyle?) applyStyle,
  ) {
    applyStyle(buffer, style);
    buffer.write(border.getChar(BoxBorderPosition.vertical));
    applyStyle(buffer, style);
    buffer.write(' ');
  }
}

class _DecoratedIndent extends _IndentEntry {
  _DecoratedIndent(this.segments);
  final List<StyledText> segments;

  @override
  String get value => segments.map((final s) => s.text).join();

  @override
  void write(
    final StringBuffer buffer,
    final void Function(StringBuffer, LogStyle?) applyStyle,
  ) {
    for (final seg in segments) {
      if (seg.text.isNotEmpty) {
        applyStyle(buffer, seg.style);
        buffer.write(seg.text);
      }
    }
  }
}

class _TableState {
  _TableState(this.columnWidths);
  final List<int> columnWidths;
  int currentColumn = -1;
  int cellStartWidth = 0;
}

class _DecoratedState {
  _DecoratedState({
    required this.leadingWidth,
    required this.trailingSegments,
    required this.trailingWidth,
    required this.repeatTrailing,
    required this.alignTrailing,
  });

  final int leadingWidth;
  final List<StyledText> trailingSegments;
  final int trailingWidth;
  final bool repeatTrailing;
  final bool alignTrailing;

  bool isFirstLine = true;
}

class _RowFiller {
  _RowFiller(this.char, this.style);
  final String char;
  final LogStyle? style;
}

class _WrappedSegment {
  const _WrappedSegment(this.completedLines, this.activeLine);
  final List<String> completedLines;
  final String activeLine;
}

/// A high-performance [LogEncoder] that renders a [BinaryIR] stream into
/// Token-Oriented Object Notation (TOON).
///
/// This encoder is used by the Native Engine's background isolate to
/// support structured logging with zero-latency.
@internal
final class BinaryToonEncoder {
  const BinaryToonEncoder();

  /// Renders the [BinaryIR] buffer into TOON format.
  String encode(
    final ffi.Pointer<ffi.Uint8> irPtr, {
    final int? length,
  }) {
    final buffer = StringBuffer();

    // 1. Read Header
    final magic = irPtr.cast<ffi.Uint32>()[0];
    if (magic != BinaryIR.magic) {
      return 'Error: Invalid Binary IR';
    }

    final nodeCount = irPtr.cast<ffi.Uint32>()[2];
    final totalLength = length ?? irPtr.cast<ffi.Uint32>()[3];
    int currentOffset = BinaryIR.headerSize;

    // 2. State
    final globalMetadata = <String, Object?>{};
    final List<Map<String, Object?>> rows = [];

    // 3. Process Instructions
    for (int i = 0; i < nodeCount; i++) {
      if (totalLength > 0 && currentOffset + 8 > totalLength) {
        break;
      }
      final opPtr = irPtr + currentOffset;
      final op = opPtr[0];

      switch (op) {
        case BinaryIR.opGlobalMetadata:
          if (totalLength > 0 && currentOffset + 8 > totalLength) {
            break;
          }
          final count = opPtr.cast<ffi.Uint32>()[1];
          currentOffset += 8;
          for (int j = 0; j < count; j++) {
            if (totalLength > 0 && currentOffset + 8 > totalLength) {
              break;
            }
            final entry = _readMetadataEntry(irPtr + currentOffset);
            if (totalLength > 0 &&
                currentOffset + entry.totalSize > totalLength) {
              break;
            }
            globalMetadata[entry.key] = entry.value;
            currentOffset += entry.totalSize;
          }

        case BinaryIR.opMetadata:
          if (totalLength > 0 && currentOffset + 8 > totalLength) {
            break;
          }
          final count = opPtr.cast<ffi.Uint32>()[1];
          currentOffset += 8;
          final map = <String, Object?>{};
          for (int j = 0; j < count; j++) {
            if (totalLength > 0 && currentOffset + 8 > totalLength) {
              break;
            }
            final entry = _readMetadataEntry(irPtr + currentOffset);
            if (totalLength > 0 &&
                currentOffset + entry.totalSize > totalLength) {
              break;
            }
            map[entry.key] = entry.value;
            currentOffset += entry.totalSize;
          }
          rows.add(map);

        case BinaryIR.opText:
          if (totalLength > 0 && currentOffset + 16 > totalLength) {
            break;
          }
          final len = opPtr.cast<ffi.Uint32>()[3];
          currentOffset += 16 + len;
        case BinaryIR.opNewline:
          currentOffset += 8;
        case BinaryIR.opBoxStart:
        case BinaryIR.opBoxEnd:
          currentOffset += 8;
        case BinaryIR.opIndentStart:
          if (totalLength > 0 && currentOffset + 16 > totalLength) {
            break;
          }
          final len = opPtr.cast<ffi.Uint32>()[3];
          currentOffset += 16 + len;
        case BinaryIR.opIndentEnd:
          currentOffset += 8;
        case BinaryIR.opFiller:
          currentOffset += 20;
        case BinaryIR.opDecoratedStart:
          if (totalLength > 0 && currentOffset + 24 > totalLength) {
            break;
          }
          final leadingCount = opPtr.cast<ffi.Uint32>()[3];
          final trailingCount = opPtr.cast<ffi.Uint32>()[4];
          currentOffset += 24;
          for (int j = 0; j < leadingCount; j++) {
            if (totalLength > 0 && currentOffset + 16 > totalLength) {
              break;
            }
            final segPtr = irPtr + currentOffset;
            final segLen = segPtr.cast<ffi.Uint32>()[3];
            currentOffset += (16 + segLen + 7) & ~7;
          }
          for (int j = 0; j < trailingCount; j++) {
            if (totalLength > 0 && currentOffset + 16 > totalLength) {
              break;
            }
            final segPtr = irPtr + currentOffset;
            final segLen = segPtr.cast<ffi.Uint32>()[3];
            currentOffset += (16 + segLen + 7) & ~7;
          }
          i += leadingCount + trailingCount;
        case BinaryIR.opDecoratedEnd:
          currentOffset += 8;
        default:
          currentOffset += 8;
      }
    }

    // 4. Render TOON
    final arrayName = globalMetadata['toon_array'] as String? ?? 'logs';
    final delimiter = globalMetadata['toon_delimiter'] as String? ?? '\t';
    final columns = globalMetadata['toon_columns'] as List<dynamic>?;

    if (columns == null || rows.isEmpty) {
      return '';
    }

    // Header (Simplified for offload)
    buffer.write('$arrayName[]${columns.join(',')}:');

    // Rows
    for (int i = 0; i < rows.length; i++) {
      final rowMap = rows[i];
      final row = columns.map((final col) {
        final val = rowMap[col.toString()];
        return _escape(val?.toString() ?? '', delimiter);
      }).join(delimiter);

      buffer.write(row);
      if (i < rows.length - 1) {
        buffer.write('\n');
      }
    }

    return buffer.toString();
  }

  _MetadataEntry _readMetadataEntry(final ffi.Pointer<ffi.Uint8> ptr) {
    final type = ptr[0];
    final keyLen = (ptr + 2).cast<ffi.Uint16>()[0];
    final key = convert.utf8.decode((ptr + 4).asTypedList(keyLen));

    final valLenPtr = (ptr + 4 + keyLen).cast<ffi.Uint32>();
    final valLen = valLenPtr[0];
    final valStr = convert.utf8.decode((ptr + 8 + keyLen).asTypedList(valLen));

    Object? value = valStr;
    if (type == BinaryIR.metaInt) {
      value = int.tryParse(valStr);
    } else if (type == BinaryIR.metaBool) {
      value = valStr == 'true';
    } else if (type == BinaryIR.metaJson) {
      try {
        value = convert.jsonDecode(valStr);
      } catch (_) {}
    }

    return _MetadataEntry(key, value, 8 + keyLen + valLen);
  }

  String _escape(final String value, final String delimiter) {
    if (value.isEmpty) {
      return '';
    }
    if (!value.contains(delimiter) && !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';
  }
}

class _MetadataEntry {
  _MetadataEntry(this.key, this.value, this.totalSize);
  final String key;
  final Object? value;
  final int totalSize;
}
