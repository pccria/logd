# logd Product — Session Log
> Append-only. Records high-level product release decisions, milestones, and architectural pivots.
> Never edit past entries. Add new entries at the top.

---

## 2026-11-25 | logd_markdown v0.2.0 | Maturation: CI Step Summaries, Table Digest & Multi-Dialect

- **Focus**: Phase 2 maturation of `packages/logd_markdown` for CI/CD job summaries, compact table reporting, and multi-dialect Markdown compatibility.
- **Key Deliverables**:
  - `GitHubStepSummaryHandler` & `MarkdownRunSummary`: Auto-resolves `$GITHUB_STEP_SUMMARY` via Web-safe conditional imports, tracks per-level counts and bounded `MarkdownSummaryFailure`s, and appends an executive summary table + collapsible failure block.
  - `MarkdownTableFormatter`: Emits aligned Markdown table headers (`preamble`) and rows with pipe escaping and inline JSON context cells.
  - `MarkdownDialect` (`gfm`, `commonmark`, `gitlab`): Dialect-aware callouts, alerts, and collapsible sections across formatters, encoders, and handlers.
  - Safe `MapNode` JSON encoding with `toEncodable` fallback and configurable `contextLanguage`.
  - Handler parity (`MarkdownFileHandler` / `.async()`), `registerLogdMarkdownSerializers()`, ADR-013, vault doc (`doc/vault/handler/markdown_ci_reporting.md`), Cookbook Recipe 7, and 4-scenario showcase gallery.

---

## 2026-11-25 | logd_toon v0.2.0 | Maturation: Bidirectional Parsing, LLM Budgeting & DuckDB Bridge

- **Focus**: Phase 2 maturation of `packages/logd_toon` for autonomous LLM agent telemetry, prompt context window budgeting, and analytical SQL ingestion.
- **Key Deliverables**:
  - `ToonSchema`: Structured immutable schema model with zero-allocation 8KB windowed byte scanning (`parseBytes`), bidirectional JSON serialization (`toJson`/`fromJson`), and preamble generation (`toPreamble`).
  - `ToonDecoder`: State-machine tokenizer providing bidirectional deserialization of raw TOON text and chunked streams into typed `ToonDocument` and `ToonRecord` instances with control unescaping and nested context decoding.
  - `ToonContextWindow`: Reverse-accumulating token-aware sliding-window tail slicer for LLM prompts with guaranteed preamble retention and explicit truncation notice (`-- [TRUNCATED: ...]`).
  - `ToonTokenEstimator`: Zero-dependency calibrated BPE heuristic token counter (OpenAI cl100k and Anthropic Claude compatible) and comparative JSON efficiency metrics (`ToonTokenMetrics`).
  - `ToonDuckDb`: Zero-copy DuckDB SQL generators (`selectQuery`, `createTableSql`, `ingestSql`) with automatic TOON-to-DuckDB type mapping.
  - Column Invariance (`contextColumns`): Fixed-width tabular projection across heterogeneous log events in `ToonFormatter` and `ToonFileHandler`.
  - Architecture & Knowledge Base: Authored ADR-012, vault article (`doc/vault/handler/toon_llm_telemetry.md`), modernized Cookbook Recipe 6, API reference, and 6-scenario showcase gallery.
  - Test Suite: 60 tests passing with 0 analyzer issues.

---

## 2026-11-20 | logd_sqlite v0.2.0 | Maturation: FTS5, Query Builder & Disk Quotas

- **Focus**: Phase 2 maturation of `packages/logd_sqlite` with production-grade search, query abstractions, and storage budgets.
- **Key Deliverables**:
  - Full-Text Search (FTS5) external content virtual table with automated sync triggers, BM25 relevance ranking, match snippets, token escaping, and dynamic runtime fallback to `LIKE`.
  - Type-safe `SqliteLogQuery` builder supporting log levels, hierarchical logger filtering, JSON context queries (`json_extract`), and keyset cursor pagination (`afterId`/`beforeId`).
  - Immutable typed `SqliteLogRecord` model with ergonomic getters and backwards-compatible map indexing.
  - Disk quota auto-purging (`maxDiskBytes`) with accurate freelist accounting (`page_count - freelist_count`) and chunked deletions.
  - Isolate serialization integration via `registerLogdSqliteSerializers()` and `SqliteIsolateHandler`.
  - Comprehensive 4-pillar test suites (43 tests in `logd_sqlite`, 2,282 across monorepo), interactive REPL dashboard, and live showcase examples.

---

## 2026-11-14 | v0.10.6 | Core Resilience & Serialization Stabilization

