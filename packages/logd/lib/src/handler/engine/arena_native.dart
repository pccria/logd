library;

import 'dart:async';
import 'dart:collection';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:math' show max;

import 'package:ffi/ffi.dart' as pkg_ffi;
import 'package:meta/meta.dart';

import '../../../logd.dart' show Handler;
import '../../core/theme/log_theme.dart';
import '../../logger/logger.dart';
import '../../stack_trace/stack_trace.dart';
import '../document/binary_ir_native.dart';
import '../document/document.dart';
import '../engine/engine.dart';
import '../handler.dart' show Handler;
import '../layout/layout.dart';

/// An isolate-local resource pool for deterministic object reuse.
///
/// [Arena] provides a LIFO-based pooling mechanism to eliminate allocation
/// overhead and garbage collection (GC) churn during steady-state logging.
///
/// **Lifecycle contract**:
/// 1. **Checkout**: Obtain a recycled or fresh instance via `checkout*()`.
/// 2. **Population**: Initialize the object's state using the provided data.
/// 3. **Execution**: Process the document through the configured pipeline.
/// 4. **Release**: Invoke `document.releaseRecursive(arena)` to return the
///    entire object graph to the pool for subsequent reuse.
///
/// **Safety invariants**:
/// - Arena-owned documents and nodes **must never** be retained across log
///   cycles (no caching, no storing in long-lived state).
/// - Only the [Handler] orchestrates checkout/release; formatters and
///   decorators receive the arena only to create new nodes.
/// - This class is **not** thread-safe. Isolate isolation is the safety
///   boundary.
@experimental
class Arena implements LogPipelineFactory {
  // Private constructor; use [instance] for isolate-local access.
  Arena._();

  /// The isolate-local singleton arena.
  static final Arena instance = Arena._();

  // ---------------------------------------------------------------------------
  // LIFO pools — one list per concrete node type.
  // ---------------------------------------------------------------------------
  final List<LogDocument> _documents = [];
  final List<HeaderNode> _headers = [];
  final List<MessageNode> _messages = [];
  final List<ErrorNode> _errors = [];
  final List<FooterNode> _footers = [];
  final List<MetadataNode> _metadataNodes = [];
  final List<BoxNode> _boxes = [];
  final List<IndentationNode> _indents = [];
  final List<GroupNode> _groups = [];
  final List<DecoratedNode> _decorated = [];
  final List<ParagraphNode> _paragraphs = [];
  final List<RowNode> _rows = [];
  final List<SectionNode> _sections = [];
  final List<FillerNode> _fillers = [];
  final List<MapNode> _maps = [];
  final List<ListNode> _lists = [];
  final List<AlignmentNode> _alignments = [];
  final List<TableNode> _tables = [];
  final List<TableRowNode> _tableRows = [];
  final List<TableCellNode> _tableCells = [];
  final List<HandlerContext> _contexts = [];
  final List<PhysicalLine> _physicalLines = [];
  final List<PhysicalDocument> _physicalDocuments = [];
  final List<LogEntry> _logEntries = [];

  final List<Map<String, Object?>> _dataMaps = [];
  final List<List<LogNode>> _nodeLists = [];
  final List<List<StyledText>> _segmentLists = [];
  final List<List<dynamic>> _dynamicLists = [];
  final List<Set<LogMetadata>> _metadataSets = [];

  // --- Native Memory Pool (B-IR Dispatch) ---
  final List<_NativeBuffer> _freeNativeBuffers = [];
  final Map<int, _NativeBuffer> _inFlightNativeBuffers = {};

  /// The number of native packets currently in-flight.
  @internal
  int get inFlightCount => _inFlightNativeBuffers.length;

  ReceivePort? _completionPort;

  @internal
  ReceivePort get completionPort {
    final port = _completionPort;
    if (port != null) {
      return port;
    }
    return _completionPort = ReceivePort()..listen(_handlePacketCompletion);
  }

  static const _defaultPacketSize = 64 * 1024; // 64KB

