# logd_sqlite Architecture

`logd_sqlite` provides high-performance relational log persistence for the `logd` ecosystem, featuring Write-Ahead Logging (WAL), atomic batching, auto-pruning retention policies, FTS5 full-text search, and full-fidelity log query capabilities.

## Core Concepts

### 1. `SqliteSink`
The `SqliteSink` extends `LogSink<LogDocument>` and interfaces directly with `package:sqlite3`. It holds a pre-compiled set of prepared statements for low-overhead insertion and auto-pruning:
- `_insertStmt`: Atomic row insertions.
- `_pruneAgeStmt`: Age-based row deletion (`maxAge`).
- `_pruneCountStmt`: Count-based row deletion (`maxEntries`).
- `_pruneDiskQuota()`: Size-based auto-pruning (`maxDiskBytes`) using SQLite page metrics.

### 2. `SqliteHandler`
A pre-wired `Handler` combining `StructuredFormatter` and `SqliteSink`. It offers convenient constructors:
- `SqliteHandler(path: ...)`: Standard disk-backed database file.
- `SqliteHandler.inMemory()`: In-memory database, ideal for test suites.
- `SqliteHandler.database(database: ...)`: Wraps an existing `Database` connection.
- `SqliteHandler.async(path: ...)`: Spawns an `AsyncHandler` executing all SQLite reads/writes on a background Dart isolate.
- `handler.query()`: Direct access to the fluent query builder.

### 3. Background Isolate Serialization
When using `SqliteHandler.async()`, `registerLogdSqliteSerializers()` must be called during application bootstrapping. This registers `SqliteSink` with `LoggerSerializationRegistry` so that database path configuration and retention limits are safely serialized across isolate boundaries without attempting to transfer native pointers.

### 4. FTS5 Virtual Table & Trigger Synchronization
When `enableFts` is active (default: `true`), `SqliteSink` creates an external content FTS5 virtual table (`${tableName}_fts`) linked to the primary table (`content='$tableName'`, `content_rowid='id'`).
- SQLite triggers (`AFTER INSERT`, `AFTER DELETE`, `AFTER UPDATE`) keep the inverted full-text index synchronized atomically inside the same write transactions as primary log rows.
- On initialization, FTS5 availability is dynamically probed; if SQLite on the host lacks FTS5 support, queries automatically fall back to parameterized `LIKE` operations without runtime exceptions.
- `clear()` executes an atomic FTS5 `delete-all` command to reset the inverted index without row-by-row trigger overhead.

### 5. Type-Safe Query Engine & Keyset Cursor Pagination
The `SqliteLogQuery` builder compiles typed filter specifications into optimized SQL statements:
- Level filtering: `.minLevel()`, `.maxLevel()`, `.levelsFilter()`.
- Hierarchical namespaces: `.logger('app.auth', hierarchy: true)`.
- Context queries: `.whereContext('key', value)` leveraging SQLite's native `json_extract()`.
- Keyset cursor pagination: `.afterId()` and `.beforeId()` provide O(1) index seeks, eliminating `OFFSET` table scan performance degradation on large log databases.
- Strong typing: returns `List<SqliteLogRecord>` with direct getters (`.level`, `.context`, `.snippet`, `.rank`) while preserving backward-compatible map indexing via `operator []`.

### 6. Storage Quota Auto-Purging (`maxDiskBytes`)
`SqliteSink` supports a hard storage ceiling via `maxDiskBytes`.
- Live storage usage is calculated via SQLite's page metrics: `(page_count - freelist_count) * page_size`.
- Free pages returned by deletes remain in SQLite's freelist and are reused by subsequent log inserts, preventing premature or repeated pruning without incurring WAL checkpoint or `VACUUM` lock contention.
