library;

import 'package:meta/meta.dart';
import '../core/log_level.dart';
import '../stack_trace/stack_trace.dart';

const String _globalLoggerName = 'global';

/// Structured representation of a log event passed to handlers.
///
/// Single source of truth for all log data. Handlers receive
/// this object and decide how to format and where to output.
class LogEntry {
  LogEntry({
    required this.loggerName,
    required this.origin,
    required this.level,
    required this.message,
    required this.timestamp,
    this.stackFrames,
    this.error,
    this.stackTrace,
    this.context,
  });

  @internal
  LogEntry.pooled()
      : loggerName = '',
        origin = '',
        level = LogLevel.debug,
        message = '',
        timestamp = '';

  /// Name of the logger that created this entry.
  String loggerName;

  /// Caller origin string (e.g., 'Class.method').
  String origin;

  /// Log severity level.
  LogLevel level;

  /// Log message content.
  String message;

  /// Formatted timestamp.
  String timestamp;

  /// Cached hierarchy depth. Dot-counting instead of split() avoids allocation.
  int? _hierarchyDepthCache;

  /// Hierarchy depth calculated from [loggerName].
  ///
  /// 'global' -> 0
  /// 'a' -> 1
  /// 'a.b' -> 2
  @pragma('vm:prefer-inline')
  int get hierarchyDepth {
    if (_hierarchyDepthCache != null) {
      return _hierarchyDepthCache!;
    }
    if (loggerName == _globalLoggerName || loggerName.isEmpty) {
      return _hierarchyDepthCache = 0;
    }
    int count = 1;
    final len = loggerName.length;
    for (int i = 0; i < len; i++) {
      if (loggerName.codeUnitAt(i) == 46) {
        count++;
      }
    }
    return _hierarchyDepthCache = count;
  }

  /// Parsed stack frames if included.
  List<CallbackInfo>? stackFrames;

  /// Associated error object.
  Object? error;

  /// Full stack trace.
  StackTrace? stackTrace;

  /// Structured context map.
  Map<String, dynamic>? context;

  /// Resets the entry for reuse in the pool.
  @pragma('vm:prefer-inline')
  void reset() {
    loggerName = '';
    origin = '';
    level = LogLevel.debug;
    message = '';
    timestamp = '';
    stackFrames = null;
    error = null;
    stackTrace = null;
    context = null;
    _hierarchyDepthCache = null;
  }

  /// Creates an independent clone of this [LogEntry] detached from any object
  /// pool.
  LogEntry clone() => LogEntry(
        loggerName: loggerName,
        origin: origin,
        level: level,
        message: message,
        timestamp: timestamp,
        stackFrames:
            stackFrames != null ? List<CallbackInfo>.of(stackFrames!) : null,
        error: error,
        stackTrace: stackTrace,
        context: context != null ? Map<String, dynamic>.from(context!) : null,
      ).._hierarchyDepthCache = _hierarchyDepthCache;

  /// Creates a copy of this entry with optional overrides.
  /// Note: copyWith does not preserve the cached hierarchy depth,
  /// as the new instance will recompute it on first access.
  LogEntry copyWith({
    final String? loggerName,
    final String? origin,
    final LogLevel? level,
    final String? message,
    final String? timestamp,
    final List<CallbackInfo>? stackFrames,
    final Object? error,
    final StackTrace? stackTrace,
    final Map<String, dynamic>? context,
  }) =>
      LogEntry(
        loggerName: loggerName ?? this.loggerName,
        origin: origin ?? this.origin,
        level: level ?? this.level,
        message: message ?? this.message,
        timestamp: timestamp ?? this.timestamp,
        stackFrames: stackFrames ?? this.stackFrames,
        error: error ?? this.error,
        stackTrace: stackTrace ?? this.stackTrace,
        context: context ?? this.context,
      );

  @override
  String toString() => '[$level] (depth $hierarchyDepth) $origin: $message';
}