  int _totalAllocatedBytes = 0;

  /// The total native memory currently allocated by the arena pool (in bytes).
  @internal
  int get totalAllocatedBytes => _totalAllocatedBytes;

  /// The maximum number of native packets allowed to be in-flight before
  /// the main thread blocks (backpressure).
  static const int maxInFlightPackets = 200;

  /// The maximum capacity for any single type pool in the Arena.
  static const int _maxPoolSize = 1000;

  bool _saturationWarningFired = false;

  /// The maximum total native memory (in bytes) the arena can allocate.
  static const int maxNativeMemory = 128 * 1024 * 1024; // 128MB

  final List<Completer<void>> _poolWaiters = [];

  void _handlePacketCompletion(final dynamic address) {
    if (address is int) {
      final buffer = _inFlightNativeBuffers.remove(address);
      if (buffer != null) {
        buffer.offset = 0;
        _freeNativeBuffers.add(buffer);

        // Notify waiters that capacity is available (with hysteresis)
        final threshold = (maxInFlightPackets * 0.8).toInt();
        if (_inFlightNativeBuffers.length < threshold) {
          _saturationWarningFired = false;
        }

        if (_poolWaiters.isNotEmpty) {
          for (final waiter in _poolWaiters) {
            if (!waiter.isCompleted) {
              waiter.complete();
            }
          }
          _poolWaiters.clear();
        }
      }
    }
  }

  /// Waits until the pool has capacity to accept new native packets.
  Future<void> waitForPoolCapacity() async {
    if (_inFlightNativeBuffers.length < maxInFlightPackets) {
      return;
    }

    final sw = Stopwatch()..start();
    while (_inFlightNativeBuffers.length >= maxInFlightPackets) {
      final waiter = Completer<void>();
      _poolWaiters.add(waiter);
      await waiter.future;
    }
    sw.stop();
    if (sw.elapsedMilliseconds > 10) {
      InternalLogger.log(
        LogLevel.warning,
        'Blocked main thread for ${sw.elapsedMilliseconds}ms '
        'waiting for pool capacity.',
      );
    }
  }

  /// Returns the offset into the current native buffer.

  void resetNative(final ArenaDocument document) {
    for (final buffer in document._buffers) {
      buffer.offset = 0;
      _freeNativeBuffers.add(buffer);
    }
    document._buffers.clear();
    document._currentBuffer = null;
  }

  NativePacket checkoutNativePacket(
    final ArenaDocument document, {
    required final int terminalWidth,
  }) {
    final buffer = document._currentBuffer;
    if (buffer == null || buffer.offset == 0) {
      throw StateError('No native data to dispatch');
    }

    _inFlightNativeBuffers[buffer.pointer.address] = buffer;
    document._currentBuffer = null;
    document._buffers.remove(buffer);

    // Log a warning if pool is saturated (blocking happens in NativeEngine)
    if (_inFlightNativeBuffers.length >= maxInFlightPackets &&
        !_saturationWarningFired) {
      _saturationWarningFired = true;
      InternalLogger.log(
        LogLevel.warning,
        'Arena saturation reached (${_inFlightNativeBuffers.length} '
        'packets). Blocking main thread.',
      );
    }

    return NativePacket(
      address: buffer.pointer.address,
      length: buffer.offset,
      terminalWidth: terminalWidth,
      completionPort: completionPort.sendPort,
    );
  }

  /// Reclaims all in-flight buffers back to the free pool.
  ///
  /// This should be called if the background worker isolate fails or
  /// is shut down abruptly to prevent native memory leaks.
  void reclaimInFlightBuffers() {
    for (final buffer in _inFlightNativeBuffers.values) {
      buffer.offset = 0;
      _freeNativeBuffers.add(buffer);
    }
    _inFlightNativeBuffers.clear();

    // Release any blocked threads
    if (_poolWaiters.isNotEmpty) {
      for (final waiter in _poolWaiters) {
        if (!waiter.isCompleted) {
          waiter.complete();
        }
      }
      _poolWaiters.clear();
    }
  }

