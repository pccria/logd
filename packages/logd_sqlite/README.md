# logd_sqlite

[![pub package](https://img.shields.io/pub/v/logd_sqlite.svg)](https://pub.dev/packages/logd_sqlite)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

![logd_sqlite Hero](https://raw.githubusercontent.com/pooriaaskarim/logd/master/assets/img/logd_sqlite_hero.webp)

A high-performance SQLite persistence log sink and handler for [`logd`](https://pub.dev/packages/logd).

Features pre-compiled prepared statements, Write-Ahead Logging (WAL mode), atomic transaction batching, full log field fidelity (`origin`, `error`, `stackTrace`, `context`), auto-pruning retention policies (`maxEntries`, `maxAge`), and a rich query engine.

---

## Installation

Add `logd` and `logd_sqlite` to your `pubspec.yaml`:

```yaml
dependencies:
  logd: ^latest_version
  logd_sqlite: ^latest_version
```

### Platform & Native Setup

`logd_sqlite` uses `package:sqlite3` dynamic library bindings:

* **Flutter (Android / iOS / macOS / Windows / Linux)**: Add `sqlite3_flutter_libs` to your `pubspec.yaml` to bundle native SQLite binaries.
* **Pure Dart CLI / Server**: Uses system SQLite libraries (e.g., `libsqlite3.so` on Linux, `libsqlite3.dylib` on macOS, `sqlite3.dll` on Windows).

---

## Quick Start

Use the pre-wired `SqliteHandler` to persist logs to disk with zero configuration:

```dart
import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';

void main() async {
  final sqliteHandler = SqliteHandler(
    path: 'app_logs.db',
    maxEntries: 10000,
    maxAge: const Duration(days: 7),
    batchSize: 50,
    flushInterval: const Duration(seconds: 2),
  );

  Logger.configure('app', handlers: [sqliteHandler]);

  final logger = Logger.get('app.service');
  logger.info(
    'Payment processed successfully',
    context: {'transactionId': 'TX-1002', 'amount': 99.99},
  );

  // Query stored logs via the handler's sink
  final errorLogs = sqliteHandler.sqliteSink.queryLogs(
    minLevel: LogLevel.warning,
    search: 'Payment',
    limit: 50,
  );

  // Flush and dispose handle on app exit
  await sqliteHandler.dispose();
}
```

---

## Pre-Wired Handler Constructors

`SqliteHandler` provides constructors for different application environments:

```dart
// 1. File-backed database (synchronous execution)
final handler = SqliteHandler(
  path: 'logs/app.db',
  maxEntries: 50000,
  maxAge: const Duration(days: 14),
);

// 2. Asynchronous background isolate worker (non-blocking I/O)
final asyncHandler = SqliteHandler.async(
  path: 'logs/app.db',
  batchSize: 50,
  flushInterval: const Duration(seconds: 2),
);

// 3. In-Memory database (ideal for tests and ephemeral runs)
final testHandler = SqliteHandler.inMemory();

// 4. Existing database instance (share a connection pool)
final sharedHandler = SqliteHandler.database(
  database: existingDb,
);
```

---

## Advanced Query Engine & Inspection

`SqliteSink` provides a built-in search and filter engine along with metadata discovery helpers:

<p align="center">
  <img src="https://raw.githubusercontent.com/pooriaaskarim/logd/master/assets/img/logd_sqlite_query_showcase.webp" alt="logd_sqlite Query Showcase" width="780" />
</p>

```dart
final sink = sqliteHandler.sqliteSink;

// 1. Multi-Criteria Query
final logs = sink.queryLogs(
  minLevel: LogLevel.warning,                                 // Filter by minimum LogLevel
  loggerName: 'app.auth',                                     // Filter by logger hierarchy namespace
  search: 'token expired',                                    // Full-text search in message & error
  start: DateTime.now().subtract(const Duration(hours: 1)),  // Time window start
  end: DateTime.now(),                                        // Time window end
  limit: 100,
  offset: 0,
);

// 2. Level Breakdown Summary
final levelCounts = sink.fetchLevelCounts();
// Map<LogLevel, int> -> {LogLevel.info: 120, LogLevel.warning: 5, LogLevel.error: 1}

// 3. Discover Active Logger Namespaces
final namespaces = sink.fetchDistinctLoggerNames();
// List<Map<String, dynamic>> -> [{'logger_name': 'app.auth', 'record_count': 14}, ...]
```

---

## Configuration Reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `path` / `dbPath` | `String` | `'logs.db'` | Path to SQLite database file (or `:memory:` for in-memory). |
| `tableName` | `String` | `'logs'` | SQL table name for log records. |
| `maxEntries` | `int?` | `10000` | Capped record count retained before auto-pruning. |
| `maxAge` | `Duration?` | `null` | Maximum age of log records before auto-pruning. |
| `batchSize` | `int` | `50` | Number of log entries buffered before committing transaction. |
| `flushInterval` | `Duration?` | `2 seconds` | Interval timer to flush pending memory buffer. |
| `walMode` | `bool` | `true` | Enables Write-Ahead Logging for high write throughput. |

---

## Database Schema Reference

`SqliteSink` automatically initializes the following indexed SQL table structure (`tableName: 'logs'`):

| Column Name | SQL Type | Description |
| :--- | :--- | :--- |
| `id` | `INTEGER PRIMARY KEY` | Auto-incrementing log record ID. |
| `timestamp` | `TEXT NOT NULL` | ISO-8601 formatted timestamp string. |
| `level` | `INTEGER NOT NULL` | Numeric level index (`0=trace` to `4=error`). |
| `level_name` | `TEXT NOT NULL` | Uppercase level string (`'INFO'`, `'ERROR'`). |
| `logger_name` | `TEXT NOT NULL` | Hierarchical namespace (`'app.payment'`). |
| `origin` | `TEXT NOT NULL` | Caller method/function origin string. |
| `message` | `TEXT NOT NULL` | Log message body. |
| `error` | `TEXT` | Formatted exception message (optional). |
| `stack_trace` | `TEXT` | Decomposed stack trace string (optional). |
| `context_json` | `TEXT` | JSON encoded context parameters (optional). |
| `created_at` | `INTEGER NOT NULL` | Milliseconds since Unix epoch (indexed). |

---

## Custom Pipeline Integration (`SqliteSink`)

When composing a customized handler pipeline manually, pair `SqliteSink` with any formatter or filters:

```dart
final sink = SqliteSink(
  dbPath: 'app.db',
  maxEntries: 20000,
  walMode: true,
);

final customHandler = Handler(
  formatter: const PlainFormatter(),
  sink: sink,
  filters: [LevelFilter(LogLevel.warning)],
);

Logger.configure('global', handlers: [customHandler]);
```

---

## Lifecycle & Graceful Shutdown

Because `SqliteSink` buffers entries in memory (`batchSize: 50`), ensure you dispose or flush the handler during application shutdown:

```dart
// Flush pending buffer and close SQLite database connection
await sqliteHandler.dispose();
```

---

## Maintenance Utilities

```dart
final sink = sqliteHandler.sqliteSink;

// Total record count
final count = sink.count();

// Force immediate transaction commit of buffered records
await sink.flush();

// Purge all records from database table
sink.clear();

// Reclaim unused disk space
sink.vacuum();
```

---

## Executable Examples

* **[sqlite_interactive_dashboard.dart](example/sqlite_interactive_dashboard.dart)**:
  An interactive terminal REPL dashboard allowing real-time log ingestion, level filtering, namespace discovery, single-record inspection, and write throughput benchmarking.
  ```bash
  dart run example/sqlite_interactive_dashboard.dart
  ```

* **[sqlite_sink_showcase.dart](example/sqlite_sink_showcase.dart)**:
  A non-interactive telemetry simulation and proof-of-concept tour.
  ```bash
  dart run example/sqlite_sink_showcase.dart
  ```

---

## License & Copyright

`logd_sqlite` is published under the **BSD 3-Clause License**.

```text
Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.
```

See the full [LICENSE](LICENSE) file for complete terms and conditions.

### Third-Party Dependencies & Credits

* **[`package:sqlite3`](https://pub.dev/packages/sqlite3)** (BSD 3-Clause License) — High-performance FFI bindings for SQLite in Dart.
* **[SQLite Database Engine](https://www.sqlite.org/)** (Public Domain) — Embedded C relational database engine.

