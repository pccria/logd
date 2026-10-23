// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;

import 'package:logd/logd.dart';
import 'package:sqlite3/sqlite3.dart';

class _PendingSqliteLog {
  const _PendingSqliteLog({
    required this.timestamp,
    required this.level,
    required this.levelName,
    required this.loggerName,
    required this.origin,
    required this.message,
    required this.createdAt,
    this.error,
    this.stackTrace,
    this.contextJson,
  });

  final String timestamp;
  final int level;
  final String levelName;
  final String loggerName;
  final String origin;
  final String message;
  final String? error;
  final String? stackTrace;
  final String? contextJson;
  final int createdAt;
}

/// A high-performance [LogSink] that persists structured logs to SQLite.
///
/// Features pre-compiled prepared statements, Write-Ahead Logging (WAL),
/// batch transaction commits ([batchSize], [flushInterval]), full entry field
/// fidelity (origin, error, stackTrace, context), retention pruning, and a rich
/// query engine.
base class SqliteSink extends LogSink<LogDocument> {
  static final RegExp _validIdentifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

  static void _validateTableName(final String name) {
    if (!_validIdentifier.hasMatch(name)) {
      throw ArgumentError.value(
        name,
        'tableName',
        'Table name must be a valid SQLite identifier (letters, digits, '
            'underscores, starting with a letter or underscore).',
      );
    }
  }

  /// Creates a [SqliteSink].
  ///
  /// - [dbPath]: SQLite database filepath (or `:memory:` for testing).
  /// - [database]: Optional existing [Database] instance.
  /// - [tableName]: Custom table name (default: `'logs'`).
  /// - [maxEntries]: Maximum number of log records retained.
  /// - [maxAge]: Maximum age of log records retained.
  /// - [batchSize]: Number of log entries to buffer before committing to
  ///   disk.
  /// - [flushInterval]: Periodic timer interval to flush pending log
  ///   entries.
  /// - [walMode]: Whether to enable Write-Ahead Logging for high write
  ///   throughput.
  /// - [maxBufferSize]: Maximum capacity for the in-memory batch buffer to
  ///   prevent memory exhaustion under write backpressure.
  SqliteSink({
    this.dbPath = 'logs.db',
    final Database? database,
    this.tableName = 'logs',
    this.maxEntries = 10000,
    this.maxAge,
    this.batchSize = 50,
    this.flushInterval = const Duration(seconds: 2),
    this.walMode = true,
    this.maxBufferSize = 10000,
    super.enabled = true,
  })  : _db = database ?? sqlite3.open(dbPath),
        _batch = [] {
    _validateTableName(tableName);
    if (maxEntries != null && maxEntries! <= 0) {
      throw ArgumentError.value(
        maxEntries,
        'maxEntries',
        'maxEntries must be positive if specified.',
      );
    }
    if (maxBufferSize <= 0) {
      throw ArgumentError.value(
        maxBufferSize,
        'maxBufferSize',
        'maxBufferSize must be positive.',
      );
    }
    _initDatabase();
    _startFlushTimer();
  }

  /// Filepath of the SQLite database.
  final String dbPath;

  /// Table name used to store log entries.
  final String tableName;

  /// Maximum log records retained before auto-pruning.
  final int? maxEntries;

  /// Maximum age of log records retained before auto-pruning.
  final Duration? maxAge;

  /// Number of log entries buffered in memory before committing a transaction.
  final int batchSize;

  /// Periodic timer interval to flush pending log entries.
  final Duration? flushInterval;

  /// Whether Write-Ahead Logging (WAL) is enabled.
  final bool walMode;

  /// Maximum capacity for in-memory buffer before evicting oldest logs.
  final int maxBufferSize;

  final Database _db;
  final List<_PendingSqliteLog> _batch;
  Timer? _flushTimer;
  bool _isDisposed = false;
  bool _inTransaction = false;

  PreparedStatement? _insertStmt;
  PreparedStatement? _pruneAgeStmt;
  PreparedStatement? _pruneCountStmt;

  void _initDatabase() {
    if (walMode && dbPath != ':memory:') {
      _db
        ..execute('PRAGMA journal_mode = WAL;')
        ..execute('PRAGMA synchronous = NORMAL;')
        ..execute('PRAGMA busy_timeout = 5000;');
    }

    _db
      ..execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT NOT NULL,
          level INTEGER NOT NULL,
          level_name TEXT NOT NULL,
          logger_name TEXT NOT NULL,
          origin TEXT NOT NULL,
          message TEXT NOT NULL,
          error TEXT,
          stack_trace TEXT,
          context_json TEXT,
          created_at INTEGER NOT NULL
        );
      ''')
      ..execute(
        'CREATE INDEX IF NOT EXISTS idx_${tableName}_created '
        'ON $tableName (created_at);',
      )
      ..execute(
        'CREATE INDEX IF NOT EXISTS idx_${tableName}_level '
        'ON $tableName (level);',
      )
      ..execute(
        'CREATE INDEX IF NOT EXISTS idx_${tableName}_logger '
        'ON $tableName (logger_name);',
      );

    _insertStmt = _db.prepare('''
      INSERT INTO $tableName (
        timestamp, level, level_name, logger_name, origin, message, error,
        stack_trace, context_json, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''');

    _pruneAgeStmt = maxAge != null
        ? _db.prepare('DELETE FROM $tableName WHERE created_at < ?;')
        : null;

    _pruneCountStmt = (maxEntries != null && maxEntries! > 0) ? _db.prepare('''
            DELETE FROM $tableName WHERE id NOT IN (
              SELECT id FROM $tableName ORDER BY id DESC LIMIT ?
            );
          ''') : null;
  }

  void _startFlushTimer() {
    if (flushInterval != null && flushInterval! > Duration.zero) {
      _flushTimer = Timer.periodic(flushInterval!, (final _) {
        _flushSync();
      });
    }
  }

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    if (!enabled || _isDisposed) {
      return;
    }

    final now = DateTime.now();
    String? contextJson;
    if (entry.context != null && entry.context!.isNotEmpty) {
      try {
        contextJson = convert.jsonEncode(
          entry.context,
          toEncodable: (final Object? nonEncodable) => nonEncodable.toString(),
        );
      } catch (_) {
        contextJson = convert.jsonEncode({'error': 'Unserializable context'});
      }
    }

    final pending = _PendingSqliteLog(
      timestamp: now.toIso8601String(),
      level: level.index,
      levelName: level.name,
      loggerName: entry.loggerName,
      origin: entry.origin,
      message: entry.message,
      error: entry.error?.toString(),
      stackTrace: entry.stackTrace?.toString(),
      contextJson: contextJson,
      createdAt: now.millisecondsSinceEpoch,
    );

    if (_batch.length >= maxBufferSize) {
      _batch.removeAt(0);
    }
    _batch.add(pending);

    if (_batch.length >= batchSize) {
      _flushSync();
    }
  }

  void _flushSync() {
    if (_isDisposed || _batch.isEmpty || _inTransaction) {
      return;
    }

    _inTransaction = true;
    final itemsToFlush = List<_PendingSqliteLog>.from(_batch);
    _batch.clear();

    try {
      _db.execute('BEGIN TRANSACTION;');
      final insertStmt = _insertStmt;
      if (insertStmt != null) {
        for (final item in itemsToFlush) {
          insertStmt.execute([
            item.timestamp,
            item.level,
            item.levelName,
            item.loggerName,
            item.origin,
            item.message,
            item.error,
            item.stackTrace,
            item.contextJson,
            item.createdAt,
          ]);
        }
      }
      _pruneLogs();
      _db.execute('COMMIT;');
    } catch (_) {
      try {
        _db.execute('ROLLBACK;');
      } catch (_) {}
      rethrow;
    } finally {
      _inTransaction = false;
    }
  }

  /// Flushes all pending in-memory log entries to disk in a single transaction.
  Future<void> flush() async {
    _flushSync();
  }

  void _pruneLogs() {
    final now = DateTime.now();
    final pruneAge = _pruneAgeStmt;
    if (pruneAge != null && maxAge != null) {
      final cutoff = now.subtract(maxAge!).millisecondsSinceEpoch;
      pruneAge.execute([cutoff]);
    }

    final pruneCount = _pruneCountStmt;
    if (pruneCount != null && maxEntries != null && maxEntries! > 0) {
      pruneCount.execute([maxEntries]);
    }
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot operate on a disposed SqliteSink.');
    }
  }

  /// Queries log records matching the specified search and filter criteria.
  List<Map<String, dynamic>> queryLogs({
    final LogLevel? minLevel,
    final String? loggerName,
    final String? search,
    final DateTime? start,
    final DateTime? end,
    final int limit = 100,
    final int offset = 0,
  }) {
    _ensureNotDisposed();

    // Ensure any buffered logs are written synchronously before querying
    _flushSync();

    final whereClauses = <String>[];
    final params = <Object?>[];

    if (minLevel != null) {
      whereClauses.add('level >= ?');
      params.add(minLevel.index);
    }

    if (loggerName != null && loggerName.isNotEmpty) {
      whereClauses.add('(logger_name = ? OR logger_name LIKE ?)');
      params
        ..add(loggerName)
        ..add('$loggerName.%');
    }

    if (search != null && search.isNotEmpty) {
      whereClauses.add(
        '(message LIKE ? OR error LIKE ? OR context_json LIKE ?)',
      );
      final term = '%$search%';
      params
        ..add(term)
        ..add(term)
        ..add(term);
    }

    if (start != null) {
      whereClauses.add('created_at >= ?');
      params.add(start.millisecondsSinceEpoch);
    }

    if (end != null) {
      whereClauses.add('created_at <= ?');
      params.add(end.millisecondsSinceEpoch);
    }

    final safeLimit = limit < 1 ? 1 : (limit > 10000 ? 10000 : limit);
    final safeOffset = offset < 0 ? 0 : offset;

    final whereSql =
        whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final sql = '''
      SELECT * FROM $tableName
      $whereSql
      ORDER BY id DESC
      LIMIT ? OFFSET ?;
    ''';

    params
      ..add(safeLimit)
      ..add(safeOffset);

    final ResultSet results = _db.select(sql, params);
    return results.map((final row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Backward-compatible fetch helper.
  List<Map<String, dynamic>> fetchLogs({final int limit = 100}) =>
      queryLogs(limit: limit);

  /// Returns a summary breakdown of stored log record counts per [LogLevel].
  Map<LogLevel, int> fetchLevelCounts() {
    _ensureNotDisposed();
    _flushSync();
    final ResultSet results = _db.select('''
      SELECT level, COUNT(*) as cnt
      FROM $tableName
      GROUP BY level;
    ''');
    final counts = <LogLevel, int>{};
    for (final row in results) {
      final idx = row['level'] as int;
      if (idx >= 0 && idx < LogLevel.values.length) {
        counts[LogLevel.values[idx]] = row['cnt'] as int;
      }
    }
    return counts;
  }

  /// Returns distinct logger names stored in the database with record counts.
  List<Map<String, dynamic>> fetchDistinctLoggerNames() {
    _ensureNotDisposed();
    _flushSync();
    final ResultSet results = _db.select('''
      SELECT logger_name, COUNT(*) as record_count
      FROM $tableName
      GROUP BY logger_name
      ORDER BY record_count DESC;
    ''');
    return results.map((final row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Returns total count of log records currently stored in the database.
  int count() {
    _ensureNotDisposed();
    _flushSync();
    final ResultSet results =
        _db.select('SELECT COUNT(*) as cnt FROM $tableName;');
    return results.first['cnt'] as int;
  }

  /// Deletes all log records stored in the database table.
  void clear() {
    _ensureNotDisposed();
    _batch.clear();
    _db.execute('DELETE FROM $tableName;');
  }

  /// Compacts the database storage file.
  void vacuum() {
    _ensureNotDisposed();
    _flushSync();
    _db.execute('VACUUM;');
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _flushTimer?.cancel();
    _flushTimer = null;
    _flushSync();

    _insertStmt?.close();
    _pruneAgeStmt?.close();
    _pruneCountStmt?.close();
    _db.close();

    await super.dispose();
  }
}
