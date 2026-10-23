// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

import 'sqlite_isolate_handler.dart';
import 'sqlite_sink.dart';

/// A pre-wired [Handler] that persists logs to a SQLite database (ADR-006).
///
/// Uses [StructuredFormatter] and a [SqliteSink] with Write-Ahead Logging (WAL)
/// mode, atomic transaction batching, and auto-pruning retention policies.
@immutable
class SqliteHandler extends Handler {
  /// Creates a [SqliteHandler] writing to the SQLite database at [path].
  SqliteHandler({
    required final String path,
    final String tableName = 'logs',
    final int batchSize = 50,
    final Duration flushInterval = const Duration(seconds: 2),
    final int? maxEntries,
    final Duration? maxAge,
    final int maxBufferSize = 10000,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
          formatter: formatter ?? const StructuredFormatter(),
          sink: SqliteSink(
            dbPath: path,
            tableName: tableName,
            batchSize: batchSize,
            flushInterval: flushInterval,
            maxEntries: maxEntries ?? 10000,
            maxAge: maxAge,
            maxBufferSize: maxBufferSize,
          ),
          decorators: decorators ?? const [],
        );

  /// Creates a [SqliteHandler] using an in-memory SQLite database.
  SqliteHandler.inMemory({
    final String tableName = 'logs',
    final int batchSize = 50,
    final Duration flushInterval = const Duration(seconds: 2),
    final int? maxEntries,
    final Duration? maxAge,
    final int maxBufferSize = 10000,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
          formatter: formatter ?? const StructuredFormatter(),
          sink: SqliteSink(
            dbPath: ':memory:',
            tableName: tableName,
            batchSize: batchSize,
            flushInterval: flushInterval,
            maxEntries: maxEntries ?? 10000,
            maxAge: maxAge,
            maxBufferSize: maxBufferSize,
          ),
          decorators: decorators ?? const [],
        );

  /// Creates a [SqliteHandler] using an existing [Database] instance.
  SqliteHandler.database({
    required final Database database,
    final String tableName = 'logs',
    final int batchSize = 50,
    final Duration flushInterval = const Duration(seconds: 2),
    final int? maxEntries,
    final Duration? maxAge,
    final int maxBufferSize = 10000,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
          formatter: formatter ?? const StructuredFormatter(),
          sink: SqliteSink(
            database: database,
            tableName: tableName,
            batchSize: batchSize,
            flushInterval: flushInterval,
            maxEntries: maxEntries ?? 10000,
            maxAge: maxAge,
            maxBufferSize: maxBufferSize,
          ),
          decorators: decorators ?? const [],
        );

  /// Access to the underlying [SqliteSink] for query engine operations
  /// (`queryLogs`, `fetchLevelCounts`, `fetchDistinctLoggerNames`, `clear`).
  SqliteSink get sqliteSink => sink as SqliteSink;

  /// Creates an asynchronous [SqliteHandler] offloaded to a background
  /// isolate.
  ///
  /// The [SqliteSink] is constructed entirely inside the background isolate
  /// from the supplied config. This avoids isolate boundary transfer errors
  /// that arise with native SQLite handles and [Timer] instances.
  static Handler async({
    required final String path,
    final String tableName = 'logs',
    final int batchSize = 50,
    final Duration flushInterval = const Duration(seconds: 2),
    final int? maxEntries,
    final Duration? maxAge,
    final bool walMode = true,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final List<LogFilter> filters = const [],
    final Duration? timeout,
  }) =>
      SqliteIsolateHandler(
        path: path,
        tableName: tableName,
        batchSize: batchSize,
        flushInterval: flushInterval,
        maxEntries: maxEntries ?? 10000,
        maxAge: maxAge,
        walMode: walMode,
        formatter: formatter ?? const StructuredFormatter(),
        decorators: decorators ?? const [],
        filters: filters,
        timeout: timeout,
      );
}