  ffi.Pointer<ffi.Uint8> allocateNative(
    final int size,
    final ArenaDocument document,
  ) {
    final alignedSize = (size + 7) & ~7;

    var buffer = document._currentBuffer;
    if (buffer == null) {
      buffer = _checkoutNewBuffer(max(_defaultPacketSize, alignedSize));
      document._buffers.add(buffer);
      document._currentBuffer = buffer;
    } else if (buffer.offset + alignedSize > buffer.size) {
      // Must grow contiguous buffer to prevent multi-buffer fragmentation
      // and out-of-bounds heap reads in BinaryAnsiEncoder.
      final newCapacity = max(buffer.size * 2, buffer.offset + alignedSize);
      final newBuffer = _checkoutNewBuffer(newCapacity);
      if (buffer.offset > 0) {
        newBuffer.pointer.asTypedList(buffer.offset).setAll(
              0,
              buffer.pointer.asTypedList(buffer.offset),
            );
        newBuffer.offset = buffer.offset;
      }
      buffer.offset = 0;
      _freeNativeBuffers.add(buffer);
      document._buffers.remove(buffer);
      document._buffers.add(newBuffer);
      document._currentBuffer = newBuffer;
      buffer = newBuffer;
    }

    final ptr = buffer.pointer + buffer.offset;
    buffer.offset += alignedSize;
    return ptr.cast();
  }

  _NativeBuffer _checkoutNewBuffer(final int size) {
    // 1. Try free pool
    for (int i = 0; i < _freeNativeBuffers.length; i++) {
      if (_freeNativeBuffers[i].size >= size) {
        return _freeNativeBuffers.removeAt(i)..offset = 0;
      }
    }

    // 2. Free unused buffers from pool if nearing maxNativeMemory
    while (_freeNativeBuffers.isNotEmpty &&
        _totalAllocatedBytes + size > maxNativeMemory) {
      final b = _freeNativeBuffers.removeLast();
      pkg_ffi.malloc.free(b.pointer);
      _totalAllocatedBytes -= b.size;
    }

    // 3. Allocate fresh
    if (_totalAllocatedBytes + size > maxNativeMemory) {
      throw const OutOfMemoryError();
    }

    final pointer = pkg_ffi.malloc.allocate<ffi.Uint8>(size);
    _totalAllocatedBytes += size;
    return _NativeBuffer(pointer, size);
  }

  // ---------------------------------------------------------------------------
  // Checkout helpers — pop from pool or allocate a fresh instance.
  // ---------------------------------------------------------------------------

  /// Checks out a [LogDocument] from the pool, or allocates a fresh one.
  @override
  LogDocument checkoutDocument() =>
      _documents.isNotEmpty ? _documents.removeLast() : ArenaDocument(this);

  /// Checks out a [LogEntry] from the pool, or allocates a fresh one.
  @internal
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
      (_logEntries.isNotEmpty ? _logEntries.removeLast() : LogEntry.pooled())
        ..loggerName = loggerName
        ..origin = origin
        ..level = level
        ..message = message
        ..timestamp = timestamp
        ..stackFrames = stackFrames
        ..error = error
        ..stackTrace = stackTrace
        ..context = context;

  /// Releases a [LogEntry] back to the pool.
  @internal
  void releaseLogEntry(final LogEntry entry) {
    if (_logEntries.length < _maxPoolSize) {
      entry.reset();
      _logEntries.add(entry);
    }
  }

