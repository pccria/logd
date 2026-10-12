# Handler Roadmap

## Next Milestones

### 🔲 v0.11.0: Ecosystem Maturation & Advanced Satellite Telemetry
**Goal**: Expand capabilities across satellite packages (`logd_sqlite`, `logd_network`, `logd_html`), refine performance profiling hooks, and stabilize APIs toward v1.0.0.
- [ ] Implement query builder extensions and pagination in `logd_sqlite`.
- [ ] Add compression support (gzip/zstd stream wrappers) in `logd_network` sinks.
- [ ] Introduce interactive log search and level filtering in `logd_html` standalone reports.

---

## Completed

### ✅ v0.10.0: Pure Semantic Engine & Hard Deprecation Removal
**Goal**: Permanently remove all soft-deprecated satellite shims and external dependencies from `packages/logd`, achieving a zero-network-dependency core logging engine focused on semantic IR dispatch.
**Result**: Successfully removed all network sinks (`NetworkSink`, `HttpSink`, `SocketSink`, `HttpServerSink`, `HttpDashboardHandler`, `DropPolicy`) and dropped `http` and `web_socket_channel` from `pubspec.yaml`. Removed legacy satellite format shims (HTML, Markdown, TOON) and the deprecated `requiredStrategy` getter on `LogEncoder`. Streamlined core handlers to 4 essential targets (`Console`, `JsonFile`, `PlainFile`, `Memory`).
- [x] Delete deprecated network classes (`network_sink.dart`, `http_server_sink_native.dart`, `http_server_sink_stub.dart`, `dashboard_html.dart`, `http_dashboard_handler.dart`) and remove `package:http` and `package:web_socket_channel` from `pubspec.yaml`.
- [x] Delete deprecated HTML shims (`html_encoder.dart`, `html_stylesheet.dart`, `html_file_handler.dart`, `html_formatter.dart`).
- [x] Delete deprecated Markdown shims (`markdown_encoder.dart`, `markdown_file_handler.dart`).
- [x] Delete deprecated TOON shims (`toon_encoder.dart`, `toon_file_handler.dart`, `toon_formatter.dart`).
- [x] Remove deprecated `requiredStrategy` getter on `LogEncoder`.

---

### ✅ v0.9.7: Core Decoupling, Satellite Expansion & Direct Isolate Transfer (ADR-008)
**Goal**: Complete extraction of specialized log formats into satellite packages, establish direct isolate transfer for `@immutable` formatters, and standardize `wrappingStrategy`.
**Result**: Released standalone packages `logd_toon` (v0.1.0), `logd_html` (v0.1.0), `logd_markdown` (v0.1.0), and matured `logd_sqlite` (v0.1.4). Enabled direct transfer of immutable formatters across `SendPort` to `AsyncHandler` without JSON serialization. Authored ADR-008.
- [x] Extract `logd_toon`, `logd_html`, and `logd_markdown` into standalone satellite packages.
- [x] Soft-deprecate core TOON, HTML, and Markdown classes in `packages/logd`.
- [x] Remove JSON serialization requirement for `AsyncHandler` by transferring `@immutable` formatters directly.
- [x] Add `SqliteHandler.async()` and `HttpDashboardHandler.async()` with in-isolate sink instantiation.
- [x] Authored ADR-008 in `doc/decisions/adr-008-rejection-of-handler-level-theme.md`.

---

### ✅ v0.9.6: Serialization Diagnostics & AsyncHandler Leak Safety
**Goal**: Improve developer diagnostics for custom isolate serialization and prevent zombie isolate leaks.
**Result**: Actionable `ArgumentError` messages for unregistered types, compile-time/bootstrap `verify*` assertion helpers, and Dart `Finalizer` kill-safeguards attached to `AsyncHandler`.
- [x] Actionable serialization error messages citing missing type and registration method.
- [x] Proactive startup validation helpers (`verifyFormatter`, `verifySink`, etc.).
- [x] `Finalizer`-based isolate worker termination on un-disposed garbage-collected `AsyncHandler`.

---

