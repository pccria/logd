// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'sqlite_record.dart';
import 'sqlite_sink.dart';

/// Supported sort fields for querying SQLite log records.
enum SqliteSortField {
  /// Sort by the autoincrement primary key ID.
  id,

  /// Sort by the millisecond creation timestamp.
  createdAt,

  /// Sort by the integer severity level index.
  level,

  /// Sort by FTS5 BM25 match relevance score.
  rank,
}

/// Sort direction for query results.
enum SqliteSortOrder {
  /// Ascending order (lowest/oldest first).
  ascending,

  /// Descending order (highest/newest first).
  descending,
}

/// A composable, type-safe query builder for retrieving log records from
/// SQLite.
///
/// Can be obtained via [SqliteSink.query] or instantiated directly and passed
/// to [SqliteSink.execute]:
/// ```dart
/// final records = sink.query()
///   .minLevel(LogLevel.warning)
///   .logger('app.payment', hierarchy: true)
///   .whereContext('userId', 'usr_1024')
///   .search('checkout timeout')
///   .afterId(500)
///   .limit(25)
///   .execute();
/// ```
@immutable
final class SqliteLogQuery {
  /// Creates a standalone [SqliteLogQuery].
  const SqliteLogQuery({
    this.minimumLevel,
    this.maximumLevel,
    this.levels,
    this.loggerName,
    this.loggerHierarchy = false,
    this.contextFilters = const {},
    this.searchTerm,
    this.rawMatch,
    this.start,
    this.end,
    this.afterCursorId,
    this.beforeCursorId,
    this.limitCount = 100,
    this.offsetCount = 0,
    this.sortField = SqliteSortField.id,
    this.sortOrder = SqliteSortOrder.descending,
  }) : _sink = null;

  /// Internal constructor with bound [SqliteSink].
  const SqliteLogQuery.bound(
    final SqliteSink sink, {
    this.minimumLevel,
    this.maximumLevel,
    this.levels,
    this.loggerName,
    this.loggerHierarchy = false,
    this.contextFilters = const {},
    this.searchTerm,
    this.rawMatch,
    this.start,
    this.end,
    this.afterCursorId,
    this.beforeCursorId,
    this.limitCount = 100,
    this.offsetCount = 0,
    this.sortField = SqliteSortField.id,
    this.sortOrder = SqliteSortOrder.descending,
  }) : _sink = sink;

  final SqliteSink? _sink;

  /// Minimum severity level (inclusive).
  final LogLevel? minimumLevel;

  /// Maximum severity level (inclusive).
  final LogLevel? maximumLevel;

  /// Specific set of [LogLevel]s to match.
  final Set<LogLevel>? levels;

  /// Logger namespace to filter by.
  final String? loggerName;

  /// When `true`, matches [loggerName] and all child namespaces
  /// (e.g. `'app.*'`).
  final bool loggerHierarchy;

  /// Structured JSON context path-to-value constraints.
  final Map<String, dynamic> contextFilters;

  /// Search keyword or phrase. When FTS5 is active, escaped automatically.
  final String? searchTerm;

  /// Raw FTS5 MATCH expression passed verbatim to the virtual table.
  final String? rawMatch;

  /// Lower bound creation timestamp (inclusive).
  final DateTime? start;

  /// Upper bound creation timestamp (inclusive).
  final DateTime? end;

  /// Cursor pagination: returns records older than [afterCursorId] in
  /// descending order, or newer than [afterCursorId] in ascending order.
  final int? afterCursorId;

  /// Cursor pagination: returns records newer than [beforeCursorId] in
  /// descending order, or older than [beforeCursorId] in ascending order.
  final int? beforeCursorId;

  /// Maximum number of records to return.
  final int limitCount;

  /// Number of records to skip (legacy pagination).
  final int offsetCount;

  /// Column to sort results by.
  final SqliteSortField sortField;

  /// Direction of sort.
  final SqliteSortOrder sortOrder;

  /// Filters logs to those at or above [level].
  SqliteLogQuery minLevel(final LogLevel level) =>
      _copyWith(minimumLevel: level);

  /// Alias for [minLevel].
  SqliteLogQuery minimum(final LogLevel level) => minLevel(level);

  /// Filters logs to those at or below [level].
  SqliteLogQuery maxLevel(final LogLevel level) =>
      _copyWith(maximumLevel: level);

  /// Alias for [maxLevel].
  SqliteLogQuery maximum(final LogLevel level) => maxLevel(level);

  /// Filters logs strictly matching the specified [level].
  SqliteLogQuery level(final LogLevel level) =>
      _copyWith(levels: {level}, minimumLevel: null, maximumLevel: null);

  /// Filters logs to those matching any of the specified [levels].
  SqliteLogQuery levelsFilter(final Iterable<LogLevel> levels) =>
      _copyWith(levels: levels.toSet(), minimumLevel: null, maximumLevel: null);

  /// Filters logs by [loggerName], optionally including child hierarchy.
  SqliteLogQuery logger(final String name, {final bool hierarchy = false}) =>
      _copyWith(loggerName: name, loggerHierarchy: hierarchy);

  /// Constrains results by a key-value pair in [LogEntry.context].
  ///
  /// Uses SQLite's native `json_extract(context_json, '$.path')`.
  SqliteLogQuery whereContext(final String key, final dynamic value) {
    final updated = Map<String, dynamic>.from(contextFilters)..[key] = value;
    return _copyWith(contextFilters: updated);
  }