  /// Completely clears all object pools and reclaims all native memory.
  ///
  /// This is primarily used in benchmarks to ensure a clean state between
  /// different engine configurations.
  @internal
  void clear() {
    _documents.clear();
    _headers.clear();
    _messages.clear();
    _errors.clear();
    _footers.clear();
    _metadataNodes.clear();
    _boxes.clear();
    _indents.clear();
    _groups.clear();
    _decorated.clear();
    _paragraphs.clear();
    _rows.clear();
    _sections.clear();
    _fillers.clear();
    _maps.clear();
    _lists.clear();
    _alignments.clear();
    _tables.clear();
    _tableRows.clear();
    _tableCells.clear();
    _contexts.clear();
    _physicalLines.clear();
    _physicalDocuments.clear();
    _logEntries.clear();

    _dataMaps.clear();
    _nodeLists.clear();
    _segmentLists.clear();
    _dynamicLists.clear();
    _metadataSets.clear();

    if (_completionPort != null) {
      _completionPort!.close();
      _completionPort = null;
    }

    reclaimInFlightBuffers();
    for (final buffer in _freeNativeBuffers) {
      pkg_ffi.malloc.free(buffer.pointer);
    }
    _freeNativeBuffers.clear();
    _totalAllocatedBytes = 0;
  }

  /// Checks out a [HeaderNode] from the pool, or allocates a fresh one.
  @override
  HeaderNode checkoutHeader() =>
      _headers.isNotEmpty ? _headers.removeLast() : HeaderNode.pooled();

  /// Checks out a [MessageNode] from the pool, or allocates a fresh one.
  @override
  MessageNode checkoutMessage() =>
      _messages.isNotEmpty ? _messages.removeLast() : MessageNode.pooled();

  /// Checks out an [ErrorNode] from the pool, or allocates a fresh one.
  @override
  ErrorNode checkoutError() =>
      _errors.isNotEmpty ? _errors.removeLast() : ErrorNode.pooled();

  /// Checks out a [FooterNode] from the pool, or allocates a fresh one.
  @override
  FooterNode checkoutFooter() =>
      _footers.isNotEmpty ? _footers.removeLast() : FooterNode.pooled();

  /// Checks out a [MetadataNode] from the pool, or allocates a fresh one.
  @override
  MetadataNode checkoutMetadata() => _metadataNodes.isNotEmpty
      ? _metadataNodes.removeLast()
      : MetadataNode.pooled();

  /// Checks out a [BoxNode] from the pool, or allocates a fresh one.
  @override
  BoxNode checkoutBox() =>
      _boxes.isNotEmpty ? _boxes.removeLast() : BoxNode.pooled();

  /// Checks out an [IndentationNode] from the pool, or allocates a fresh one.
  @override
  IndentationNode checkoutIndentation() =>
      _indents.isNotEmpty ? _indents.removeLast() : IndentationNode.pooled();

  /// Checks out a [GroupNode] from the pool, or allocates a fresh one.
  @override
  GroupNode checkoutGroup() =>
      _groups.isNotEmpty ? _groups.removeLast() : GroupNode.pooled();

  /// Checks out a [DecoratedNode] from the pool, or allocates a fresh one.
  @override
  DecoratedNode checkoutDecorated() =>
      _decorated.isNotEmpty ? _decorated.removeLast() : DecoratedNode.pooled();

  /// Checks out a [ParagraphNode] from the pool, or allocates a fresh one.
  @override
  ParagraphNode checkoutParagraph() => _paragraphs.isNotEmpty
      ? _paragraphs.removeLast()
      : ParagraphNode.pooled();

  /// Checks out a [RowNode] from the pool, or allocates a fresh one.
  @override
  RowNode checkoutRow() =>
      _rows.isNotEmpty ? _rows.removeLast() : RowNode.pooled();

  /// Checks out a [SectionNode] from the pool, or allocates a fresh one.
  @override
  SectionNode checkoutSection() =>
      _sections.isNotEmpty ? _sections.removeLast() : SectionNode.pooled();

  /// Checks out a [FillerNode] from the pool, or allocates a fresh one.
  @override
  FillerNode checkoutFiller() =>
      _fillers.isNotEmpty ? _fillers.removeLast() : FillerNode.pooled();

  /// Checks out a [MapNode] from the pool, or allocates a fresh one.
  @override
  MapNode checkoutMap() =>
      _maps.isNotEmpty ? _maps.removeLast() : MapNode.pooled();

