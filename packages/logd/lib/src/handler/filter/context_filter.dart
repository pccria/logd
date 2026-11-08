part of 'filter.dart';

/// A [LogFilter] that filters log entries based on their structured context.
@immutable
class ContextFilter implements LogFilter {
  /// Creates a [ContextFilter].
  ///
  /// - [key]: The context key to check.
  /// - [value]: Optional value to match. If null, the filter matches if the
  ///   key exists.
  /// - [exclude]: If true, matching entries are excluded (dropped).
  ///   Defaults to false.
  const ContextFilter(
    this.key, {
    this.value,
    this.exclude = false,
  });

  /// The context key to filter by.
  final String key;

  /// The context value to match (optional).
  final dynamic value;

  /// Whether to exclude matching entries instead of including them.
  final bool exclude;

  @override
  bool shouldLog(final LogEntry entry) {
    final context = entry.context;
    final exists = context != null && context.containsKey(key);
    final matches = exists && (value == null || context[key] == value);

    return exclude ? !matches : matches;
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ContextFilter &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          exclude == other.exclude;

  @override
  int get hashCode => Object.hash(key, value, exclude);
}