  /// Searches messages, errors, and context strings.
  ///
  /// Automatically escapes special characters for FTS5 when available,
  /// or performs substring matching (`LIKE '%term%'`) as fallback.
  SqliteLogQuery search(final String term) => _copyWith(searchTerm: term);

  /// Performs raw FTS5 query matching using the full FTS5 expression syntax
  /// (e.g. `'auth AND NOT logout'`, `'phrase match *'`).
  SqliteLogQuery match(final String fts5Expression) =>
      _copyWith(rawMatch: fts5Expression);

  /// Filters logs recorded at or after [startTime].
  SqliteLogQuery after(final DateTime startTime) => _copyWith(start: startTime);

  /// Filters logs recorded at or before [endTime].
  SqliteLogQuery before(final DateTime endTime) => _copyWith(end: endTime);

  /// Filters logs within the range `[startTime, endTime]`.
  SqliteLogQuery timeRange(final DateTime startTime, final DateTime endTime) =>
      _copyWith(start: startTime, end: endTime);

  /// Keyset cursor: fetches records sequentially after [id].
  SqliteLogQuery afterId(final int id) => _copyWith(afterCursorId: id);

  /// Keyset cursor: fetches records sequentially before [id].
  SqliteLogQuery beforeId(final int id) => _copyWith(beforeCursorId: id);

  /// Limits the number of results returned.
  SqliteLogQuery limit(final int count) => _copyWith(limitCount: count);

  /// Skips [count] records (prefer [afterId] for large tables).
  SqliteLogQuery offset(final int count) => _copyWith(offsetCount: count);

  /// Specifies the sort column and direction.
  SqliteLogQuery orderBy(
    final SqliteSortField field, [
    final SqliteSortOrder order = SqliteSortOrder.descending,
  ]) => _copyWith(sortField: field, sortOrder: order);

  SqliteSink _resolveSink(final SqliteSink? sink) {
    final target = sink ?? _sink;
    if (target == null) {
      throw StateError(
        'SqliteLogQuery requires a SqliteSink. Call query() on a SqliteSink '
        'or pass a sink to execute(sink).',
      );
    }
    return target;
  }

  /// Executes this query against [sink] (or the bound sink) and returns typed
  /// records.
  List<SqliteLogRecord> execute([final SqliteSink? sink]) =>
      _resolveSink(sink).execute(this);

  /// Executes this query and returns the first record, or `null` if none match.
  SqliteLogRecord? fetchFirst([final SqliteSink? sink]) {
    final records = limit(1).execute(sink);
    return records.isEmpty ? null : records.first;
  }

  /// Returns the total number of records matching this query's filters.
  int count([final SqliteSink? sink]) => _resolveSink(sink).countQuery(this);

  /// Deletes all records matching this query's filters.
  ///
  /// Returns the count of deleted records.
  int delete([final SqliteSink? sink]) => _resolveSink(sink).deleteQuery(this);

  SqliteLogQuery _copyWith({
    final LogLevel? minimumLevel,
    final LogLevel? maximumLevel,
    final Set<LogLevel>? levels,
    final String? loggerName,
    final bool? loggerHierarchy,
    final Map<String, dynamic>? contextFilters,
    final String? searchTerm,
    final String? rawMatch,
    final DateTime? start,
    final DateTime? end,
    final int? afterCursorId,
    final int? beforeCursorId,
    final int? limitCount,
    final int? offsetCount,
    final SqliteSortField? sortField,
    final SqliteSortOrder? sortOrder,
  }) {
    if (_sink != null) {
      return SqliteLogQuery.bound(
        _sink,
        minimumLevel: minimumLevel ?? this.minimumLevel,
        maximumLevel: maximumLevel ?? this.maximumLevel,
        levels: levels ?? this.levels,
        loggerName: loggerName ?? this.loggerName,
        loggerHierarchy: loggerHierarchy ?? this.loggerHierarchy,
        contextFilters: contextFilters ?? this.contextFilters,
        searchTerm: searchTerm ?? this.searchTerm,
        rawMatch: rawMatch ?? this.rawMatch,
        start: start ?? this.start,
        end: end ?? this.end,
        afterCursorId: afterCursorId ?? this.afterCursorId,
        beforeCursorId: beforeCursorId ?? this.beforeCursorId,
        limitCount: limitCount ?? this.limitCount,
        offsetCount: offsetCount ?? this.offsetCount,
        sortField: sortField ?? this.sortField,
        sortOrder: sortOrder ?? this.sortOrder,
      );
    }
    return SqliteLogQuery(
      minimumLevel: minimumLevel ?? this.minimumLevel,
      maximumLevel: maximumLevel ?? this.maximumLevel,
      levels: levels ?? this.levels,
      loggerName: loggerName ?? this.loggerName,
      loggerHierarchy: loggerHierarchy ?? this.loggerHierarchy,
      contextFilters: contextFilters ?? this.contextFilters,
      searchTerm: searchTerm ?? this.searchTerm,
      rawMatch: rawMatch ?? this.rawMatch,
      start: start ?? this.start,
      end: end ?? this.end,
      afterCursorId: afterCursorId ?? this.afterCursorId,
      beforeCursorId: beforeCursorId ?? this.beforeCursorId,
      limitCount: limitCount ?? this.limitCount,
      offsetCount: offsetCount ?? this.offsetCount,
      sortField: sortField ?? this.sortField,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