  /// Checks out a [ListNode] from the pool, or allocates a fresh one.
  @override
  ListNode checkoutList() =>
      _lists.isNotEmpty ? _lists.removeLast() : ListNode.pooled();

  @override
  AlignmentNode checkoutAlignment() => _alignments.isNotEmpty
      ? _alignments.removeLast()
      : AlignmentNode.pooled();

  @override
  TableNode checkoutTable() =>
      _tables.isNotEmpty ? _tables.removeLast() : TableNode.pooled();

  @override
  TableRowNode checkoutTableRow() =>
      _tableRows.isNotEmpty ? _tableRows.removeLast() : TableRowNode.pooled();

  @override
  TableCellNode checkoutTableCell() => _tableCells.isNotEmpty
      ? _tableCells.removeLast()
      : TableCellNode.pooled();

  /// Checks out a [HandlerContext] from the pool, or allocates a fresh one.
  @override
  HandlerContext checkoutContext() =>
      _contexts.isNotEmpty ? _contexts.removeLast() : HandlerContext.pooled();

  /// Checks out a [PhysicalLine] from the pool, or allocates a fresh one.
  @override
  PhysicalLine checkoutPhysicalLine() => _physicalLines.isNotEmpty
      ? _physicalLines.removeLast()
      : PhysicalLine.pooled();

  /// Checks out a [PhysicalDocument] from the pool, or allocates a fresh one.
  @override
  PhysicalDocument checkoutPhysicalDocument() => _physicalDocuments.isNotEmpty
      ? _physicalDocuments.removeLast()
      : PhysicalDocument.pooled();

  @override
  Map<K, V> checkoutDataMap<K, V>() {
    if (K == String && V == _typeOf<Object?>() && _dataMaps.isNotEmpty) {
      return _dataMaps.removeLast() as Map<K, V>;
    }
    return <K, V>{};
  }

  @override
  List<T> checkoutDataList<T>() {
    if (T == LogNode && _nodeLists.isNotEmpty) {
      return _nodeLists.removeLast() as List<T>;
    }
    if (T == StyledText && _segmentLists.isNotEmpty) {
      return _segmentLists.removeLast() as List<T>;
    }
    if (_dynamicLists.isNotEmpty) {
      return _dynamicLists.removeLast().cast<T>();
    }
    return <T>[];
  }

  @override
  Set<T> checkoutDataSet<T>() {
    if (T == LogMetadata && _metadataSets.isNotEmpty) {
      return _metadataSets.removeLast() as Set<T>;
    }
    return <T>{};
  }

  // ---------------------------------------------------------------------------
  // Release — reset and push back onto the pool.
  // ---------------------------------------------------------------------------