- **Focus**: Process exit safety, log injection neutralization, timezone fast-paths, zero-allocation pre-flight filtering, and monorepo CI/CD.
- **Key Deliverables**:
  - Obfuscated stack frame fallback origin resolution preventing drops in stripped/obfuscated binaries.
  - Lifecycle flush and drain contracts (`flush()`, `shutdown()`) across `LogSink`, `Handler`, and `AsyncHandler`.
  - Sequential worker event loops in isolate sinks with `errorsAreFatal: false` and bounded queues.
  - Zero-allocation pre-flight log level checks (`isLoggable`) bypassing async dispatch and future allocation.
  - Terminal control sequence neutralization (ANSI escape codes, C0/C1, and bidi override neutralization) with `LogTag.raw` / `allowSgr` opt-ins.
  - Safe indexed and timestamp-based retention rotation in `FileSink`.
  - Monorepo GitHub Actions CI matrix ([`.github/workflows/ci.yml`](file://.github/workflows/ci.yml)) testing all 7 packages, benchmarks, minimum SDK, and web stub parity.
- **PR**: #89, #90, #91, #92, #93, #94, #95, #96, #97, #98, #99 merged to `master`.

---

## 2026-10-20 | v0.10.2 | Native Engine Memory Safety & Layout Stabilization

- **Focus**: SIMD memory safety, dynamic arena slab expansion, and cross-terminal box border alignment.
- **Key Deliverables**:
  - Bounded Binary IR parsing checking `totalLength` header across all opcodes.
  - Dynamic Arena slab expansion beyond 64 KB capacity.
  - Terminal tab stop expansion (8 columns) in `TerminalLayout` and `BinaryAnsiEncoder`.
  - Satellite package security hardening (Dio cURL injection patch, Network CSWSH origin check, SQLite transaction batching, Markdown code fence scaling).

---

## 2026-10-15 | v0.10.1 | Production Cookbook, API Reference & logd_dio Launch

- **Focus**: Launch `packages/logd_dio` and comprehensive production documentation.
- **Key Deliverables**:
  - Published `packages/logd_dio` (v0.1.0) with cURL generation, body/header redaction, and `LogContext` ambient tracing.
  - Authored production cookbook (`doc/cookbook.md`) and complete public API reference (`doc/api_reference.md`).

---

## 2026-10-02 | v0.10.0 | Pure Semantic Engine & Hard Deprecation Removal

- **Focus**: Permanent removal of deprecated network files from core, achieving zero external network dependencies.
- **Key Deliverables**:
  - Permanently deleted soft-deprecated network sinks (`NetworkSink`, `HttpSink`, `SocketSink`, `HttpServerSink`, `HttpDashboardHandler`) and legacy format shims.
  - Dropped `package:http` and `package:web_socket_channel` dependencies from `packages/logd/pubspec.yaml`.
  - Core handlers streamlined to 4 essential targets (`Console`, `JsonFile`, `PlainFile`, `Memory`).

---

## 2026-09-20 | v0.9.7 | Core Decoupling & Satellite Package Expansion (ADR-008)

- **Focus**: Standalone satellite packages and direct isolate transfer.
- **Key Deliverables**:
  - Extracted `packages/logd_toon`, `packages/logd_html`, and `packages/logd_markdown` into independent packages.
  - Enabled direct SendPort transfer of `@immutable` formatters without JSON serialization.

---

## 2026-09-05 | v0.9.6 | Serialization Diagnostics & AsyncHandler Leak Safety

- **Focus**: Actionable isolate serialization errors and Finalizer lifecycle safety.
- **Key Deliverables**:
  - Clear `ArgumentError` citing missing types and registration methods in `LoggerSerializationRegistry`.
  - Proactive startup validation helpers (`verifyFormatter`, `verifySink`).
  - Dart `Finalizer` kill-safeguards attached to `AsyncHandler`.

---

## 2026-08-25 | v0.9.5 | Satellite Extraction (logd_network) & Core Deprecations (ADR-007)

- **Focus**: Decouple network sinks into standalone `packages/logd_network`.
- **Key Deliverables**:
  - Scaffolded `packages/logd_network` with dedicated unit/integration tests and interactive showcases.
  - Marked core network classes as `@Deprecated` targeting removal in `v0.10.0`.

---

## 2026-11-23 | v0.2.0 | logd_dio W3C Distributed Tracing, Bandwidth Profiling & Stream Telemetry

- **Focus**: Maturing `packages/logd_dio` to enterprise status with OpenTelemetry-compatible distributed tracing and non-buffering stream telemetry.
- **Key Deliverables**:
  - `W3cTraceContext` supporting W3C Level 1 `traceparent` (`00-${traceId}-${spanId}-${traceFlags}`) and `tracestate`.
  - `TracePropagationMode` (`both`, `w3c`, `custom`, `none`) with ambient `LogContext` inheritance and remote server trace header extraction (`extractServerTraceContext`).
  - Monotonic `HttpMetrics` tracking duration, request/response byte sizing, throughput (KB/s), and status classification.
  - Zero-buffering `StreamMetricsTracker` wrapping `ResponseBody.stream` with transparent chunk forwarding and `STREAM_COMPLETED` lifecycle events.
  - Pluggable `LogdBodySerializer` and `FunctionalBodySerializer` for Protocol Buffers, FlatBuffers, and XML.
  - HTTP error elevation (`elevateHttpErrors`) elevating 4xx to `warningLevel` and 5xx to `errorLevel` in non-throwing pipelines (`validateStatus: (s) => true`).
  - Pretty-formatted cURL (`prettyCurl: true`) with `--compressed` auto-detection.
  - Authored and adopted **ADR-011**: W3C Distributed Tracing, Bandwidth Profiling, and Zero-Buffering Stream Telemetry in Dio Interceptor.
  - Authored Architectural Knowledge Base entry `doc/vault/handler/http_inspection.md` and updated Recipe 2 in `doc/cookbook.md`.
- **PR**: #110 merged to `master`. Tagged `logd_dio-v0.2.0` and published to pub.dev.

---

## 2026-11-20 | v0.3.0 | logd_network Dual Memory Budgeting, Atomic Priority Eviction & ADR-010

- **Focus**: Maturing `packages/logd_network` with client-side memory safety, jittered transport resilience, and decoupled offline durability.
- **Key Deliverables**:
  - Dual memory budgeting enforcing both entry-count (`maxBufferSize`) and byte limits (`maxBufferBytes`).
  - Atomic headroom pre-validation in `DropPolicy.discardByPriority` eliminating uncompensated data loss.
  - `@immutable` `BackoffPolicy` with decorrelated randomized jitter to eliminate thundering-herd reconnection waves across distributed fleets.
  - Zero-copy `BytesBuilder` assembly for high-throughput NDJSON and binary streaming.
  - Authored and adopted **ADR-010**: Client-Side Dual Memory Budgeting, Atomic Priority Eviction, and Jittered Transport Resilience.
  - Published `logd_network` v0.3.0 to pub.dev.
- **PR**: #109 merged to `master`. Tagged `logd_network-v0.3.0`.

---

## 2026-08-19 | v0.9.4 | Hot-Path Origin Bypass & Ambient Structured Context (MDC)

- **Focus**: Performance optimization and Mapped Diagnostic Context (MDC).
- **Key Deliverables**:
  - `includeOrigin: false` config option bypassing `StackTrace.current` VM unwinding for ~5x throughput speedup.
  - `LogContext.run()` Zone-based ambient structured context propagation across async boundaries.
  - Zero-allocation merge semantics (`LogContext.merge()`) on baseline logging paths.
  - Full formatter integration across `StructuredFormatter`, `PlainFormatter`, `JsonFormatter`, and `ToonFormatter`.
- **Strategic Architecture Decision**:
  - Audited multi-isolate behavior following `LogContext` Zone-scoping.
  - Rejected point-patch cross-isolate pub/sub bus (`LogdIsolateHub`) in favor of a comprehensive, principled multi-isolate architecture for the **v0.10.x milestone track** before locking the API for `v1.0.0`.
  - Established dedicated knowledge item `.agents/knowledge/logd_isolate_model/` covering topology roles, configuration authority, ambient context bridging, and unified log ingestion.
- **PR**: #60 merged to `dev`; #61 open on `dev`.

---

## 2026-08-05 | v0.9.3 | Target Handlers & Dual-Mode `.async()` Offloading

- **Focus**: Beginner developer experience (DX) and pipeline wiring simplification.
- **Key Deliverables**:
  - Authored and adopted **ADR-006**: Pre-Wired `{Target}Handler` Convenience Subclass Architecture.
  - Introduced 8 zero-config target handler subclasses (`ConsoleHandler`, `HtmlFileHandler`, `JsonFileHandler`, `PlainFileHandler`, `ToonFileHandler`, `MarkdownFileHandler`, `HttpDashboardHandler`, `MemoryHandler`).
  - Added `.async()` factory constructors across all output-bound handlers for non-blocking isolate offloading (~15 µs return).
  - Created `package:logd/advanced.dart` entry point for custom engine developers.

---

## 2026-08-01 | v0.9.2 | Theme Isolate State Preservation & SQLite Satellite Package

- **Focus**: Multi-isolate state synchronization and satellite ecosystem launch.
- **Key Deliverables**:
  - Preserved `LogBrightness` across isolate transfers in `LoggerSerializationRegistry`.
  - Launched `logd_sqlite` (v0.1.0) with WAL persistence, prepared statement caching, and retention pruning.
  - Added high-contrast WCAG AA light mode palettes.

---

## 2026-07-28 | v0.9.1 | Native TOON Logging & AutoEncoder Protocol Detection

- **Focus**: Token-optimized LLM formatting and sink self-configuration.
- **Key Deliverables**:
  - Native `ToonFormatter` / `ToonEncoder` implementation and `doc/toon_spec.md` specification.
  - Protocol auto-detection via `AutoEncoder` and `'logd.encoder'` metadata contract.
  - Self-declaring `requiredStrategy` on encoders.
  - `MemorySink<T>` in-memory ring-buffer with capacity caps.

---

## 2026-07-22 | v0.9.0 | API Stabilization & Semver Contract (Phase 1 Milestone)

- **Focus**: Public symbol audit, semver breaking-change guarantees, and theme unification.
- **Key Deliverables**:
  - Audited and decorated public symbols (`@experimental` on low-level FFI/isolate engines).
  - Published `doc/semver_contract.md`.
  - Unified theme ownership under `StyleDecorator` and `document.metadata['logd.theme']`.
  - Extracted `HtmlStylesheet` from `HtmlEncoder`.

---

## 2026-07-18 | v0.8.9 | Hardening, Web Source Mapping & Roadmap Pivot

- **Focus**: Phase A Hardening completion — polymorphic serialization fix, timezone input hardening and benchmarks, concurrency stress tests, Web Source Mapping, formal ADR documentation.
- **Key Decisions Recorded**:
  - Sinks (SqlSink, MemorySink, SentrySink) are satellite package concerns. They must NOT be built until the core `LogSink` / `LogFormatter` extension points are declared `@stable`.
  - The roadmap is formally restructured into 3 phases: (1) API Stabilization → (2) Major v1.0 + Ecosystem → (3) Lean Core dependency extraction.
  - `http`, `web_socket_channel`, and `ffi` are to be extracted from core in Phase 3 as a **breaking change** requiring a major version bump. They stay in core through v1.0 with explicit deprecation notices.
  - "Gradual stabilization" was criticized as too vague. Phase 1 requires concrete deliverables: symbol annotation audit (`@stable`/`@experimental`/`@internal`), semver contract document, DX quality pass, extension point freeze.
- **Released**: `logd` v0.8.9 and `logd_linters` v0.1.2 published to pub.dev.
- **PR**: [#52](https://github.com/pccria/logd/pull/52) opened dev → master.

---

## 2026-07-08 | v0.8.7 | Concurrency & Stability Milestone

- **Focus**: Hardening VM concurrency under heavy load and final validation of the HTML encoder control panel.
- **Key Decision**: Shifted focus from starting v0.9.0 planning to core stabilization (concurrency stress testing, memory capping, auto-recovery background isolates). This ensures the engine is rock-solid before any major API overhauls.

---

## 2026-07-03 | v0.8.6 | Web Compilation Restructuring

- **Focus**: Restructured internal sub-libraries to fix a major compilation crash under browser/Web environments.
- **Key Decision**: Extracted FFI conditional stubs directly next to their VM implementations and removed all platform-specific imports from the package package-level exports. This prioritizes out-of-the-box cross-platform compliance (Web, JS, WASM).

---

## 2026-06-25 | v0.8.4 | Flutter Decoupling & Testing Harness

- **Focus**: Decoupled the logging pipeline from the Flutter SDK and added a dedicated test harness (`package:logd/testing.dart`).
- **Key Decision**: Flutter was moved to `dev_dependencies`. This allows backend CLI and server-side Dart tools to utilize `logd` without dragging the Flutter framework along. Diagnostic metrics (`LoggerMetrics`) and pooled buffers (`LogBuffer`) were introduced to provide enterprise-grade observability.

---

## 2026-06-18 | v0.8.3 | Allocation-Free hot-path optimizations

- **Focus**: CPU latency optimization and complete garbage collection (GC) pressure elimination.
- **Key Decision**: Optimized hot execution paths (`hierarchyDepth` character scanning, JIT inlining of the cache lookup check, lazy token parsing in timestamp formatter) to target 0.00 KB of heap allocations per 10k log operations.
