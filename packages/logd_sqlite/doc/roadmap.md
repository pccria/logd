# logd_sqlite Roadmap

Package version at time of writing: **0.1.7**

---

## Versioning Strategy

`logd_sqlite` follows the semver contract defined in
[`doc/semver_contract.md`](../../../doc/semver_contract.md):

| Increment | Triggers |
|---|---|
| **Patch** (`0.1.x`) | Non-breaking bug fixes, security hardening, and performance optimizations. |
| **Minor** (`0.x.0`) | New backward-compatible query features, indexing enhancements, or storage drivers. |
| **Major** (`x.0.0`) | Breaking changes to database schema conventions or core sink APIs. |

---

## Completed

### ✅ v0.2.0: Type-Safe Query Builder, Cursor Pagination & FTS5 Full-Text Search

**Goal**: Transform `logd_sqlite` into a queryable local log engine with high-performance search, structured querying, and automated disk management.

- [x] **Type-Safe Query Builder (`SqliteLogQuery`)**:
  - Added fluent, composable query builder extensions to construct type-safe filters on log levels, logger hierarchy prefixes, timestamps, and JSON context keys (`json_extract`) without manual SQL concatenation.
- [x] **Cursor-Based Keyset Pagination**:
  - Implemented cursor-based navigation (`afterId`, `beforeId`) for O(1) index seeks across disk log history in interactive tools without `OFFSET` performance degradation.
- [x] **Full-Text Search (FTS5) Virtual Table**:
  - Added FTS5 virtual table indexing on message payloads, stack traces, and serialized context for instant BM25-ranked keyword lookups, snippet extraction, and trigger synchronization with automatic fallback to parameterized `LIKE` when FTS5 is compiled out.
- [x] **Strongly-Typed Log Record (`SqliteLogRecord`)**:
  - Replaced untyped row maps with `SqliteLogRecord` value model providing typed getters and backward-compatible `operator []` map indexing.
- [x] **Disk Quota Auto-Purging (`maxDiskBytes`)**:
  - Added size-based pruning (`maxDiskBytes`) alongside existing entry-count (`maxEntries`) and age (`maxAge`) pruning to strictly cap log database disk usage in constrained mobile and desktop environments using `(page_count - freelist_count) * page_size` page accounting.

---

### ✅ v0.1.7: Security, Memory Backpressure & Concurrency Hardening

**Goal**: Eliminate SQL injection risks, prevent out-of-memory errors during write storms, and eliminate concurrency races between queries and batch flushes.

- [x] **Strict Table Name Validation**:
  - Enforced identifier validation using regex `^[a-zA-Z_][a-zA-Z0-9_]*$`, eliminating SQL injection risks via untrusted table names in DDL, indexing, DML, and query statements.
- [x] **Memory Backpressure & Drop Policy (`maxBufferSize`)**:
  - Added configurable `maxBufferSize` (default: 10,000) to `SqliteSink` and `SqliteHandler`. Evicts oldest buffered log entries when write backpressure or disk latency saturates memory, preventing OutOfMemory crashes.
- [x] **Synchronous Query Flush & Reentrancy Lock**:
  - Replaced unawaited microtask flushes across synchronous query and utility APIs (`queryLogs()`, `fetchLevelCounts()`, `fetchDistinctLoggerNames()`, `count()`, `vacuum()`) with synchronous FFI transaction batching (`_flushSync()`), guaranteeing zero race conditions and eliminating stale query reads.
  - Added `_inTransaction` reentrancy guard preventing nested transaction errors during concurrent flushes.
  - Added `PRAGMA busy_timeout = 5000;` on initialization to wait out transient SQLite file locks.
- [x] **Isolate Startup Buffer Queue**:
  - Added internal pending queue in `SqliteIsolateHandler` so entries logged while the background worker isolate is spawning are preserved and drained cleanly upon startup.
  - Added handshake and error propagation completing `ready.future` on worker failure rather than hanging.
- [x] **Disposal Idempotence & Safe Serialization**:
  - Guarded all sink operations with `_ensureNotDisposed()`.
  - Added safe JSON serialization with `toEncodable: (o) => o.toString()` for context objects.
- [x] **Dependency Alignment**:
  - Aligned minimum `logd` dependency constraint to `^0.10.2`.

---

### ✅ v0.1.6: Dependency Alignment
- [x] Updated minimum `logd` dependency constraint to `^0.10.0`.

---

### ✅ v0.1.4: Async Isolate Support (`SqliteHandler.async`)
- [x] Added `SqliteHandler.async()` static factory method for non-blocking disk persistence on a dedicated background isolate.

---

### ✅ v0.1.0: Initial Release
- [x] High-performance WAL mode SQLite log sink with prepared statements, atomic transaction batching, retention pruning, and serialization registry integration.