  /// Releases [obj] back to the pool after resetting its state.
  ///
  /// [obj] may be a [LogDocument] or any [LogNode] subclass.
  /// Prefer calling [LogDocument.releaseRecursive] to release an entire tree
  /// rather than releasing individual nodes manually.
  @override
  void release(final Object obj) {
    switch (obj) {
      case final LogDocument d:
        if (_documents.length < _maxPoolSize) {
          d.reset();
          _documents.add(d);
        }
        return;
      case final HeaderNode n:
        if (_headers.length < _maxPoolSize) {
          n.reset();
          _headers.add(n);
        }
        return;
      case final MessageNode n:
        if (_messages.length < _maxPoolSize) {
          n.reset();
          _messages.add(n);
        }
        return;
      case final ErrorNode n:
        if (_errors.length < _maxPoolSize) {
          n.reset();
          _errors.add(n);
        }
        return;
      case final FooterNode n:
        if (_footers.length < _maxPoolSize) {
          n.reset();
          _footers.add(n);
        }
        return;
      case final MetadataNode n:
        if (_metadataNodes.length < _maxPoolSize) {
          n.reset();
          _metadataNodes.add(n);
        }
        return;
      case final BoxNode n:
        if (_boxes.length < _maxPoolSize) {
          n.reset();
          _boxes.add(n);
        }
        return;
      case final IndentationNode n:
        if (_indents.length < _maxPoolSize) {
          n.reset();
          _indents.add(n);
        }
        return;
      case final GroupNode n:
        if (_groups.length < _maxPoolSize) {
          n.reset();
          _groups.add(n);
        }
        return;
      case final DecoratedNode n:
        if (_decorated.length < _maxPoolSize) {
          n.reset();
          _decorated.add(n);
        }
        return;
      case final ParagraphNode n:
        if (_paragraphs.length < _maxPoolSize) {
          n.reset();
          _paragraphs.add(n);
        }
        return;
      case final RowNode n:
        if (_rows.length < _maxPoolSize) {
          n.reset();
          _rows.add(n);
        }
        return;
      case final SectionNode n:
        if (_sections.length < _maxPoolSize) {
          n.reset();
          _sections.add(n);
        }
        return;
      case final FillerNode n:
        if (_fillers.length < _maxPoolSize) {
          n.reset();
          _fillers.add(n);
        }
        return;
      case final MapNode n:
        if (_maps.length < _maxPoolSize) {
          n.reset();
          _maps.add(n);
        }
        return;
      case final ListNode n:
        if (_lists.length < _maxPoolSize) {
          n.reset();
          _lists.add(n);
        }
        return;
      case final AlignmentNode n:
        if (_alignments.length < _maxPoolSize) {
          n.reset();
          _alignments.add(n);
        }
        return;
      case final TableNode n:
        if (_tables.length < _maxPoolSize) {
          n.reset();
          _tables.add(n);
        }
        return;
      case final TableRowNode n:
        if (_tableRows.length < _maxPoolSize) {
          n.reset();
          _tableRows.add(n);
        }
        return;
      case final TableCellNode n:
        if (_tableCells.length < _maxPoolSize) {
          n.reset();
          _tableCells.add(n);
        }
        return;
      case final HandlerContext c:
        if (_contexts.length < _maxPoolSize) {
          c.reset();
          _contexts.add(c);
        }
        return;
      case final PhysicalLine l:
        if (_physicalLines.length < _maxPoolSize) {
          l.reset();
          _physicalLines.add(l);
        }
        return;
      case final PhysicalDocument d:
        if (_physicalDocuments.length < _maxPoolSize) {
          d.reset();
          _physicalDocuments.add(d);
        }
        return;
      case final Map<String, Object?> m:
        if (m.runtimeType == _typeOf<Map<String, Object?>>()) {
          if (m is! UnmodifiableMapView && _dataMaps.length < _maxPoolSize) {
            m.clear();
            _dataMaps.add(m);
          }
        }
        return;
      case final List<StyledText> l:
        if (l.runtimeType == _typeOf<List<StyledText>>()) {
          if (l is! UnmodifiableListView &&
              _segmentLists.length < _maxPoolSize) {
            l.clear();
            _segmentLists.add(l);
          }
        }
        return;
      case final List<LogNode> l:
        if (l.runtimeType == _typeOf<List<LogNode>>()) {
          if (l is! UnmodifiableListView && _nodeLists.length < _maxPoolSize) {
            l.clear();
            _nodeLists.add(l);
          }
        }
        return;
      case final List l:
        if (l.runtimeType == _typeOf<List<dynamic>>()) {
          if (l is! UnmodifiableListView &&
              _dynamicLists.length < _maxPoolSize) {
            l.clear();
            _dynamicLists.add(l);
          }
        }
        return;
      case final Set<LogMetadata> s:
        if (s.runtimeType == _typeOf<Set<LogMetadata>>()) {
          if (_metadataSets.length < _maxPoolSize) {
            try {
              s.clear();
              _metadataSets.add(s);
            } catch (_) {}
          }
        }
        return;
    }
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  /// Returns the total number of objects currently cached across all pools.
  int get poolSize =>
      _documents.length +
      _headers.length +
      _messages.length +
      _errors.length +
      _footers.length +
      _metadataNodes.length +
      _boxes.length +
      _indents.length +
      _groups.length +
      _decorated.length +
      _paragraphs.length +
      _rows.length +
      _sections.length +
      _fillers.length +
      _maps.length +
      _lists.length +
      _alignments.length +
      _tables.length +
      _tableRows.length +
      _tableCells.length +
      _contexts.length +
      _physicalLines.length +
      _physicalDocuments.length;

  /// Frees all native memory. Should only be called on isolate shutdown.
  void disposeNative() {
    if (_completionPort != null) {
      _completionPort!.close();
      _completionPort = null;
    }

    for (final buffer in _freeNativeBuffers) {
      pkg_ffi.malloc.free(buffer.pointer);
    }
    _freeNativeBuffers.clear();

    for (final buffer in _inFlightNativeBuffers.values) {
      pkg_ffi.malloc.free(buffer.pointer);
    }
    _inFlightNativeBuffers.clear();
    _totalAllocatedBytes = 0;
  }
}

class _NativeBuffer {
  _NativeBuffer(this.pointer, this.size);
  final ffi.Pointer<ffi.Uint8> pointer;
  final int size;
  int offset = 0;
}

/// A specialized [LogDocument] for use within an [Arena].
///
/// [ArenaDocument] supports a **Hybrid Execution Mode**:
/// 1. **Streaming Mode**: Writes directly to the native Binary IR buffer.
///    This mode provides maximum performance (20x boost) but bypasses
///    structural decorators that rely on tree traversal.
/// 2. **Object Mode**: Behaves like a [StandardDocument], creating poolable
///    nodes. This mode is used when decorators are present.
class ArenaDocument extends StandardDocument {
  ArenaDocument(this.arena) : super.pooled();

