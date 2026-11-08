library;

import 'package:meta/meta.dart';
import '../../logger/logger.dart';

part 'context_filter.dart';
part 'level_filter.dart';
part 'regex_filter.dart';

/// Abstract base for filtering log entries before processing.
//ignore: one_member_abstracts
@immutable
abstract class LogFilter {
  const LogFilter();

  /// Returns true if the entry should be logged, false to drop it.
  bool shouldLog(final LogEntry entry);
}
