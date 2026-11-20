// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;

import 'package:logd/logd.dart';
import 'package:sqlite3/sqlite3.dart';

import 'sqlite_query.dart';
import 'sqlite_record.dart';

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
/// fidelity (origin, error, stackTrace, context), retention pruning
/// ([maxEntries], [maxAge], [maxDiskBytes]), optional FTS5 full-text indexing
/// ([enableFts]), and a type-safe query engine ([query]).
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

  /// Escapes a query string as a literal FTS5 double-quoted phrase.
  static String escapeFts5(final String query) =>
      '"${query.replaceAll('"', '""')}"';

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
  /// - [enableFts]: Whether to enable FTS5 virtual table indexing for full-text
  ///   search and BM25 ranking (default: `true`).
  /// - [maxDiskBytes]: Maximum disk/memory usage in bytes before auto-pruning
  ///   oldest records.
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
    this.enableFts = true,
    this.maxDiskBytes,
    super.enabled = true,
  }) : _db = database ?? sqlite3.open(dbPath),
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
    if (maxDiskBytes != null && maxDiskBytes! <= 0) {
      throw ArgumentError.value(
        maxDiskBytes,
        'maxDiskBytes',
        'maxDiskBytes must be positive if specified.',
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

  /// Whether FTS5 virtual table indexing is requested.
  final bool enableFts;

  /// Maximum storage capacity in bytes before auto-pruning oldest records.
  final int? maxDiskBytes;

  final Database _db;
  final List<_PendingSqliteLog> _batch;
  Timer? _flushTimer;
  bool _isDisposed = false;
  bool _inTransaction = false;
  bool _fts5Available = false;

  PreparedStatement? _insertStmt;
  PreparedStatement? _pruneAgeStmt;
  PreparedStatement? _pruneCountStmt;

  /// Whether SQLite FTS5 extension is available and enabled on this database.
  bool get isFts5Available => _fts5Available;

  bool _probeFts5() {
    const probeTable = '_logd_fts5_probe';
    try {
      _db
        ..execute('CREATE VIRTUAL TABLE $probeTable USING fts5(x);')
        ..execute('DROP TABLE $probeTable;');
      return true;
    } catch (_) {
      return false;
    }
  }

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

    if (enableFts) {
      _fts5Available = _probeFts5();
      if (_fts5Available) {
        final ftsExisted = _db.select('''
          SELECT 1 FROM sqlite_master
          WHERE type = 'table' AND name = '${tableName}_fts';
        ''').isNotEmpty;

        _db
          ..execute('''
            CREATE VIRTUAL TABLE IF NOT EXISTS ${tableName}_fts USING fts5(
              message,
              error,
              context_json,
              content='$tableName',
              content_rowid='id'
            );
          ''')
          ..execute('''
            CREATE TRIGGER IF NOT EXISTS ${tableName}_ai
            AFTER INSERT ON $tableName BEGIN
              INSERT INTO ${tableName}_fts(rowid, message, error, context_json)
              VALUES (new.id, new.message, new.error, new.context_json);
            END;
          ''')
          ..execute('''
            CREATE TRIGGER IF NOT EXISTS ${tableName}_ad
            AFTER DELETE ON $tableName BEGIN
              INSERT INTO ${tableName}_fts(${tableName}_fts, rowid, message, error, context_json)
              VALUES('delete', old.id, old.message, old.error, old.context_json);
            END;
          ''')
          ..execute('''
            CREATE TRIGGER IF NOT EXISTS ${tableName}_au
            AFTER UPDATE ON $tableName BEGIN
              INSERT INTO ${tableName}_fts(${tableName}_fts, rowid, message, error, context_json)
              VALUES('delete', old.id, old.message, old.error, old.context_json);
              INSERT INTO ${tableName}_fts(rowid, message, error, context_json)
              VALUES (new.id, new.message, new.error, new.context_json);
            END;
          ''');

        if (!ftsExisted) {
          _db.execute(
            "INSERT INTO ${tableName}_fts(${tableName}_fts) VALUES('rebuild');",
          );
        }
      }
    }

    _insertStmt = _db.prepare('''
      INSERT INTO $tableName (
        timestamp, level, level_name, logger_name, origin, message, error,
        stack_trace, context_json, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''');

    _pruneAgeStmt = maxAge != null
        ? _db.prepare('DELETE FROM $tableName WHERE created_at < ?;')
        : null;

    _pruneCountStmt = (maxEntries != null && maxEntries! > 0)
        ? _db.prepare('''
            DELETE FROM $tableName WHERE id NOT IN (
              SELECT id FROM $tableName ORDER BY id DESC LIMIT ?
            );
          ''')
        : null;
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
  @override
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

    _pruneDiskQuota();
  }

  void _pruneDiskQuota() {
    final quota = maxDiskBytes;
    if (quota == null) {
      return;
    }

    while (true) {
      final row = _db.select('''
        SELECT (page_count - freelist_count) * page_size AS live_bytes
        FROM pragma_page_count(), pragma_freelist_count(), pragma_page_size();
      ''').first;
      final liveBytes = row['live_bytes'] as int;
      if (liveBytes <= quota) {
        break;
      }

      _db.execute('''
        DELETE FROM $tableName WHERE id IN (
          SELECT id FROM $tableName ORDER BY id ASC LIMIT 50
        );
      ''');
      if (_db.updatedRows == 0) {
        break;
      }
    }
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot operate on a disposed SqliteSink.');
    }
  }

  /// Returns a fluent [SqliteLogQuery] builder bound to this sink.
  SqliteLogQuery query() => SqliteLogQuery.bound(this);

  String _colName(final SqliteSortField field) => switch (field) {
    SqliteSortField.id => 'id',
    SqliteSortField.createdAt => 'created_at',
    SqliteSortField.level => 'level',
    SqliteSortField.rank => 'rank',
  };

  (String, List<Object?>) _compileSelectSql(final SqliteLogQuery q) {
    final useFts =
        _fts5Available &&
        ((q.searchTerm != null && q.searchTerm!.isNotEmpty) ||
            (q.rawMatch != null && q.rawMatch!.isNotEmpty));

    final whereClauses = <String>[];
    final params = <Object?>[];
    final prefix = useFts ? 'l.' : '';

    if (useFts) {
      whereClauses.add('${tableName}_fts MATCH ?');
      if (q.rawMatch != null && q.rawMatch!.isNotEmpty) {
        params.add(q.rawMatch);
      } else {
        params.add(escapeFts5(q.searchTerm!));
      }
    } else if (q.searchTerm != null && q.searchTerm!.isNotEmpty) {
      whereClauses.add(
        '(${prefix}message LIKE ? OR ${prefix}error LIKE ? '
        'OR ${prefix}context_json LIKE ?)',
      );
      final term = '%${q.searchTerm}%';
      params
        ..add(term)
        ..add(term)
        ..add(term);
    }

    _applyFilterClauses(q, prefix, whereClauses, params);

    final whereSql = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final sortCol = q.sortField == SqliteSortField.rank && !useFts
        ? 'id'
        : (q.sortField == SqliteSortField.rank
              ? 'rank'
              : '$prefix${_colName(q.sortField)}');
    final sortDir = q.sortOrder == SqliteSortOrder.ascending ? 'ASC' : 'DESC';
    final safeLimit = q.limitCount < 1
        ? 1
        : (q.limitCount > 10000 ? 10000 : q.limitCount);
    final safeOffset = q.offsetCount < 0 ? 0 : q.offsetCount;

    String sql;
    if (useFts) {
      sql =
          '''
        SELECT
          l.*,
          snippet(${tableName}_fts, 0, '<b>', '</b>', '...', 15) AS snippet,
          ${tableName}_fts.rank AS rank
        FROM ${tableName}_fts
        JOIN $tableName l ON l.id = ${tableName}_fts.rowid
        $whereSql
        ORDER BY $sortCol $sortDir
        LIMIT ? OFFSET ?;
      ''';
    } else {
      sql =
          '''
        SELECT * FROM $tableName
        $whereSql
        ORDER BY $sortCol $sortDir
        LIMIT ? OFFSET ?;
      ''';
    }

    params
      ..add(safeLimit)
      ..add(safeOffset);

    return (sql, params);
  }

  (String, List<Object?>) _compileCountSql(final SqliteLogQuery q) {
    final useFts =
        _fts5Available &&
        ((q.searchTerm != null && q.searchTerm!.isNotEmpty) ||
            (q.rawMatch != null && q.rawMatch!.isNotEmpty));

    final whereClauses = <String>[];
    final params = <Object?>[];
    final prefix = useFts ? 'l.' : '';

    if (useFts) {
      whereClauses.add('${tableName}_fts MATCH ?');
      if (q.rawMatch != null && q.rawMatch!.isNotEmpty) {
        params.add(q.rawMatch);
      } else {
        params.add(escapeFts5(q.searchTerm!));
      }
    } else if (q.searchTerm != null && q.searchTerm!.isNotEmpty) {
      whereClauses.add(
        '(${prefix}message LIKE ? OR ${prefix}error LIKE ? '
        'OR ${prefix}context_json LIKE ?)',
      );
      final term = '%${q.searchTerm}%';
      params
        ..add(term)
        ..add(term)
        ..add(term);
    }

    _applyFilterClauses(q, prefix, whereClauses, params);

    final whereSql = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    String sql;
    if (useFts) {
      sql =
          '''
        SELECT COUNT(*) AS cnt
        FROM ${tableName}_fts
        JOIN $tableName l ON l.id = ${tableName}_fts.rowid
        $whereSql;
      ''';
    } else {
      sql = 'SELECT COUNT(*) AS cnt FROM $tableName $whereSql;';
    }

    return (sql, params);
  }

  (String, List<Object?>) _compileDeleteSql(final SqliteLogQuery q) {
    final useFts =
        _fts5Available &&
        ((q.searchTerm != null && q.searchTerm!.isNotEmpty) ||
            (q.rawMatch != null && q.rawMatch!.isNotEmpty));

    final whereClauses = <String>[];
    final params = <Object?>[];
    final prefix = useFts ? 'l.' : '';

    if (useFts) {
      whereClauses.add('${tableName}_fts MATCH ?');
      if (q.rawMatch != null && q.rawMatch!.isNotEmpty) {
        params.add(q.rawMatch);
      } else {
        params.add(escapeFts5(q.searchTerm!));
      }
    } else if (q.searchTerm != null && q.searchTerm!.isNotEmpty) {
      whereClauses.add(
        '(${prefix}message LIKE ? OR ${prefix}error LIKE ? '
        'OR ${prefix}context_json LIKE ?)',
      );
      final term = '%${q.searchTerm}%';
      params
        ..add(term)
        ..add(term)
        ..add(term);
    }

    _applyFilterClauses(q, prefix, whereClauses, params);

    final whereSql = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    String sql;
    if (useFts) {
      sql =
          '''
        DELETE FROM $tableName
        WHERE id IN (
          SELECT l.id
          FROM ${tableName}_fts
          JOIN $tableName l ON l.id = ${tableName}_fts.rowid
          $whereSql
        );
      ''';
    } else {
      sql = 'DELETE FROM $tableName $whereSql;';
    }

    return (sql, params);
  }

  void _applyFilterClauses(
    final SqliteLogQuery q,
    final String prefix,
    final List<String> whereClauses,
    final List<Object?> params,
  ) {
    if (q.levels != null && q.levels!.isNotEmpty) {
      final placeholders = List.filled(q.levels!.length, '?').join(', ');
      whereClauses.add('${prefix}level IN ($placeholders)');
      params.addAll(q.levels!.map((final l) => l.index));
    } else {
      if (q.minimumLevel != null) {
        whereClauses.add('${prefix}level >= ?');
        params.add(q.minimumLevel!.index);
      }
      if (q.maximumLevel != null) {
        whereClauses.add('${prefix}level <= ?');
        params.add(q.maximumLevel!.index);
      }
    }

    if (q.loggerName != null && q.loggerName!.isNotEmpty) {
      if (q.loggerHierarchy) {
        whereClauses.add(
          '(${prefix}logger_name = ? OR ${prefix}logger_name LIKE ?)',
        );
        params
          ..add(q.loggerName)
          ..add('${q.loggerName}.%');
      } else {
        whereClauses.add('${prefix}logger_name = ?');
        params.add(q.loggerName);
      }
    }

    for (final entry in q.contextFilters.entries) {
      final key = entry.key;
      final path = key.startsWith(r'$.') ? key : r'$.' + key;
      final val = entry.value;
      if (val == null) {
        whereClauses.add('json_extract(${prefix}context_json, ?) IS NULL');
        params.add(path);
      } else if (val is bool) {
        whereClauses.add('json_extract(${prefix}context_json, ?) = ?');
        params
          ..add(path)
          ..add(val ? 1 : 0);
      } else {
        whereClauses.add('json_extract(${prefix}context_json, ?) = ?');
        params
          ..add(path)
          ..add(val);
      }
    }

    if (q.start != null) {
      whereClauses.add('${prefix}created_at >= ?');
      params.add(q.start!.millisecondsSinceEpoch);
    }

    if (q.end != null) {
      whereClauses.add('${prefix}created_at <= ?');
      params.add(q.end!.millisecondsSinceEpoch);
    }

    if (q.afterCursorId != null) {
      if (q.sortOrder == SqliteSortOrder.descending) {
        whereClauses.add('${prefix}id < ?');
      } else {
        whereClauses.add('${prefix}id > ?');
      }
      params.add(q.afterCursorId);
    }

    if (q.beforeCursorId != null) {
      if (q.sortOrder == SqliteSortOrder.descending) {
        whereClauses.add('${prefix}id > ?');
      } else {
        whereClauses.add('${prefix}id < ?');
      }
      params.add(q.beforeCursorId);
    }
  }

  /// Executes [query] against this database and returns strongly-typed results.
  List<SqliteLogRecord> execute(final SqliteLogQuery query) {
    _ensureNotDisposed();
    _flushSync();

    final (sql, params) = _compileSelectSql(query);
    final ResultSet results = _db.select(sql, params);
    return results.map((final row) => SqliteLogRecord.fromRow(row)).toList();
  }

  /// Returns the total count of records matching [query].
  int countQuery(final SqliteLogQuery query) {
    _ensureNotDisposed();
    _flushSync();

    final (sql, params) = _compileCountSql(query);
    final ResultSet results = _db.select(sql, params);
    return results.first['cnt'] as int;
  }

  /// Deletes all records matching [query] and returns the count of deleted
  /// rows.
  int deleteQuery(final SqliteLogQuery query) {
    _ensureNotDisposed();
    _flushSync();

    final (sql, params) = _compileDeleteSql(query);
    _db.execute(sql, params);
    return _db.updatedRows;
  }

  /// Queries log records matching the specified search and filter criteria.
  ///
  /// Deprecated in favor of [query]. Returns strongly-typed [SqliteLogRecord]s
  /// that implement [operator []] for backward compatibility with map access.
  @Deprecated(
    'Use query() builder instead. '
    'queryLogs() will be removed in v0.3.0. '
    'Migration: sink.query().minLevel(...).logger(...).search(...).limit(...)'
    '.execute()',
  )
  List<SqliteLogRecord> queryLogs({
    final LogLevel? minLevel,
    final String? loggerName,
    final String? search,
    final DateTime? start,
    final DateTime? end,
    final int limit = 100,
    final int offset = 0,
  }) {
    var q = query();
    if (minLevel != null) {
      q = q.minLevel(minLevel);
    }
    if (loggerName != null && loggerName.isNotEmpty) {
      q = q.logger(loggerName, hierarchy: true);
    }
    if (search != null && search.isNotEmpty) {
      q = q.search(search);
    }
    if (start != null) {
      q = q.after(start);
    }
    if (end != null) {
      q = q.before(end);
    }
    q = q.limit(limit).offset(offset);
    return q.execute();
  }

  /// Backward-compatible fetch helper.
  List<SqliteLogRecord> fetchLogs({final int limit = 100}) =>
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
    final ResultSet results = _db.select(
      'SELECT COUNT(*) as cnt FROM $tableName;',
    );
    return results.first['cnt'] as int;
  }

  /// Deletes all log records stored in the database table and synchronizes
  /// FTS5.
  void clear() {
    _ensureNotDisposed();
    _batch.clear();
    _db.execute('BEGIN TRANSACTION;');
    try {
      _db.execute('DELETE FROM $tableName;');
      if (_fts5Available) {
        _db.execute(
          "INSERT INTO ${tableName}_fts(${tableName}_fts) "
          "VALUES('delete-all');",
        );
      }
      _db.execute('COMMIT;');
    } catch (_) {
      try {
        _db.execute('ROLLBACK;');
      } catch (_) {}
      rethrow;
    }
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