  /// The arena that owns this document.
  final Arena arena;

  /// The writer used for streaming Binary IR.
  late final BinaryIRWriter writer = BinaryIRWriter(this);

  final List<_NativeBuffer> _buffers = [];
  _NativeBuffer? _currentBuffer;
  bool _isStreaming = false;

  /// Returns whether this document is currently in streaming mode.
  bool get isStreaming => _isStreaming;

  /// Returns the base pointer of the current active native buffer,
  /// or null if unallocated.
  @internal
  ffi.Pointer<ffi.Uint8>? get nativeBufferPointer => _currentBuffer?.pointer;

  /// Returns the byte offset of the current active native buffer.
  @internal
  int get nativeBufferOffset => _currentBuffer?.offset ?? 0;

  /// Enables high-performance streaming mode.
  void enableStreaming() {
    _isStreaming = true;
    writer
      ..start()
      ..writeDocumentMetadata(metadata);
  }

  @override
  void reset() {
    super.reset();
    writer.reset();
    if (_buffers.isNotEmpty) {
      arena.resetNative(this);
    }
    _isStreaming = false;
  }

  @override
  void text(
    final String text, {
    final LogStyle? style,
    final int tags = LogTag.none,
    final LogPipelineFactory? factory,
  }) {
    if (_isStreaming) {
      writer.writeText(text, style: style, tags: tags);
    } else {
      super.text(text, style: style, tags: tags, factory: factory ?? arena);
    }
  }

  @override
  void startBox({
    final BoxBorderStyle border = BoxBorderStyle.rounded,
    final int tags = LogTag.none,
    final LogPipelineFactory? factory,
  }) {
    if (_isStreaming) {
      writer.writeBoxStart(border: border, tags: tags);
    } else {
      super.startBox(border: border, tags: tags, factory: factory ?? arena);
    }
  }

  @override
  void styledText(final StyledText text, {final LogPipelineFactory? factory}) {
    if (_isStreaming) {
      writer.writeText(text.text, style: text.style, tags: text.tags);
    } else {
      super.styledText(text, factory: factory ?? arena);
    }
  }

  @override
  void newline() {
    if (_isStreaming) {
      writer.writeNewline();
    } else {
      super.newline();
    }
  }

