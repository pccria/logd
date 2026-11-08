// Example: Advanced Filtering
//
// Demonstrates:
// - Complex filter combinations
// - Regex patterns
// - Level filtering
// - Multiple filters (AND behavior)
//
// Expected: Only matching logs are processed

import 'package:logd/logd.dart';

/// Custom LogFilter to demonstrate filtering by loggerName.
class LoggerNameFilter implements LogFilter {
  const LoggerNameFilter(this.regex);
  final RegExp regex;

  @override
  bool shouldLog(final LogEntry entry) => regex.hasMatch(entry.loggerName);
}

void main() async {
  // Filter by logger name pattern using a custom LogFilter
  final nameFilter = Handler(
    formatter: const PlainFormatter(),
    sink: const ConsoleSink(),
    filters: [
      LoggerNameFilter(RegExp(r'^example\.(auth|user)')),
    ],
  );

  // Filter by message content and level
  final contentLevelFilter = Handler(
    formatter: const PlainFormatter(),
    sink: const ConsoleSink(),
    filters: [
      const LevelFilter(LogLevel.warning),
      RegexFilter(RegExp('error|fail|critical', caseSensitive: false)),
    ],
  );

  // Inverted filter (exclude pattern)
  final excludeFilter = Handler(
    formatter: const PlainFormatter(),
    sink: const ConsoleSink(),
    filters: [
      RegexFilter(
        RegExp('password|secret|token'),
        invert: true, // Exclude if matches
      ),
    ],
  );

  Logger.configure('example.auth', handlers: [nameFilter]);
  Logger.configure('example.user', handlers: [nameFilter]);
  Logger.configure('example.db', handlers: [nameFilter]);
  Logger.configure('example.filtered', handlers: [contentLevelFilter]);
  Logger.configure('example.exclude', handlers: [excludeFilter]);

  final authLogger = Logger.get('example.auth');
  final userLogger = Logger.get('example.user');
  final dbLogger = Logger.get('example.db');
  final filteredLogger = Logger.get('example.filtered');
  final excludeLogger = Logger.get('example.exclude');

  print('=== Name Filter (auth|user only) ===');
  authLogger.info('Auth message - should appear');
  userLogger.info('User message - should appear');
  dbLogger.info('DB message - should NOT appear');

  print('\n=== Content + Level Filter ===');
  filteredLogger
    ..info('Info message - should NOT appear')
    ..warning('Warning message - should NOT appear (no match)')
    ..warning('Warning with ERROR - should appear')
    ..error('Error message - should appear');

  print('\n=== Exclude Filter (no secrets) ===');
  excludeLogger
    ..info('Normal message - should appear')
    ..info('Message with password - should NOT appear')
    ..info('Message with secret - should NOT appear')
    ..info('Message with token - should NOT appear')
    ..info('Safe message - should appear');
}
