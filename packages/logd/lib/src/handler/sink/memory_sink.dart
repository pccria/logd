part of 'sink.dart';

/// An in-memory, fixed-capacity ring-buffer [LogSink] that retains recent
/// [LogEntry] events in memory.
///
/// This sink is particularly useful for in-app debug panels, bug reporting
/// screens, and programmatically inspecting recent log entries in tests.
///
/// Excess entries beyond [capacity] are automatically dropped on a FIFO basis.
@experimental
@immutable
base class MemorySink extends LogSink<LogDocument> {
  /// Creates a [MemorySink] with the given [capacity].
  ///
  /// - [capacity]: Maximum number of entries retained in memory (default: 200).
  /// - [enabled]: Whether the sink is currently active.
  MemorySink({
    this.capacity = 200,
    super.enabled,
  }) : _entries = Queue<LogEntry>() {
    if (capacity <= 0) {
      throw ArgumentError.value(
        capacity,
        'capacity',
        'Capacity must be greater than zero.',
      );
    }
  }

  /// Maximum number of log entries to retain.
  final int capacity;

  /// Internal queue holding retained log entries.
  final Queue<LogEntry> _entries;

  /// Unmodifiable view of the currently retained log entries.
  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    if (!enabled) {
      return;
    }

    if (_entries.length >= capacity) {
      _entries.removeFirst();
    }
    _entries.add(entry.copyWith());
  }

  /// Empties all retained log entries.
  void clear() {
    _entries.clear();
  }

  @override
  bool operator ==(final Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}
