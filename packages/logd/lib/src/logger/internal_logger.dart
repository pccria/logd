library;

import '../core/log_level.dart';

/// Fail-safe diagnostic logger for the logd framework, engines, and sinks.
///
/// Bypasses the standard logd pipeline and outputs directly to the platform's
/// console stream with a `[logd-internal]` prefix to guarantee zero
/// circularity or re-entrant logging during pipeline or sink failures.
class InternalLogger {
  const InternalLogger._();

  /// Logs a message directly to console.
  static void log(
    final LogLevel level,
    final String message, {
    final Object? error,
    final StackTrace? stackTrace,
  }) {
    print('[logd-internal] [${level.name.toUpperCase()}]: $message');
    if (error != null) {
      print('[logd-internal] [Error]: $error');
    }
    if (stackTrace != null) {
      print('[logd-internal] [Stack Trace]:\n$stackTrace');
    }
  }
}
