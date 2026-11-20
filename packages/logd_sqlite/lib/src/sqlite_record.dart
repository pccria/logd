// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'dart:convert' as convert;

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

/// A strongly-typed representation of a persisted log record in SQLite.
///
/// Features typed field accessors ([level], [createdAtDateTime], [context]),
/// full text search metadata ([snippet], [rank]), and backward-compatible map
/// indexing via [operator []].
@immutable
final class SqliteLogRecord {
  /// Creates a [SqliteLogRecord].
  const SqliteLogRecord({
    required this.id,
    required this.timestamp,
    required this.levelIndex,
    required this.levelName,
    required this.loggerName,
    required this.origin,
    required this.message,
    required this.createdAt,
    this.error,
    this.stackTrace,
    this.contextJson,
    this.snippet,
    this.rank,
  });

  /// Constructs a [SqliteLogRecord] from a raw SQLite row map.
  factory SqliteLogRecord.fromRow(final Map<String, dynamic> row) =>
      SqliteLogRecord(
        id: row['id'] as int,
        timestamp: row['timestamp'] as String,
        levelIndex: row['level'] as int,
        levelName: row['level_name'] as String,
        loggerName: row['logger_name'] as String,
        origin: row['origin'] as String,
        message: row['message'] as String,
        createdAt: row['created_at'] as int,
        error: row['error'] as String?,
        stackTrace: row['stack_trace'] as String?,
        contextJson: row['context_json'] as String?,
        snippet: row['snippet'] as String?,
        rank: (row['rank'] as num?)?.toDouble(),
      );

  /// Primary database autoincrement ID.
  final int id;

  /// ISO 8601 formatted timestamp string recorded at log creation.
  final String timestamp;

  /// Raw integer index representing the log severity level in SQLite.
  final int levelIndex;

  /// String name of the log severity level (e.g. `'info'`, `'error'`).
  final String levelName;

  /// Hierarchical logger identifier (e.g. `'app.payment.gateway'`).
  final String loggerName;

  /// Call site origin string (e.g. `'PaymentService.process'`).
  final String origin;

  /// Formatted or raw message content.
  final String message;

  /// Milliseconds since Unix epoch when the record was persisted.
  final int createdAt;

  /// Serialized error object or message, if any.
  final String? error;

  /// Serialized stack trace, if any.
  final String? stackTrace;

  /// Serialized JSON context string, if any.
  final String? contextJson;

  /// Highlighted match snippet when returned by an FTS5 query.
  final String? snippet;

  /// BM25 relevance score when returned by an FTS5 query.
  final double? rank;

  /// Typed [LogLevel] derived from [levelIndex].
  LogLevel get level => (levelIndex >= 0 && levelIndex < LogLevel.values.length)
      ? LogLevel.values[levelIndex]
      : LogLevel.info;

  /// [DateTime] representation of [createdAt].
  DateTime get createdAtDateTime =>
      DateTime.fromMillisecondsSinceEpoch(createdAt);

  /// Parsed JSON context map, or `null` if no context was attached or invalid.
  Map<String, dynamic>? get context {
    if (contextJson == null || contextJson!.isEmpty) {
      return null;
    }
    try {
      return convert.jsonDecode(contextJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Backward-compatible map accessor.
  ///
  /// Returns the exact types stored in SQLite rows:
  /// - `['id']` -> [int]
  /// - `['timestamp']` -> [String]
  /// - `['level']` -> [int] (the integer ordinal, matching legacy queries)
  /// - `['level_name']` -> [String]
  /// - `['logger_name']` -> [String]
  /// - `['origin']` -> [String]
  /// - `['message']` -> [String]
  /// - `['error']` -> [String]?
  /// - `['stack_trace']` -> [String]?
  /// - `['context_json']` -> [String]?
  /// - `['created_at']` -> [int]
  /// - `['snippet']` -> [String]?
  /// - `['rank']` -> [double]?
  Object? operator [](final String key) => switch (key) {
    'id' => id,
    'timestamp' => timestamp,
    'level' => levelIndex,
    'level_name' => levelName,
    'logger_name' => loggerName,
    'origin' => origin,
    'message' => message,
    'error' => error,
    'stack_trace' => stackTrace,
    'context_json' => contextJson,
    'created_at' => createdAt,
    'snippet' => snippet,
    'rank' => rank,
    _ => null,
  };

  /// Converts this record to a map with column-name keys.
  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp,
    'level': levelIndex,
    'level_name': levelName,
    'logger_name': loggerName,
    'origin': origin,
    'message': message,
    'error': error,
    'stack_trace': stackTrace,
    'context_json': contextJson,
    'created_at': createdAt,
    if (snippet != null) 'snippet': snippet,
    if (rank != null) 'rank': rank,
  };

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is SqliteLogRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          timestamp == other.timestamp &&
          levelIndex == other.levelIndex &&
          levelName == other.levelName &&
          loggerName == other.loggerName &&
          origin == other.origin &&
          message == other.message &&
          createdAt == other.createdAt &&
          error == other.error &&
          stackTrace == other.stackTrace &&
          contextJson == other.contextJson &&
          snippet == other.snippet &&
          rank == other.rank;

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    levelIndex,
    levelName,
    loggerName,
    origin,
    message,
    createdAt,
    error,
    stackTrace,
    contextJson,
    snippet,
    rank,
  );

  @override
  String toString() =>
      'SqliteLogRecord(id: $id, level: $levelName, logger: $loggerName, '
      'message: $message, createdAt: $createdAt)';
}
