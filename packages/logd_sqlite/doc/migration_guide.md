# Migration Guide: `logd_sqlite`

Starting with `logd` v0.9.7, relational SQLite log persistence is supported via the standalone `logd_sqlite` satellite package.

This guide explains how to integrate and migrate existing log storage to `logd_sqlite`.

---

## 1. Migrating to `v0.2.0` (Type-Safe Query Builder & FTS5)

`v0.2.0` introduces typed log records (`SqliteLogRecord`), a fluent query builder (`SqliteLogQuery`), BM25-ranked full-text search (FTS5), cursor pagination, and disk quota auto-purging (`maxDiskBytes`).

### Migrating Queries from `queryLogs()` to `query()`

While `queryLogs()` remains available for backward compatibility, new code should use the fluent builder API:

```dart
// Before (v0.1.x)
final logs = sink.queryLogs(
  minLevel: LogLevel.warning,
  loggerName: 'app.payment',
  search: 'connection timeout',
  limit: 50,
);

// After (v0.2.0)
final records = sink.query()
  .minLevel(LogLevel.warning)
  .logger('app.payment', hierarchy: true)
  .whereContext('userId', 'USR-1024')
  .search('connection timeout')
  .limit(50)
  .execute();
```

### Strongly-Typed Record Model (`SqliteLogRecord`)

In `v0.2.0`, queries return `List<SqliteLogRecord>` instead of `List<Map<String, dynamic>>`:

```dart
for (final record in records) {
  // Strongly typed properties
  print(record.level);            // LogLevel.warning
  print(record.message);          // String
  print(record.createdAtDateTime); // DateTime
  print(record.context);          // Map<String, dynamic>?
  print(record.snippet);          // String? (FTS5 match snippet)
  print(record.rank);             // double? (BM25 relevance score)

  // Backward-compatible map access continues to work
  print(record['level']);         // 3 (int)
  print(record['message']);       // String
}
```

### Keyset Cursor Pagination

Replace slow `offset:` queries with keyset cursor pagination for high-volume logs:

```dart
// Next page (records older than the last seen ID)
final nextBatch = sink.query()
  .afterId(records.last.id)
  .limit(50)
  .execute();
```

### Disk Quota Budgeting

Strictly cap log storage on disk using `maxDiskBytes`:

```dart
final sink = SqliteSink(
  dbPath: 'app.db',
  maxDiskBytes: 25 * 1024 * 1024, // 25 MB hard storage ceiling
);
```

---

## 2. Registering Serializers (For Full Isolate Config Sync)

`SqliteHandler.async()` constructs its native `SqliteSink` directly inside the worker isolate from plain configuration parameters, avoiding isolate handle transfer issues and eliminating the need for serializer registration.

However, if you export and import the full logger configuration registry across isolates using `Logger.exportConfig()` and `Logger.importConfig()`, you must register SQLite serializers during your application bootstrap:

```dart
void main() {
  // Required only when using Logger.exportConfig() / Logger.importConfig()
  registerLogdSqliteSerializers();
}
```

---

## 3. Compatibility with `logd` v0.10.0+

`logd_sqlite` v0.2.0+ requires `logd ^0.10.6`. Core logging remains purely semantic while `logd_sqlite` provides high-performance relational storage without breaking pipeline invariants.
