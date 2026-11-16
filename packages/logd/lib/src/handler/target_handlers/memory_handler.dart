library;

import 'package:meta/meta.dart';

import '../../logger/log_entry.dart';
import '../handler.dart';

/// A pre-wired [Handler] that retains recent log entries in memory.
///
/// Uses [StructuredFormatter] and a [MemorySink]. Retained entries can be
/// accessed directly via [entries].
@immutable
class MemoryHandler extends Handler {
  /// Creates a [MemoryHandler].
  MemoryHandler({
    final int capacity = 200,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
          formatter: formatter ?? const StructuredFormatter(),
          sink: MemorySink(capacity: capacity),
          decorators: decorators ?? const [],
        );

  /// Unmodifiable view of currently retained entries in [MemorySink].
  List<LogEntry> get entries => (sink as MemorySink).entries;

  /// Empties all retained log entries.
  void clear() => (sink as MemorySink).clear();
}