  @override
  void endBox() {
    if (_isStreaming) {
      writer.writeBoxEnd();
    } else {
      super.endBox();
    }
  }

  @override
  void startIndent(
    final String indent, {
    final LogStyle? style,
    final int tags = LogTag.none,
    final LogPipelineFactory? factory,
  }) {
    if (_isStreaming) {
      writer.writeIndentStart(indent, style: style, tags: tags);
    } else {
      super.startIndent(
        indent,
        style: style,
        tags: tags,
        factory: factory ?? arena,
      );
    }
  }

  @override
  void endIndent() {
    if (_isStreaming) {
      writer.writeIndentEnd();
    } else {
      super.endIndent();
    }
  }

  @override
  void metadataBlock(
    final Map<String, Object?> data, {
    final int tags = LogTag.none,
    final LogPipelineFactory? factory,
  }) {
    if (_isStreaming) {
      writer.writeMap(data, tags: tags);
    } else {
      super.metadataBlock(data, tags: tags, factory: factory ?? arena);
    }
  }

  @override
  void startAlignment(
    final LogAlignment alignment, {
    final LogPipelineFactory? factory,
  }) {
    if (_isStreaming) {
      writer.writeAlignmentStart(alignment);
    } else {
      super.startAlignment(alignment, factory: factory ?? arena);
    }
  }

  @override
  void endAlignment() {
    if (_isStreaming) {
      writer.writeAlignmentEnd();
    } else {
      super.endAlignment();
    }
  }

  @override
  void startTable({
    final List<int>? columnWidths,
    final LogPipelineFactory? factory,
  }) {
    if (_isStreaming) {
      writer.writeTableStart(columnWidths: columnWidths);
    } else {
      super.startTable(columnWidths: columnWidths, factory: factory ?? arena);
    }
  }

  @override
  void endTable() {
    if (_isStreaming) {
      writer.writeTableEnd();
    } else {
      super.endTable();
    }
  }

  @override
  void startRow({final LogPipelineFactory? factory}) {
    if (_isStreaming) {
      writer.writeRowStart();
    } else {
      super.startRow(factory: factory ?? arena);
    }
  }

  @override
  void endRow() {
    if (_isStreaming) {
      writer.writeRowEnd();
    } else {
      super.endRow();
    }
  }

  @override
  void startCell({
    final int colspan = 1,
    final int rowspan = 1,
    final LogPipelineFactory? factory,
  }) {
    if (_isStreaming) {
      writer.writeCellStart(columnSpan: colspan, rowSpan: rowspan);
    } else {
      super.startCell(
        colspan: colspan,
        rowspan: rowspan,
        factory: factory ?? arena,
      );
    }
  }

  @override
  void endCell() {
    if (_isStreaming) {
      writer.writeCellEnd();
    } else {
      super.endCell();
    }
  }

  @override
  void startDecorated({
    required final List<StyledText> leading,
    final int leadingWidth = 0,
    final String? leadingHint,
    final LogPipelineFactory? factory,
  }) {
    if (_isStreaming) {
      writer.writeDecoratedStart(
        leading: leading,
        leadingWidth: leadingWidth,
        leadingHint: leadingHint,
      );
    } else {
      super.startDecorated(
        leading: leading,
        leadingWidth: leadingWidth,
        leadingHint: leadingHint,
        factory: factory ?? arena,
      );
    }
  }

  @override
  void endDecorated() {
    if (_isStreaming) {
      writer.writeDecoratedEnd();
    } else {
      super.endDecorated();
    }
  }

  @override
  void filler({
    required final String char,
    final int tags = LogTag.none,
    final LogPipelineFactory? factory,
  }) {
    if (_isStreaming) {
      writer.writeFiller(char: char, tags: tags);
    } else {
      super.filler(char: char, tags: tags, factory: factory ?? arena);
    }
  }

  @override
  void writeNode(final LogNode node) {
    if (_isStreaming) {
      writer.writeNode(node);
    } else {
      super.writeNode(node);
    }
  }
}

Type _typeOf<T>() => T;