### ✅ v0.9.5: Satellite Package Extraction (`logd_network`) & Core Soft Deprecations (ADR-007)
**Goal**: Decouple `HttpSink`, `SocketSink`, `HttpServerSink`, and `HttpDashboardHandler` into the `logd_network` satellite package, soft-deprecating them in `package:logd` targeting `v0.10.0`.
**Result**: Scaffolded `packages/logd_network` with dedicated unit/integration tests (17/17 passing) and standalone showcases. Added `@Deprecated` annotations targeting `v0.10.0` across core network classes. Exposed `@protected isPreambleWritten` in `EncodingSink`.
- [x] Extract `logd_network` satellite package with full test suite and interactive CLI showcases.
- [x] Implement `registerLogdNetworkSerializers()` for cross-isolate configuration transfer.
- [x] Soft-deprecate core network classes targeting removal in `v0.10.0`.
- [x] Document ADR-007 and migration paths in `doc/migration.md`.

---

### ✅ v0.9.3: `{Target}Handler` Subclasses, Dual-Mode `.async()` Offloading & Advanced Entry Point
**Goal**: Introduce pre-wired `Handler` subclasses for common output targets (ADR-006), dual-mode `.async()` isolate constructors, and `package:logd/advanced.dart`.
**Result**: 8 pre-wired `{Target}Handler` subclasses (`Console`, `HtmlFile`, `JsonFile`, `PlainFile`, `ToonFile`, `MarkdownFile`, `HttpDashboard`, `Memory`), 6 `.async()` isolate constructors, `package:logd/advanced.dart` entry point, interactive showcase, and comprehensive 22-test target handler test suite.
- [x] Pre-wired 8 `{Target}Handler` convenience subclasses (ADR-006)
- [x] Dual-mode `.async()` isolate constructors across all 6 I/O handlers
- [x] Modular `package:logd/advanced.dart` entry point
- [x] Comprehensive test suite & interactive showcase

---

### ✅ v0.9.2: Theme Isolate State Preservation, High-Contrast Light Mode, Deep Hierarchy Safeguards & SQLite Ecosystem Integration
**Goal**: Preserve multi-isolate theme brightness, introduce WCAG-compliant high-contrast light mode, harden deep hierarchy resolution performance, and launch the `logd_sqlite` satellite package.
**Result**: `LogBrightness` transport across multi-isolate boundaries in `LoggerSerializationRegistry`, high-contrast palette mappings (`--warning: #92400e;`) for light mode, verified <50μs lookup across 12-level logger trees with `Logger.maxHierarchyDepth` safety limit integration, and launched satellite package `logd_sqlite` (v0.1.1).
- [x] `LogBrightness` Isolate Transport — state preservation across `AsyncHandler` and `IsolateSink` transfers
- [x] High-Contrast Light Theme Palette — WCAG AA compliant contrast ratios in `LogColorScheme.lightScheme` and `DefaultHtmlStylesheet`
- [x] Deep Hierarchy Resolution Optimization & Safeguards — <50μs lookup performance and `Logger.maxHierarchyDepth` warnings
- [x] Launch `logd_sqlite` Satellite Package (v0.1.1) — SQLite persistence with WAL mode, atomic batching, retention auto-pruning, and log query engine

---

### ✅ v0.9.1: Native TOON Support, Auto-Encoder Protocol Detection, MemorySink & Bounds Safeguards
**Goal**: Integrate TOON semantic format, auto-detect encoders, memory ring-buffer sink, bounds-capped buffer queuing, and custom symbol resolution hooks.
**Result**: Introduced `ToonFormatter`/`ToonEncoder`, protocol-aware `AutoEncoder` (`AutoConsoleEncoder`, `AutoTextEncoder`), bounded `MemorySink`, `LogBuffer.maxEntries` capacity safeguard, `SymbolResolver` deobfuscation hook, and ADRs 002–005.
- [x] Native TOON format & dialect integration (`ToonFormatter`, `ToonEncoder`, `toon_dialect.dart`)
- [x] Protocol Auto-Detect Encoders (`AutoEncoder` with standard `'logd.encoder'` contract)
- [x] In-Memory Log Sink (`MemorySink`) — bounded ring-buffering with FIFO eviction
- [x] `LogBuffer` capacity safeguards (`maxEntries` limit with diagnostic warnings)
- [x] `SymbolResolver` hook in `StackTraceParser` for stack trace deobfuscation
- [x] Authored ADRs 002–005 in `doc/decisions/`

---

