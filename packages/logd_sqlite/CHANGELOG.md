## 0.1.5

- **`logd` v0.10.x Support**: Widened dependency constraint to `logd: '>=0.9.7 <0.11.0'`, enabling seamless compatibility with `logd` v0.10.0's pure semantic engine.
- **Documentation**: Updated migration and usage guides for `logd` v0.10.0+ integration.

## 0.1.4

- **Async Isolate Support (`SqliteHandler.async`)**: Added `SqliteHandler.async()` static factory method allowing SQLite log persistence to run on background isolates without blocking main event loops.
- **Direct Formatter & Decorator Transfer**: Supports direct transfer of `@immutable` `LogFormatter` and `LogDecorator` instances across isolates without JSON serialization overhead.
- **Lifecycle Hardening & Race-Free `dispose()`**: Awaits isolate initialization before executing teardown, eliminating race conditions during immediate shutdown and preventing locked database file handles on Windows.
- **Sequential Queue Processing**: Worker isolate processes incoming log entries sequentially via `await for`, guaranteeing all pending entries flush to SQLite before database connection closure.
- **Serialization Support**: Added `registerLogdSqliteSerializers()` to register `SqliteSink` with `LoggerSerializationRegistry` for `Logger.exportConfig()` and `Logger.importConfig()`.
- **Cross-Satellite Matrix Testing**: Added end-to-end integration tests validating concurrent `SqliteHandler.async` logging with `MarkdownFormatter`, `HtmlFormatter`, and `ToonFormatter`.
- **Documentation**: Added `doc/architecture.md`, `doc/benchmarks.md`, and `doc/migration_guide.md`.
- **Updated Dependencies**: Updated `logd` dependency constraint to `^0.9.7`.

## 0.1.3

- **Pub.dev Score & Lower-Bound Analysis Fixes**:
  - Updated `sqlite3` lower bound constraint to `^3.0.0` to resolve `PreparedStatement.close()` lower-bound compatibility under `dart pub downgrade` analysis.
  - Added explicit `platforms` section in `pubspec.yaml` for `android`, `ios`, `linux`, `macos`, and `windows` native OS targets.

## 0.1.2

- **ADR-006 `{Target}Handler` Alignment**:
  - Introduced `SqliteHandler` convenience subclass extending `Handler` (`SqliteHandler()`, `SqliteHandler.inMemory()`, and `SqliteHandler.database()`).
  - Added direct `sqliteSink` getter on `SqliteHandler` for rich query engine access (`queryLogs()`, `fetchLevelCounts()`, `fetchDistinctLoggerNames()`).
  - Updated `logd` dependency constraint to `^0.9.3`.
- **`sqlite3` 3.x & Native Assets Modernization**:
  - Updated `sqlite3` version constraint to `'>=2.4.0 <4.0.0'`, fully supporting `sqlite3` 3.x releases.
  - Leveraged Dart Native Assets build hooks, removing obsolete manual dynamic library overrides (`open.overrideFor`).
  - Updated statement and database disposal lifecycle calls to `.close()`.

## 0.1.1

- **Pub.dev Maintenance & Score Fixes**:
  - Added library-level documentation comment to `logd_sqlite` primary export.
  - Added `example/example.dart` standard example entrypoint for pub.dev automated score discovery.
  - Updated `pubspec.yaml` repository and homepage URLs to valid HTTP 200 endpoints.
  - Updated `sqlite3` dependency version constraint to `'>=2.4.0 <4.0.0'` supporting both 2.x and 3.x releases.
  - Updated `logd` dependency constraint to `^0.9.2`.

## 0.1.0

- Initial release of `logd_sqlite`, a dedicated satellite package providing production-grade SQLite persistence logging for `logd`.
- **`SqliteSink`**: High-performance `LogSink<LogDocument>` supporting:
  - Pre-compiled prepared statement reuse across all log writes.
  - Write-Ahead Logging (`WAL` mode) and synchronous pragma optimizations.
  - Atomic transaction batching (`batchSize`, `flushInterval`).
  - Full entry field fidelity (`timestamp`, `level`, `logger_name`, `origin`, `message`, `error`, `stack_trace`, `context_json`).
  - Auto-pruning retention policies (`maxEntries`, `maxAge`).
  - Rich query engine (`queryLogs`) supporting level filtering, logger namespace matching, full-text search, and pagination.
  - Inspection helpers `fetchLevelCounts()` and `fetchDistinctLoggerNames()`.
  - Database utilities `count()`, `clear()`, `vacuum()`, and `flush()`.
- **Examples & Showcase**:
  - `example.dart`: Standard usage entrypoint for log write, query engine, and level breakdown.
  - `sqlite_sink_showcase.dart`: Top-to-bottom telemetry simulation and query engine proof-of-concept.
  - `sqlite_interactive_dashboard.dart`: Interactive REPL CLI dashboard with level counts, discovered namespaces, and throughput benchmarking.
