part of 'filter.dart';

/// Filters entries below a minimum level.
@immutable
class LevelFilter implements LogFilter {
  const LevelFilter(this.minimumLevel);

  /// The minimum level to allow (inclusive).
  final LogLevel minimumLevel;

  @override
  bool shouldLog(final LogEntry entry) =>
      entry.level.index >= minimumLevel.index;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is LevelFilter &&
          runtimeType == other.runtimeType &&
          minimumLevel == other.minimumLevel;

  @override
  int get hashCode => minimumLevel.hashCode;
}