### ✅ v0.8.8: Async Isolate Offloading, Web-Based Log Viewer & HTML Consolidation
**Goal**: Implement isolate-offloaded async pipeline execution, real-time web-based log dashboard streaming via WebSockets, and consolidate HTML logging.
**Result**: `AsyncHandler` offloads the full format → decorate → sink pipeline to a background isolate, `HttpServerSink` serves an embedded real-time log dashboard via WebSockets, and legacy `HtmlFormatter`/`HtmlSink` were consolidated into the high-fidelity `HtmlEncoder`.
- [x] `AsyncHandler` — isolate-backed pipeline execution with `ready` completer and graceful `dispose`
- [x] `IsolateWorker` — unified isolate lifecycle manager (spawn, recovery, teardown)
- [x] Embed loopback-bound HTTP dashboard server (`HttpServerSink`)
- [x] Real-time log streaming to served dashboard via WebSockets
- [x] Consolidate HTML logging: legacy `HtmlFormatter`/`HtmlSink` removed; `HtmlEncoder` + standard formatters is the unified path
- [x] Dynamic CSS stylesheet injection from `HtmlEncoder` directly to the dashboard

---

### ✅ v0.8.4: Decoupling, Decorator Optimization & Context Filtering
**Goal**: Resolve pure-Dart compatibility packaging issues, optimize decorator performance, introduce fallback warning diagnostics, and implement structured context filters.
**Result**: Removed Flutter dependencies/stubs, cached visible length measurements in decorators, implemented compile-time safe diagnostics in NativeEngine, and added a ContextFilter.
* **Pure Dart Decoupling**:
  - [x] Move `flutter` SDK dependency from runtime dependencies to dev dependencies (closes #44)
  - [x] Delete `flutter_stubs` files and transition logger to manual FlutterError hook setup
* **Performance Optimizations**:
  - [x] Benchmark and profile SuffixDecorator/PrefixDecorator latency
  - [x] Cache visible length calculations in static decorators (`getCachedVisibleLength`)
* **Fallback Warnings**:
  - [x] Implement one-time warning in `NativeEngine` on StandardEngine fallbacks
* **Context Filtering**:
  - [x] Implement `ContextFilter` to filter log entries by structured context key/value

---

### ✅ v0.8.3: Performance, Structured Context & Parity
**Goal**: Optimize performance bottlenecks, support structured logging context, and achieve full cross-platform compatibility on Windows.
**Result**: Fully stabilized cache and formatting hot-paths, full structured context propagation across formatters, and resolved all timezone and layout constraints on Windows.
* **Performance Optimizations**:
  - [x] Optimize `LoggerCache._resolve` with inline-friendly fast-paths
  - [x] Optimize `TimestampFormatter` token formatting by ordering by token frequency
  - [x] Make hierarchy depth calculation allocation-free by counting dots
  - [x] Introduce $O(m)$ descendant invalidation reverse-index in `LoggerCache`
* **Structured Context Support**:
  - [x] Add `Map<String, dynamic> context` to `LogEntry` / `Logger` methods
  - [x] Integrate structured context maps into all core formatters (Json, Toon, Plain)
  - [x] Add context merging and sinking to `LogBuffer`
* **Cross-Platform Parity**:
  - [x] Fix Windows path separator issues in rotation tests
  - [x] Fix golden test CRLF line-ending mismatches on Windows
  - [x] Resolve Windows timezone names to standard IANA timezone identifiers via Unicode CLDR mapping table

---

### ✅ v0.8.1: FFI Layout Parity & Stabilization
**Goal**: Achieve 100% visual layout parity between the NativeEngine and StandardEngine rendering paths.
**Result**: Verified across 2,048 differential test configurations. `BinaryAnsiEncoder` now produces character-for-character identical output to the standard ANSI path.
- [x] Implement state-aware word-wrap simulator in `BinaryAnsiEncoder`
- [x] Add `_DecoratedState` for nested decorator leading-width tracking
- [x] Harden FFI pointer bounds checking for memory safety
- [x] Introduce `three_engines_comparison.dart` benchmark on a level playing field
- [x] Archive M15 milestone record in `packages/benchmarks/records/`
- [x] Restore `StandardEngine` as the universal default engine
- [x] Fix iOS `ProcessException` on timezone fetch (closes #21)
- [x] Merge into `dev`
- [x] PR to `master` and cut `v0.8.1` / `v0.8.3` release tags

---

### ✅ v0.8.0: The Engine & Schema Milestone
**Goal**: Consolidate high-performance native rendering with AI-native structured schemas.
**Result**: Fully stabilized Standard, Arena, and Native execution engines with support for B-IR v2 serialization and TOON explicit schemas.
* **TOON Schema Maturity**:
  - [x] Define semantic `ToonType` system (iso8601, enum, markdown, etc.)
  - [x] Implement aligned, multi-line schema headers
  - [x] Add Enum introspection for log levels in schema
  - [x] Update `TerminalLayout` to detect and render explicit schemas in console
* **Engine Optimizations (Binary IR & Native Engine)**:
  - [x] Define B-IR v1 & v2 instruction stream specifications
  - [x] Implement `BinaryIRWriter` for linearized document streaming
  - [x] Create `NativeEngine` with fast-path bypassing object-tree traversal
  - [x] Standardize 16-byte B-IR header with color/padding support
  - [x] Implement `BinaryAnsiEncoder` as reference native-compatible renderer
  - [x] Achieve ~13x throughput improvement over standard heap engine
  - [x] Build golden-testing suite for complete engine parity verification
  - [x] Stabilize LIFO-based Arena memory allocation and deterministic resource release

### ✅ P0: BoxFormatter Refactoring
**Goal**: Separate visual framing from content formatting.
**Result**: Successfully split into `StructuredFormatter` and `BoxDecorator`.
- [x] Create `BoxDecorator` class implementing `LogDecorator`
- [x] Extract layout logic from `BoxFormatter` into `StructuredFormatter`
- [x] Deprecate `BoxFormatter`, provide migration guide
- [x] Add tests for decorator + formatter composition

### ✅ P0: Semantic Segment Refactoring
**Goal**: Enable granular control over log content.
**Result**: Introduced `LogLine` and `LogSegment` architecture.
- [x] Implement `LogSegment` with `Set<LogTag>` support
- [x] Update all formatters to emit `LogLine`
- [x] Implement fine-grained tagging in `StructuredFormatter`
- [x] Add `JsonPrettyFormatter` with semantic styling and customizable fields
- [x] Add MarkdownEncoder and HtmlEncoder

### ✅ P1: Shared LogField System
**Goal**: Unify data access across all formatters.
**Result**: Created `LogField` enum and extension.
- [x] Decouple field extraction from JSON/TOON formatters
- [x] Allow dynamic field selection in any supported formatter

### ✅ P0: Visual Showcase (Logd Theatre)
**Goal**: Demonstrate complex capabilities in a single interactive dashboard.
**Result**: Created `example/log_theatre.dart`.
- [x] Implement mock dashboard UI in terminal
- [x] Showcase real-time multi-handler processing
- [x] Demonstrate all border styles and coloring configurations

### ✅ P0: Centralized Layout Management
**Goal**: Consolidate layout constraints and remove redundant parameters.
**Result**: Moved `lineLength` to `Handler` and added `preferredWidth` to `LogSink`.
- [x] Remove `lineLength` from `StructuredFormatter` and `BoxDecorator`
- [x] Implement `LogSink.preferredWidth` across all sink types
- [x] Update `LogContext` to provide `availableWidth`
- [x] Migrate all examples and tests to the new model

### ✅ P0: Unified Layout Pipeline (v0.6.1)
**Goal**: Eliminate scattered output and redundant wrapping logic.
**Result**: Centralized all wrapping into the `Handler` pipeline.
- [x] Implement implicit wrapping in `Handler.log`
- [x] Add `totalWidth` and `contentLimit` to `LogContext`
- [x] Port `SuffixDecorator` to the new layout model
- [x] Fix ANSI fragment sanitation and "phantom line" bugs

### ✅ P1: Responsive Metadata Alignment
- [x] Add `alignToEnd` support to `SuffixDecorator`
- [x] Ensure suffixes respect structural (box) boundaries

### ✅ P1: Recursive JSON Inspection
- [x] Implement recursive detection in `JsonPrettyFormatter`
- [x] Add tab-to-space normalization for environmental stability

### ✅ P1: Network Sinks (HttpSink & SocketSink)
**Context**: Users require reliable network logging for centralized log aggregation and real-time monitoring.

**Result**: Implemented specialized network sinks extending `NetworkSink` base class.
- [x] `HttpSink`: POST logs to REST endpoint with batching and exponential backoff retries
- [x] `SocketSink`: Real-time WebSocket streaming with auto-reconnection
- [x] `DropPolicy` for memory-safe buffer management (`discardOldest`, `discardNewest`)
- [x] Dependency injection support for testability (`client` and `channel` parameters)
- [x] Comprehensive test coverage (8 tests passing)

### ✅ P1: Semantic Encoder Inversion (v0.6.5)
**Goal**: Decouple formatting intent from physical serialization.
**Result**: Formatter produces semantic IR (`MapNode`/`ListNode`), while `LogEncoder` handles serialization.
- [x] Implement `JsonEncoder` and `ToonEncoder`
- [x] Refactor `EncodingSink` to be protocol-agnostic
- [x] Update `ToonFormatter` and `JsonFormatter` to emit semantic documents
- [x] Fix session-aware headers via `LogEncoder.preamble(document)`

---

## Active Development

### 🟡 v0.9.3: `{Target}Handler` Convenience Subclasses & Custom Linters
**Goal**: Introduce pre-wired `Handler` subclasses for common output targets (ADR-006) and publish `logd_linters`.
**See**: [ADR-006: `{Target}Handler` Subclass Convention](../decisions/adr-006-handler-subclass-convention.md)

- [x] `ConsoleHandler` (`.async()`) — `StructuredFormatter` + `StyleDecorator(DarkTheme())` + `ConsoleSink()`; supports `theme`, `lineLength` parameters
- [x] `HtmlFileHandler(path)` (`.async()`) — correct formatter + `HtmlEncoder` + `FileSink`; `WrappingStrategy.document` wired internally, eliminating the silent-failure footgun
- [x] `JsonFileHandler(path)` (`.async()`) — `JsonFormatter` + `JsonEncoder` + `FileSink`
- [x] `PlainFileHandler(path)` (`.async()`) — `PlainFormatter` + `FileSink`
- [x] `ToonFileHandler(path)` (`.async()`) — `ToonFormatter` + `ToonEncoder` + `FileSink`; token-optimized AI log output
- [x] `MarkdownFileHandler(path)` (`.async()`) — `StructuredFormatter` + `MarkdownEncoder` + `FileSink`; GFM log reports
- [x] `HttpDashboardHandler(port)` — `StructuredFormatter` + `HtmlEncoder` + `HttpServerSink`; embedded live web dashboard
- [x] `MemoryHandler(capacity)` — `StructuredFormatter` + `MemorySink`; in-memory ring-buffer with `.entries` access
- [x] Dual-Mode Architecture & `package:logd/advanced.dart` — offloadable sinks provide `.async()` constructors, while advanced isolate/engine primitives are organized in `package:logd/advanced.dart`
- [ ] `packages/logd_linters` — publish custom lint rules warning about un-sinked `LogBuffer` instances and missing `Handler.dispose()` calls

> **Withdrawn**: The `LogOutput` facade concept (`LogOutput.console()`, `LogOutput.htmlFile()`, etc.) is withdrawn in favour of the `{Target}Handler` subclass convention. See ADR-006 for the full rationale.

---

## Features & Ecosystem Roadmap

### 🟡 P1: Async Pipeline Offloading
**Context**: `AsyncHandler` (shipped v0.8.8) offloads the full format → decorate → sink pipeline to a background isolate.

**Remaining Work**:
- [x] Benchmark `AsyncHandler` vs `StandardEngine` throughput on high-volume JSON payloads (`async_handler_benchmark.dart` & `doc/handler/async_handler_guide.md`)
- [ ] Document `AsyncHandler` wrapping of convenience subclasses in README (e.g., `AsyncHandler(ConsoleHandler())`, `AsyncHandler(SqliteHandler('app.db'))`)

---

### 🟡 P1: Satellite Ecosystem & Sinks
**Context**: Expand `logd` output destinations via the `{Target}Handler` subclass convention (ADR-006). Each satellite package provides its own `{Target}Handler extends Handler` subclass, consistent with core's naming pattern.

**Completed**:
- [x] `MemorySink`: In-memory ring-buffer for testing and in-process log inspection (`@experimental`, v0.9.1)
- [x] `SqliteHandler` / `logd_sqlite`: High-performance WAL-mode SQLite persistence satellite package ([`logd_sqlite`](file://packages/logd_sqlite), v0.1.1)

**Planned Satellite Packages — each ships a `{Target}Handler extends Handler`**:
- [ ] `logd_sentry`: `SentryHandler` — forwards structured log events and stack traces to Sentry.io
- [ ] `logd_flutter`: `FlutterOverlayHandler` — in-app UI log viewer and automatic `FlutterError.onError` / `PlatformDispatcher` hooks
- [ ] `logd_opentelemetry`: `OtlpHandler` — OTLP format exporter for Grafana Loki, Datadog, and ELK
- [ ] Core `HtmlHttpHandler` — `StructuredFormatter` + `HtmlEncoder` + `HttpServerSink` convenience subclass
- [ ] Core `MarkdownFileHandler` — `StructuredFormatter` + `MarkdownEncoder` + `FileSink`

