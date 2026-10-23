# Changelog

## 0.10.2: Native Engine Memory Safety & Layout Stabilization

This patch release hardens memory safety and pointer boundaries in `NativeEngine` and `Arena`, and resolves box border tab alignment inconsistencies across terminal viewers.

- ### Native & FFI Memory Safety (`Arena` & `BinaryIR`)
  - **Bounded Binary IR Traversal**: Added length header field (`totalLength` at header index 3) in `BinaryIRWriter`. Enforced strict buffer bounds checking on all opcodes in `BinaryAnsiEncoder` and `BinaryToonEncoder`, preventing heap out-of-bounds over-read on malformed or truncated byte streams.
  - **Dynamic Buffer Growth for Large Payloads**: In-place contiguous slab expansion in `Arena.allocateNative` ensures memory blocks remain unified when a document exceeds the initial 64 KB capacity, eliminating disjoint slab fragmentation and preserving pointer offset validity.
  - **Monotonic Allocation Counter Reset**: Wired `_totalAllocatedBytes = 0` to `Arena.clear()` and `disposeNative()`. Added pool eviction when free slabs approach `maxNativeMemory` (128 MB), preventing false `OutOfMemoryError` failures during high-throughput churn.

- ### Terminal Layout & Border Parity
  - **Box Decorator Tab Alignment**: Resolved border misalignment in `BoxDecorator` when log messages contain tab (`\t`) characters. `TerminalLayout` now expands tabs to their calculated 8-column tab stops within boxed content, ensuring consistent, flush right borders across all terminal emulators, IDE consoles, and markdown renderers.
  - **Native Engine Parity**: Synchronized tab expansion and bounds tracking in `BinaryAnsiEncoder` to maintain 100% character-level parity with `StandardEngine`.

## 0.10.1: Documentation & Developer Experience Refresh

- **Production Cookbook**: Introduced comprehensive production integration cookbook (`doc/cookbook.md`) with copy-paste recipes for Flutter zero-jank offloading, Dio HTTP inspection, Shelf microservice tracing, SQLite WAL persistence, live WebSocket dashboards, and TOON LLM agent telemetry.
- **Comprehensive API Reference**: Added catalog (`doc/api_reference.md`) documenting all public handlers, formatters, decorators, rotation policies, and satellite package APIs.
- **`package:logd_dio` First-Class Integration**: Documented the official Dio HTTP interceptor satellite package across core recipes, advanced features, and satellite package indexes.
- **README Restructuring**: Relocated pre-wired handlers to the top of the README for faster onboarding, updated Flutter recipes to modern `FlutterError.onError` and `PlatformDispatcher.instance.onError` patterns, and added architectural guidance for enterprise deployments.
- **Documentation Automation**: Added Melos `docs` task for unified `dart doc` generation across the monorepo workspace.

## 0.10.0: Pure Semantic Engine & Hard Deprecation Removal

This major milestone release completes the architectural transition of `logd` into a pure semantic logging engine. All soft-deprecated network sinks and legacy format shims have been permanently removed, eliminating all external network dependencies from the core package and establishing a zero-network-dependency core.

- ### Zero-Network-Dependency Core
  - **Permanent Removal of Network Sinks**: Removed `NetworkSink`, `HttpSink`, `SocketSink`, `HttpServerSink`, `HttpDashboardHandler`, and `DropPolicy` from `package:logd`.
  - **Pruned Dependencies**: Dropped `package:http` and `package:web_socket_channel` from `pubspec.yaml`. All network telemetry and live web dashboard features are now exclusively maintained in [`package:logd_network`](https://pub.dev/packages/logd_network).

- ### Satellite Decoupling & Shim Elimination
  - **Permanent Removal of Satellite Format Shims**:
    - **TOON**: Removed `ToonEncoder`, `ToonFormatter`, and `ToonFileHandler`. Use [`package:logd_toon`](https://pub.dev/packages/logd_toon).
    - **HTML**: Removed `HtmlEncoder`, `HtmlStylesheet`, `HtmlFormatter`, and `HtmlFileHandler`. Use [`package:logd_html`](https://pub.dev/packages/logd_html).
    - **Markdown**: Removed `MarkdownEncoder`, `MarkdownFormatter`, and `MarkdownFileHandler`. Use [`package:logd_markdown`](https://pub.dev/packages/logd_markdown).
  - **Pruned Pre-Wired Handlers**: Core `packages/logd` now focuses strictly on four fundamental handlers: `ConsoleHandler`, `JsonFileHandler`, `PlainFileHandler`, and `MemoryHandler`. Specialized targets are provided by their dedicated satellite packages.

- ### Encoder Contract Hardening
  - **`requiredStrategy` Removal**: Permanently removed the deprecated `requiredStrategy` getter from `LogEncoder` and all encoder implementations (`AnsiEncoder`, `JsonEncoder`, `PlainTextEncoder`, `AutoEncoder`). All callers and custom encoders must now use `wrappingStrategy`.

- ### Documentation & Testing Streamlining
  - **Zero-Warning Workspace Cleanliness**: Removed all obsolete `hide` clauses across downstream packages and tests, eliminating `undefined_hidden_name` analyzer warnings.
  - **Modular Test Suites**: Removed legacy format and network integration tests from core `packages/logd`, transferring full test ownership to satellite packages (`logd_network`, `logd_toon`, `logd_html`, `logd_markdown`).

---

## 0.9.7: Core Decoupling & Satellite Ecosystem Expansion

This release completes core decoupling for specialized log formats and layout strategies, establishing first-class satellite packages, modernizing isolate offloading with direct immutable transfer, and renaming internal wrapping contracts for enhanced clarity.

- ### Direct Isolate Transfer (Dart 3.7+)
  - **Zero-Serialization Worker Offloading**: Leveraged Dart 3.7+ immutable object sharing to pass `@immutable` `LogFormatter` and `LogDecorator` instances directly across `SendPort` boundaries to background worker isolates. This eliminates JSON serialization overhead and manual registry bootstrapping for pure pipeline components.

- ### Contract Rename & Deprecation: `wrappingStrategy`
  - **`requiredStrategy` → `wrappingStrategy`**: Renamed `LogEncoder.requiredStrategy` to `wrappingStrategy` for improved API readability. `requiredStrategy` is preserved as a `@Deprecated` getter shim pointing to `wrappingStrategy` and will be removed in `v0.10.0`.

- ### Core Decoupling & Satellite Package Activation
  - **`package:logd_toon`**: Activated Tab-Oriented Object Notation (TOON) as a standalone satellite package (`0.1.0`). Removed TOON-specific layout conditionals (`toon_columns`) from `TerminalLayout`, `AutoEncoder`, and `NativeEngine`. Soft-deprecated `ToonFormatter`, `ToonEncoder`, and `ToonFileHandler` in core `packages/logd`.
  - **`package:logd_html`**: Created dedicated satellite package for HTML5 log rendering (`HtmlEncoder`, `HtmlStylesheet`, `HtmlFileHandler`). Soft-deprecated HTML classes in core `packages/logd`.
  - **`package:logd_markdown`**: Created dedicated satellite package for GitHub-Flavored Markdown rendering (`MarkdownEncoder`, `MarkdownFileHandler`). Soft-deprecated Markdown classes in core `packages/logd`.
  - **Soft-Deprecated Core Shims (Targeted Removal in v0.10.0)**:
    - `HtmlEncoder`, `HtmlStylesheet`, `HtmlFileHandler` → use `package:logd_html`
    - `MarkdownEncoder`, `MarkdownFileHandler` → use `package:logd_markdown`
    - `ToonEncoder`, `ToonFormatter`, `ToonFileHandler` → use `package:logd_toon`

- ### Structural Robustness & Architectural Integrity
  - **`MapNode.toString()` & `ListNode.toString()` Unencodable Safety**: Added `toEncodable: (final object) => object.toString()` fallback to `jsonEncode` calls inside `MapNode` and `ListNode`, guaranteeing exception-free string conversion when documents carry non-JSON-encodable Dart objects (`StateError`, `StackTrace`, custom models).
  - **Rejection of `Handler.theme` (ADR-008)**: Formally documented ADR-008 to solidify theme ownership in `StyleDecorator`, preserving Single Source of Truth and semantic/physical pipeline boundaries.

- ### Testing & Regression Safeguards
  - **Golden Test Suites**: Added golden output baselines for HTML and Markdown formatting across standard and error log payloads.
  - **Engine Parity**: Added differential validation verifying output equivalence between `StandardEngine` and `NativeEngine`.

## 0.9.6: Serialization Registry Diagnostics & AsyncHandler Leak Safety

This release improves developer experience and resource safety when integrating custom pipeline components (`LogFormatter`, `LogSink`, `LogFilter`, `LogDecorator`, `LogEngine`) and background isolate handlers (`AsyncHandler`).

- ### Isolate Serialization Diagnostics (`LoggerSerializationRegistry`)
  - **Actionable Error Messages on Serialization Failure**: `serializeFormatter`, `serializeSink`, `serializeFilter`, `serializeDecorator`, and `serializeEngine` now throw `ArgumentError` messages that name the unregistered type and specify the exact registration method to call (e.g., `LogFormatter subtype "MyFormatter" is not registered in LoggerSerializationRegistry. Call LoggerSerializationRegistry.registerFormatter<MyFormatter>(...)...`). Previously the error was `Type "X" is not registered.` with no actionable context.
  - **Actionable Error Messages on Deserialization Failure**: All `deserialize*` methods now produce equivalent messages, replacing generic `Sink type "X" not registered.`-style errors with component-category-aware messages.
  - **Internal Invariant Message Fix**: `_lookupName`'s fallback error (a branch that is unreachable under correct usage) is reclassified from `ArgumentError` to `StateError` with a message identifying it explicitly as a registry bug, not a user error.

- ### Proactive Registration Validation (`verify*` helpers)
  - **`verifyFormatter<T>()`**, **`verifySink<T>()`**, **`verifyFilter<T>()`**, **`verifyDecorator<T>()`**, **`verifyEngine<T>()`**: New static helpers that satellite packages and app initializers can call at startup — after all `register*` calls — to assert that their custom types are registered before any isolate boundary is ever crossed. These throw `StateError` immediately at the call site with a clean stack trace, eliminating the class of delayed, context-free failures that would otherwise only surface during `exportConfig()` or `AsyncHandler` initialization.

- ### Resource Leak Protection (`AsyncHandler`)
  - **Finalizer Leak Safety**: Wired Dart's `Finalizer` API to `AsyncHandler` (`async_handler_native.dart`). If an `AsyncHandler` instance is garbage-collected without `dispose()` being called explicitly, the `Finalizer` callback logs an `InternalLogger.warning` and immediately terminates the underlying worker isolate via `IsolateWorker.kill()`, preventing abandoned background isolates from leaking CPU/RAM.

- ### Robustness & Defensive Guards
  - **Pattern RegExp Error Guard**: Wrapped `RegExp` construction in `Logger.configurePattern` ([logger.dart:1183-1194](lib/src/logger/logger.dart)) in a `try/catch` block. If an invalid pattern string is supplied, it now catches `FormatException` and throws a descriptive `ArgumentError` citing the pattern string directly.

- ### Testing
  - Added dedicated tests covering reactive error messages (serialization and deserialization of unregistered types), proactive `verify*` helpers (registered pass, unregistered `StateError`), `configurePattern` parameter validation, and `AsyncHandler` post-dispose safety.

## 0.9.5: Extraction of Network Sinks to Satellite Package (logd_network) & Soft Deprecations (ADR-007)

This release extracts all external network dependencies (`package:http`, `package:web_socket_channel`) into a standalone satellite package: [`package:logd_network`](https://pub.dev/packages/logd_network).

- ### Satellite Package Extraction (`logd_network`)
  - **Modular Network Telemetry**: Extracted `HttpSink`, `SocketSink`, `HttpServerSink`, `HttpDashboardHandler`, `NetworkSink`, and `DropPolicy` into `packages/logd_network`.
  - **Standalone Interactive Showcases & Test Harness**: Migrated unit and live integration tests into `packages/logd_network/test/` (17/17 passing) and created an interactive CLI gallery in `packages/logd_network/example/main.dart`.
  - **Cross-Isolate Serializers**: Implemented `registerLogdNetworkSerializers()` in `package:logd_network` for background isolate deserialization.

- ### Core Package Soft Deprecations & Boundary Protection
  - **Soft Deprecations (Removal in v0.10.0)**: Added `@Deprecated` annotations targeting `v0.10.0` on `HttpSink`, `SocketSink`, `NetworkSink`, `DropPolicy`, `HttpServerSink`, and `HttpDashboardHandler` in `packages/logd`.
  - **Encapsulation Access**: Exposed `@protected isPreambleWritten` in `EncodingSink` to allow satellite package sinks to safely format document-level preambles.
  - **Core Examples Decoupled**: Updated `packages/logd/example/` to focus cleanly on the 7 core TargetHandlers (`ConsoleHandler`, `MemoryHandler`, `JsonFileHandler`, `HtmlFileHandler`, `ToonFileHandler`, `MarkdownFileHandler`, `PlainFileHandler`), removing all local network server dependencies from core examples.

- ### Documentation & Decisions
  - **ADR-007 Authored**: Documented ADR-007 (*Satellite Package Architecture for Domain-Specific Sinks & Handlers*) in `doc/decisions/adr-007-satellite-package-extraction.md`.
  - **Migration Guide Updated**: Added `v0.9.4` to `v0.9.5` migration instructions in `doc/migration.md`.

## 0.9.4: Hot-Path Performance Optimization & Ambient Structured Context (MDC)

This release advances logd's production architecture with hot-path stack trace capture bypasses (~5x throughput speedup) for high-throughput workloads and ambient scope-based structured logging (MDC) across synchronous and asynchronous execution paths.

- ### Hot-Path Performance & Lazy Stack Trace Bypass
  - **Configurable Caller Origin (`includeOrigin`)**: Added `includeOrigin` to `LoggerConfig`, `Logger.configure`, `Logger.configureMultiple`, `Logger.configurePattern`, and `Logger.includeOrigin` getter. Defaults to `true` on the global logger for full backward compatibility.
  - **VM Stack Unwinding Bypass**: When `includeOrigin: false` and `stackMethodCount[level] == 0` without an explicit `stackTrace`, log dispatch completely bypasses `StackTrace.current` VM capture and `StackTraceParser.parse` regex matching, delivering up to a **~5x throughput gain** (~2.38 µs vs ~11.76 µs dispatch latency).
  - **Preserved Frame & Trace Invariants**:
    - When `stackMethodCount[level] > 0` is set, stack frames are collected on `LogEntry.stackFrames` without extracting caller origin headers.
    - When an explicit `stackTrace` is passed (e.g. `logger.error('Failed', stackTrace: st)`), it is preserved directly on `LogEntry.stackTrace`.
  - **Hierarchy & Serialization Integration**: Wired `includeOrigin` into hierarchy inheritance, pattern-based matching, `freezeInheritance()` / `unfreezeInheritance()`, and JSON serialization.

- ### Ambient Structured Context (MDC / `LogContext`)
  - **Zone-Based Scoped Context (`LogContext.run`)**: Introduced ambient structured context propagation using Dart's `Zone` mechanism. Callers can bind key-value pairs (such as `traceId`, `requestId`, `userId`, `tenantId`) across synchronous blocks, asynchronous `await` chains, and microtasks without manually passing `context` maps through function signatures.
  - **Scope Nesting & Hierarchical Merging**: Inner `LogContext.run` scopes automatically inherit values from enclosing outer scopes. Keys defined in deeper scopes override parent keys for the lifetime of that scope without mutating the outer context.
  - **Fast-Path Zero Allocation**: Integrated `LogContext.merge()` into `Logger.logInternal`. When no ambient or explicit context is present, dispatch performs 0 heap allocations.
  - **Seamless Formatter & Filter Integration**: Ambient context values flow directly into `LogEntry.context`, immediately accessible to `JsonFormatter`, `PlainFormatter`, `StructuredFormatter`, `ToonFormatter`, `HttpDashboardHandler`, and `ContextFilter`.

- ### Benchmarks & Diagnostics
  - **Lazy Stack & Origin Bypass Benchmark Target**: Added `packages/benchmarks/lib/lazy_stack_benchmark.dart` to measure and safeguard log dispatch throughput.
  - **Ambient Context Benchmark Target**: Added `packages/benchmarks/lib/log_context_benchmark.dart` to measure ambient zone lookup and merging overhead on the hot path.

- ### Testing & Verification
  - **Stack Bypass & Caller Origin Suite**: Added `packages/logd/test/logger/lazy_stack_trace_test.dart` and expanded `logger_serialization_test.dart`, validating origin bypass, frame collection, inheritance, freeze/unfreeze, pattern rules, and serialization roundtrips.
  - **Structured Context Test Suite**: Added `packages/logd/test/logger/log_context_test.dart` with comprehensive coverage of sync/async execution, nested scopes, concurrent event isolation, call-site overrides, filter integration, and structured JSON formatting.

## 0.9.3: Pre-Wired `{Target}Handler` Subclasses, Dual-Mode `.async()` Pipeline Offloading & Advanced Library Entry Point

This release introduces the pre-wired `{Target}Handler` convenience subclass architecture ([ADR-006](../../doc/decisions/adr-006-handler-subclass-convention.md)) to eliminate beginner pipeline wiring friction, adds dual-mode `.async()` isolate offloading constructors for non-blocking I/O, prevents state-isolation bugs by design, and introduces a dedicated `package:logd/advanced.dart` entry point for power users and custom engine developers.

- ### Pre-Wired `{Target}Handler` Convenience Subclass Architecture (ADR-006)
  - **Zero-Config Target Handlers**: Replaced multi-stage manual pipeline construction (`Formatter` + `Decorator` + `Encoder` + `Sink` + `WrappingStrategy`) with 8 pre-wired, strongly-typed `Handler` subclasses:
    - **`ConsoleHandler`**: Standard terminal/stdout logging with customizable themes (`LogTheme.dark()`, `LogTheme.light()`) and line length limits.
    - **`HtmlFileHandler`**: Encapsulates `HtmlEncoder` + `FileSink` and enforces `WrappingStrategy.document` internally, eliminating broken HTML markup issues out of the box.
    - **`JsonFileHandler`**: Outputs structured JSON with toggleable 2-space indentation (`pretty: true`) or compact single-line mode (`pretty: false`).
    - **`PlainFileHandler`**: Outputs unstyled raw text logs to disk.
    - **`ToonFileHandler`**: Generates Token-Oriented Object Notation (TOON) files optimized for AI/LLM token efficiency.
    - **`MarkdownFileHandler`**: Outputs GitHub-Flavored Markdown (`.md`) formatted logs suitable for CI/CD job summaries and release artifacts.
    - **`HttpDashboardHandler`**: Starts an embedded HTTP/WebSocket server hosting the live interactive browser dashboard.
    - **`MemoryHandler`**: Retains recent log entries in an in-memory ring-buffer with direct programmatic inspection via `handler.entries`.
  - **Single Architectural Convention Across Ecosystem**: Standardized the `{Target}Handler` naming and subclass pattern across core and all satellite packages (e.g. `SqliteHandler` in `logd_sqlite`, `SentryHandler` in `logd_sentry`).

- ### Dual-Mode Execution & Background Isolate Offloading (`.async()`)
  - **`.async()` Factory Constructors**: Added `.async()` constructors across all 6 output-bound handlers (`ConsoleHandler.async()`, `HtmlFileHandler.async()`, `JsonFileHandler.async()`, `PlainFileHandler.async()`, `ToonFileHandler.async()`, `MarkdownFileHandler.async()`).
  - **Unblocked Main Thread**: `.async()` constructors offload formatting, decoration, and physical I/O to a background worker isolate via `AsyncHandler`, returning in ~15µs to ensure zero jank in UI frameworks (Flutter) and high-throughput servers.
  - **Safety by Design for State-Bound Handlers**: Omitted `.async()` from `MemoryHandler` (retaining heap visibility on caller isolate) and `HttpDashboardHandler` (binding local socket server directly), structurally preventing cross-isolate memory disconnects and duplicate socket binds.

- ### Modular Entry Point (`package:logd/advanced.dart`)
  - **Power-User Entry Point**: Created `package:logd/advanced.dart` exporting low-level engine and isolate internals (`AsyncHandler`, `ArenaEngine`, `NativeEngine`, `IsolateSink`, `LogEngine`) for custom pipeline and engine authors.
  - **Mainstream DX Polish**: Refined `package:logd/logd.dart` to emphasize `{Target}Handler` convenience subclasses while maintaining full backward compatibility.

- ### Testing & Verification
  - **Target Handler Test Suite**: Added `packages/logd/test/handler/target_handlers_test.dart` verifying all 8 sync target handlers and all 6 `.async()` isolate pipelines with 100% test pass rate.

## 0.9.2: Theme Isolate State Preservation, High-Contrast Light Mode, Deep Hierarchy Safeguards & SQLite Ecosystem Integration

This release enhances multi-isolate theme serialization, introduces WCAG-compliant high-contrast light mode palettes, hardens deep logger hierarchy resolution performance with safety depth warnings, and launches the `logd_sqlite` satellite package ecosystem.

- ### Theme & Isolate Serialization Fixes
  - **`LogBrightness` Isolate Transport**: Fixed theme brightness state loss across multi-isolate boundaries in `LoggerSerializationRegistry`. Transferred theme configurations now preserve `brightness` state (`LogBrightness.dark` vs `LogBrightness.light`) across `AsyncHandler` and `IsolateSink` transfers.
  - **High-Contrast Light Theme Palette**: Enhanced `LogColorScheme.lightScheme` and `DefaultHtmlStylesheet` CSS generation with high-contrast amber/red/green color palette mappings (`--warning: #92400e;`) ensuring WCAG AA contrast ratio compliance on light backgrounds.

- ### Performance & Hierarchy Safeguards
  - **Deep Hierarchy Resolution Optimization**: Confirmed configuration resolution across 12-level deep logger trees completes in **< 50 microseconds per lookup**.
  - **Hierarchy Safety Limit Integration**: Verified `Logger.maxHierarchyDepth` safety warning triggers for deep logger hierarchies.

- ### Satellite Package Ecosystem Expansion
  - **`logd_sqlite` (v0.1.0)**: Released dedicated satellite package [`logd_sqlite`](https://pub.dev/packages/logd_sqlite) providing high-performance SQLite log persistence with Write-Ahead Logging (WAL mode), pre-compiled prepared statements, atomic transaction batching, auto-pruning retention policies (`maxEntries`, `maxAge`), and a rich query engine (`queryLogs()`, `fetchLevelCounts()`, `fetchDistinctLoggerNames()`).

## 0.9.1: Native TOON Support, Auto-Encoder Protocol Detection, MemorySink, LogBuffer Safeguards & Strategy Fallback


This release introduces native TOON (Tree-Oriented Object Notation) logging format and dialect engine with HTTP live dashboard integration, Protocol-Aware Auto-Detect Encoders (`AutoEncoder` with standard `'logd.encoder'` contract), in-memory ring-buffer `MemorySink`, bounds-capped `LogBuffer` queuing, self-declaring encoder wrapping strategies with fallback handling, custom symbol resolution hooks for stack trace deobfuscation, unified theme architecture, and formal Architecture Decision Records (ADRs 002–005).

- ### Native TOON Format & Dialect Integration
  - **Tree-Oriented Object Notation (`ToonFormatter` / `ToonEncoder`)**: Added native support for the TOON semantic dialect, including `ToonFormatter` for semantic IR document layout, `ToonEncoder` for string and ANSI rendering, and custom dialect token handling (`toon_dialect.dart`).
  - **HttpServerSink Live Dashboard Integration**: Upgraded the embedded HTTP log dashboard viewer to dynamically render TOON-formatted logs with interactive controls, copy buttons, dark/light theme toggling, and live WebSocket streaming.
  - **TOON Format Specification**: Documented format architecture, token rules, and layout specifications in `doc/toon_spec.md`.

- ### Log Sinks & Wrapping Strategy Fallback
  - **In-Memory Log Sink (`MemorySink`)**: Added `@experimental` `MemorySink<T>` supporting bounded in-memory ring-buffering (`capacity`), FIFO log eviction, unmodifiable log sequence inspection via `.logs`, and manual flushing with `.clear()`.
  - **Self-Declaring Encoder Wrapping Strategies**: Added `requiredStrategy` getter to `LogEncoder` base class, allowing encoders (`HtmlEncoder`, `AnsiEncoder`, `JsonEncoder`, `ToonEncoder`) to self-declare minimum wrapping strategy requirements. `EncodingSink` now automatically defaults to `encoder.requiredStrategy` when no explicit strategy is provided.
  - **Protocol Auto-Detect Encoders (`AutoEncoder`)**: Introduced `AutoEncoder` base class (`AutoConsoleEncoder`, `AutoTextEncoder`) establishing the standardized `AutoEncoder.encoderKey` (`'logd.encoder'`) metadata contract. Formatters (`ToonFormatter`, `JsonFormatter`, and custom formatters) attach their preferred physical encoder directly to `document.metadata`, enabling default sinks (`ConsoleSink`, `FileSink`, `HttpSink`, `SocketSink`) to automatically delegate to `ToonEncoder`, `JsonEncoder`, or custom encoders without requiring manual `encoder:` parameter overrides.
  - **HttpServerSink Log History Buffering & Replay**: Added `bufferCapacity` to `HttpServerSink` (default: 100) to maintain an in-memory ring buffer of recent logs and automatically replay historical events to late-connecting WebSocket dashboard clients.
  - **Defensive Width Validation**: Added a runtime assertion in `EncodingSink` ensuring `preferredWidth` is strictly positive (`preferredWidth > 0`).

- ### Log Buffer & Logger Capping Safeguards
  - **`LogBuffer` Capacity Safeguard**: Introduced `maxEntries` capacity limits to `_LogBuffer` and `LogBuffer` handle class, dropping excess oldest entries and logging diagnostic warnings via `InternalLogger` when limits are breached.
  - **Logger Convenience Helper**: Added `logger.buffer(level, {maxEntries})` API to `Logger` for creating bounded log buffers with single-call chaining.

- ### Stack Trace Parsing & Symbol Resolution
  - **`SymbolResolver` Hook**: Added `@experimental` `SymbolResolver` hook (`String? Function(String symbol)`) to `StackTraceParser` and `ParsedFrame` engine to support custom symbol demangling, native C/C++ symbol resolution, and custom obfuscation map translations.

- ### Architecture Decisions & Internal Refactoring
  - **Architecture Decision Records (ADRs 002–005)**: Authored formal ADRs documenting core design invariants for Cache Invalidation (ADR-002), Sparse Storage (ADR-003), Unmodifiable Collections (ADR-004), and Internal Logger Contracts (ADR-005).
  - **Internal Source Reorganization**: Relocated conditional platform import stubs (`io_native.dart`, `io_stub.dart`) to `src/core/context/io/` for cleaner modular project structure.
  - **Theme & ColorScheme Architecture Unification**: Unified `LogTheme` and `LogColorScheme` with explicit `LogBrightness` support (`dark`, `light`), extracted `HtmlStylesheet` from `HtmlEncoder`, and added comprehensive golden tests and theme showcases (`themes_console_example.dart`, `themes_html_example.dart`).

- ### Benchmarks & Diagnostics
  - **Async vs Standard Benchmark Target**: Added a benchmark target comparing `AsyncHandler` isolate pipeline throughput against synchronous `StandardEngine` execution.
  - **Baseline Benchmark Suite**: Recorded baseline execution metrics for `v0.9.1`.

## 0.9.0: API Stabilization, Semver Contract, DX Improvements & Theme Presets

This release marks Phase 1 of logd's roadmap, focusing on core API surface stabilization, publishing a formal Semantic Versioning contract, enhancing developer experience (DX), and standardizing light and dark terminal themes.

- ### API Stabilization & Symbol Audit
  - **Symbol Stability Annotations**: Audited public exports and decorated native/FFI and isolate components (`Arena`, `NativeEngine`, `ArenaEngine`, `HttpServerSink`, `IsolateSink`, `NativeIsolateSink`) with `@experimental` to establish clear stability guarantees.
  - **Extension Point Freeze**: Formally frozen `LogFormatter` (interface class), `LogDecorator` (sealed class), `LogSink` (base class), and `Handler` as the core stable extensibility points.

- ### Semver Contract
  - **Semver Specification**: Published `doc/semver_contract.md` detailing breaking change guarantees for stable, experimental, and internal APIs to support ecosystem and satellite package development.

- ### Developer Experience & Diagnostic Hardening
  - **Implicit Timezone Initialization Fallback**: Added graceful exception handling to implicit timezone database loading, falling back to fixed local offsets to prevent runtime initialization crashes.
  - **JSON Schema Validation**: Added explicit JSON schema validation with descriptive `FormatException` error messages for pipeline component deserialization in `LoggerSerializationRegistry`.
  - **Runtime Assertions**: Added runtime assertions for pipeline options, including non-negative `timeout` validation in `Handler`.

- ### Theming API Overhaul & Architectural Modernization
  - **Single Source of Truth Architecture**: Standardized `StyleDecorator([this.theme = const DarkTheme()])` as the sole authority for semantic tag-to-style resolution on `LogDocument`, making `theme` a positional optional parameter for cleaner DX (`StyleDecorator(LightTheme())`). `StyleDecorator` automatically attaches `document.metadata['logd.theme']` as an immutable context bus for encoders. Removed redundant `theme:` parameters from `AnsiEncoder` and `HtmlEncoder`.
  - **Unified `LogColorScheme` & `LogStyle` System Design**: Simplified `LogColorScheme` to represent a pure 5-level semantic color palette (`trace`, `debug`, `info`, `warning`, `error`). Consolidated all visual properties and tag-specific overrides into `LogStyle` (`timestampStyle`, `levelStyle`, `borderStyle`, `exceptionStyle`, etc.), eliminating redundant `*Color` tag fields following Flutter `TextTheme` design patterns. Renamed tag-based `errorStyle` to `exceptionStyle` to eliminate naming collisions with severity levels.
  - **Extracted `HtmlStylesheet`**: Decoupled CSS/JS generation from `HtmlEncoder` into an interchangeable `HtmlStylesheet` interface and default `DefaultHtmlStylesheet`.
  - **Interactive HTML UI Refinements**: Redesigned the HTML copy-to-clipboard button with glassmorphic floating pill styling, exact top/right margin alignment matching `.log-entry` content padding, and SVG checkmark feedback animations.
  - **Standard Theme Presets**: Added top-level `@immutable` theme presets (`DarkTheme`, `LightTheme`, `PastelTheme`, `HighContrastTheme`) along with `LogColorScheme` preset palettes (`darkScheme`, `lightScheme`, `pastelScheme`, `highContrastScheme`).

## 0.8.9: Web Source Mapping, Polymorphic Serialization Registry & Architecture Hardening

This release adds support for Web Source Mapping, fixes a critical polymorphic serialization registry bug under multi-isolate configurations, hardens timezone input parsing, adds multi-isolate stress testing, and introduces formal Architecture Decision Records.

- ### Web Source Mapping (Phase B)
  - **Deobfuscated Browser Stack Traces**: Enabled translation of Chrome, Firefox, and Safari stack traces back to their original Dart source files, line/column coordinates, and deobfuscated method names using standard `.js.map` source maps.
  - **Flexible Suffix Matching**: Added file path normalization to automatically resolve source maps even if the JS file's hostname, protocol, or directory structure varies.
  - **Sync Parser Integration**: Updated the synchronous stack trace parsing pipeline to dynamically query registered source maps under browser environments.
  - **Showcase Example**: Added a relocated example showcasing raw browser frame mapping back to a resolved Dart call frame.

- ### Polymorphic Serialization Fix
  - **Polymorphic Spec Typing**: Resolved a bug where custom log sinks or filters registered in multi-isolate environments failed to serialize, incorrectly matching base classes due to generic type erasure. Subtypes are now dynamically checked at runtime.

- ### Input Hardening & Timezone Benchmarks
  - **Timezone Parameter Hardening**: Hardened constructors to validate named timezone inputs, raising assertions/errors on blank, empty, or whitespace-only values.
  - **Timezone Cache Benchmarks**: Added baseline benchmarks measuring caching performance for named offsets, local offsets, and timestamp formatting.

- ### Architecture Decisions (ADR)
  - **ADR Documentation**: Created a dedicated architecture documentation index detailing core decisions ADR-001 through ADR-005 on hierarchical inheritance, cache invalidation, sparse metadata storage, unmodifiable collections, and internal logger contracts.

## 0.8.8: Async Isolate Offloading, HttpServer Viewer & HTML Concurrency

This release introduces native isolate-offloaded logging pipelines, an embedded HTTP log dashboard viewer, dynamic HTML encoding integrations, and concurrency safety hardening.

- ### Concurrency & Pipeline Engines
  - **Isolate-Backed Logging (`AsyncHandler`)**: Overhauled background isolate offloading for the formatting $\rightarrow$ decorating $\rightarrow$ sinking pipeline. Extracted isolate spawning, ready verification, and graceful teardown logic into a unified, reusable `IsolateWorker` manager.
  - **Unified Lifecycle Management**: Added a public `Future<void> dispose()` contract directly to the `Handler` base class. Hardened `AsyncHandler` and isolate sinks with a public `ready` future to await startup, complete idempotency on teardown, and prevent start/dispose race conditions.
  - **State Overhaul & Immutability**: Removed state-tracking `Expando` maps on `AsyncHandler` and `HttpServerSink` in favor of clean private instance fields, resolving memory leak risks while keeping the `@immutable` annotation constraint cleanly satisfied.
  - **Comprehensive Developer Documentation**: Documented isolate boundaries, performance tradeoffs, copy-transfer restrictions, lifecycle guides, and web-stub fallback architectures.

- ### Real-Time Server Logging
  - **Embedded Dashboard (`HttpServerSink`)**: Added a loopback-bound HTTP dashboard server hosting a real-time developer log dashboard. Supports automated WebSocket upgrade for live telemetry streaming.
  - **HtmlEncoder Integration**: Defaulted `HttpServerSink` to output raw semantic HTML5 segments directly to client browsers instead of parsing plain text ANSI codes, guaranteeing perfect layout rendering of decorators (e.g. `BoxDecorator`).
  - **Dynamic Stylesheet Injection**: Automated runtime stylesheet injection by loading the `HtmlEncoder` CSS rules directly into the served dashboard HTML wrapper page.
  - **Ready Completer**: Hardened `HttpServerSink` with a `ready` state completer to prevent race conditions during port allocation and connection binding in test environments.

- ### Showcase & Examples
  - **Isolate Offloading Comparison Showcase**: Added `example/handler/showcase/async_isolate_showcase.dart` performing a side-by-side performance check of synchronous vs asynchronous isolate-offloaded pipelines using non-blocking Future loops.
  - **Dashboard Telemetry Demo**: Added `example/handler/sinks/http_server_sink_demo.dart` streaming dynamic warning/info telemetry events using `ToonPrettyFormatter` and `BoxDecorator` to the dashboard viewer.

## 0.8.7: Core Stabilization, Concurrency Hardening & Pipeline Safety

This release focuses on codebase hardening, lifecycle guarantees, memory boundary enforcement, and multi-isolate reliability for the `logd` logging framework.

- ### Concurrency & Resource Pooling (Arena)
  - **Thread Waiter Queue**: Replaced the single waiter slot in `Arena` with a robust, concurrent FIFO waiter queue. This prevents race conditions and permanently blocked logging pipelines under high async saturation.
  - **Memory Pool Capping**: Enforced a strict maximum capacity limit (`512` objects or `1000` buffers) on all internal pools within the `Arena` to prevent memory growth spikes under heavy continuous workloads.
  - **Lazy receivePort Lifecycle**: Made the `Arena` completion ReceivePort lazy. The port is now safely closed and re-constructed on `clear()` or `disposeNative()`, eliminating leak risks and keeping VM tests clean.

- ### Pipeline Safety & Error Handling
  - **Isolate Worker Recovery**: Implemented automated crash detection and 2-second delayed re-spawning recovery in `NativeIsolateSink`, ensuring that a background worker crash does not permanently halt the pipeline.
  - **Isolate Pre-ready Capping**: Capped the startup pre-ready buffer at 200 packets, preventing out-of-memory errors on slow worker startups.
  - **Handler Execution Timeout**: Introduced optional `timeout` configurations to all `Handler` instances, enabling safe pipeline cancellation and failure tracing instead of indefinite hangs.
  - **Registry Mutation Atomicity**: Improved `configureMultiple` to validate configurations (e.g. negative stack trace counts) and stage updates atomically, preventing partial registry corruption.
  - **Rate-Limited Warnings**: Implemented a per-type failed handler warning rate limiter to prevent console logging spam when a handler fails repeatedly.
  - **Exponential Backoff Reconnect**: Added exponential backoff reconnect logic in `SocketSink` capped at 5 minutes to gracefully handle network drops.

- ### Performance Optimizations
  - **Queue-based Memory Buffering**: Swapped List-based buffers in `NetworkSink` with `Queue` to support O(1) removals.
  - **Lazy StackTrace Parsing**: Avoided capturing/evaluating `StackTrace.current` inside `logInternal` if an explicit trace is already supplied, saving CPU cycles on standard paths.
  - **Scoped Cache Invalidation**: Optimized pattern matching updates to invalidate only cached loggers affected by the pattern, avoiding full cache wipes.

- ### Testing & Diagnostics
  - **Multi-Isolate Stress Testing**: Added a concurrency stress test verifying 10,000 concurrent logs across 5 isolates with zero deadlocks or memory leaks.
  - **Descriptive Configuration Warnings**: Hardened JSON configuration parsers to raise descriptive `FormatException` on mismatched parameter types.

- ### HTML Encoder Enhancements
  - **Interactive Control Panel**: Injected real-time search filtering and interactive log level filters with matching live counter displays inside the preamble of generated HTML documents.
  - **Copy-to-Clipboard Utility**: Added an inline copy action to every log entry, supporting modern Clipboard API and fallback methods with micro-animations.
  - **Premium Typography & Aesthetics**: Leveraged Google Fonts (Outfit, Inter) alongside CSS Grid layouts to produce a high-fidelity visual layout.
  - **Contrast & Accessibility Optimization**: Implemented high-contrast color mappings (`_lightColorMap`) for light mode to meet WCAG readability standards on white backgrounds.
  - **Explicit Theme Controls**: Added the `darkMode` option to `HtmlEncoder` constructors to override background and text modes regardless of theme colors.
  - **Showcase Stability**: Overhauled example targets to purge existing files on startup, avoiding repeated preambles and corrupt append states.

## 0.8.6: Sub-Library Restructuring & Critical Web Compilation Fix

This patch release fixes a critical, long-standing issue that broke compilation under Web (JS/WASM) environments due to platform-incompatible imports of `dart:ffi` and `dart:io` in the native logging handlers.

- ### Platform Compatibility & Web Logging Fix
  - **Web Compilation Restored**: Resolved build-time crashes on Web, Dart2js, and DDC environments. Web projects can now import and use the `logd` package out-of-the-box.
  - **Co-located Platform Stubs**: Dissolved the monolithic `native_handler_stub.dart` and `native_handler.dart` files, extracting individual platform stubs to sit directly next to their native FFI implementations (e.g. `file_sink_native.dart` & `file_sink_stub.dart`).
  - **Leaf-level Conditional Exports**: Pushed platform-aware conditional exports down to the individual features (e.g. `Arena`, `FileSink`, `IsolateSink`, `NativeEngine`). The package entry point (`package:logd/logd.dart`) is now entirely platform-agnostic and contains zero conditional imports.
  - **Actionable Fallback Error Messages**: Updated all fallback stubs under browser environments to throw descriptive `UnsupportedError` messages explaining why the FFI/filesystem feature is unavailable and recommending cross-platform alternatives (e.g. `StandardEngine`, `ConsoleSink`, `HttpSink`).
  - **Robust Stack Trace Parser Package Ignoring**: Refined the stack trace parser package-filtering logic to parse the frame first and check the resolved `filePath` prefix rather than applying raw string substring matching. This prevents local scripts and test files inside monorepos (whose absolute paths contain the package name in their directories, e.g. `packages/logd/example/`) from being incorrectly ignored as framework internals, while retaining full correctness for Web/DDC package imports and browser-based HTTP/HTTPS runs.

- ### Pipeline Codebase Restructuring (DX & Maintainability)
  - **Sub-Library Refactoring**: Split the monolithic 46-part `handler.dart` part tree into 8 clean, modular sub-libraries (`document.dart`, `decorator.dart`, `filter.dart`, `formatter.dart`, `encoder.dart`, `sink.dart`, `layout.dart`, `engine.dart`).
  - **Safe Compilation Boundaries**: Enforced strict encapsulation across compiler boundaries, ensuring FFI-specific VM/Native parts do not pollute Web/JS modules.
  - **Clean Cross-Library References**: Promoted `PrintSink._staticWrite` to `@internal` public `PrintSink.staticWrite` to allow `ConsoleSink` to safely reference it across independent library boundaries.
  - **Relocated Alignment Utility**: Moved `alignment.dart` from the global `core/utils/` directory to the semantic `src/handler/document/` directory where it belongs.

- ### Stability & Testing
  - **Zero Public API Changes**: The restructuring is fully backwards-compatible for all public APIs.
  - **Refactored VM Tests**: Updated VM-only FFI tests to import the FFI implementations (`*_native.dart`) directly, resolving class name ambiguity during static analysis.

## 0.8.5: Bulk & Pattern-Based Configuration APIs

This release introduces the bulk configuration API to enable efficient, batched logger updates, as well as pattern-based configuration for wildcard matching across logger hierarchies.

- ### Core Configuration API
  - **Logger.configureMultiple**: Added a new static method `Logger.configureMultiple(Map<String, LoggerConfig> configurations)` to allow configuring multiple loggers in a single operation.
  - **Single-Pass Cache Invalidation**: Implemented `LoggerCache.invalidateMultiple` to batch descendant cache invalidations, avoiding $O(N^2)$ traversal costs and minimizing tree-walk operations.
  - **Atomic Input Validation**: Validation of all logger configurations happens atomically before any registry modifications are made, ensuring that the entire batch either succeeds or fails.
  - **LoggerConfig Export**: Exposed `LoggerConfig` in the public API (`packages/logd/lib/logd.dart`) to support programmatic configuration construction for bulk updates.
  - **Logger.configure Delegation**: Refactored `Logger.configure` to delegate to `Logger.configureMultiple` for architectural consistency.

- ### Wildcard Pattern Matching Configuration
  - **Logger.configurePattern**: Added a new static method `Logger.configurePattern(String pattern, ...)` to configure loggers matching a wildcard or regular expression pattern.
  - **Glob Wildcard Syntax**: Supports suffix matching (e.g., `*.database`), prefix/infix matching (e.g., `app.services.*`), and global wildcards (e.g., `*`).
  - **Dynamic Walker Resolution**: Evaluates pattern rules dynamically during the logger resolution path, maintaining strict hierarchical precedence while allowing newer pattern rules to override older ones.
  - **Isolate Serialization Integration**: Supported exporting and importing pattern configuration rules seamlessly across isolates via `Logger.exportConfig()` and `Logger.importConfig()`.

- ### Stack Trace & Diagnostics Enhancements
  - **Column Number Preservation**: Added `columnNumber` field to `CallbackInfo` and updated `StackTraceParser` regex/parsing logic to capture and preserve column numbers across VM, Chrome (V8), Firefox, and Safari environments for high-fidelity source map resolution and deobfuscation.
  - **Hierarchy Depth Warning**: Added a safeguard that alerts developers via an `InternalLogger` warning on first access to abnormally deep logger hierarchies (defaulting to >10 levels) to prevent potential stack overflows and performance degradation.
  - **Configurable Safety Threshold**: Introduced `Logger.maxHierarchyDepth` to customize or disable the hierarchy depth warning threshold.
  - **Isolate Coordination Documentation**: Authored a comprehensive integration guide (`doc/logger/isolates.md`) detailing how to coordinate logger configurations dynamically across worker isolates and register custom pipeline components.

## 0.8.4: Core Logger Enhancements, Web Stack Trace, Time Caching, Testing Utilities & Flutter Decoupling

This release introduces major updates to mature the core logger configuration, transports, observability, testing infrastructure, time performance caching, and cross-platform web/Windows runtime compatibility. It also decouples the logging pipeline from the Flutter SDK for pure Dart CLI/VM support, optimizes decorator layout width calculations, and adds a context filter.

- ### Core Logger & Transport
  - **LoggerConfig Immutability**: Audited and made `LoggerConfig` fully immutable using `@immutable` and final fields with a new `copyWith` method.
  - **Configuration Serialization**: Implemented `toJson()` and `fromJson()` serialization support for `LoggerConfig`, introducing `LoggerSerializationRegistry` to register and look up custom sinks, formatters, and decorators to support cross-isolate transport via `Logger.exportConfig()` and `Logger.importConfig()`.
  - **stackMethodCount Merge Semantics**: Refactored resolver logic to perform key-by-key map merges up the logger hierarchy instead of replacing the entire map.
  - **Graceful Fallback Logging**: Fallback to safe console `print` output if all configured handlers in the pipeline throw exceptions.
  - **Logger Metrics**: Added `LoggerMetrics` API to monitor cache hits, misses, drops, handler failures, and buffer allocations/releases/leaks.
  - **LogBuffer Pooling**: Implemented a LIFO `LogBuffer` pool with `Finalizer`-based leak detection to eliminate heap allocations on hot logging paths while guaranteeing abandoned buffers are safely tracked and sinked.
  - **Origin String StringBuffer**: Optimized origin builder string concatenation using a `StringBuffer` fast-path.
- ### Testing Utilities (`package:logd/testing.dart`)
  - **Test Library**: Created a dedicated testing library exposing:
    - `CaptureSink` and `CapturedLog` for capturing log entries in memory.
    - `TestLogger` wrapper to isolate logger configuration per test.
    - `hasLog` custom matcher to easily assert against captured logs.
- ### Stack Trace Module
  - **Web Stack Trace Parsing**: Implemented platform-aware stack trace parsing supporting Chrome/V8, Firefox, and Safari formats.
  - **Environment Detection**: Automatically detects standard VM vs web browser runtimes via `const bool.fromEnvironment`.
  - **Asynchronous boundary handling**: Added `includeAsyncOrigin` configuration to `StackTraceParser` to optionally track and include `<asynchronous suspension>` boundaries.
- ### Time Module
  - **Minute-Granularity Offset Caching**: Added offset caching at 1-minute granularity in `Timezone.offset` to bypass transition rule recalculations.
  - **Date-Only Optimization**: Added `Timestamp.dateOnly` factory representing ISO 8601 `yyyy-MM-dd` date formats, and implemented a static formatter cache to return formatted date strings instantly.
- ### Flutter Decoupling (Pure Dart)
  - **Complete SDK Decoupling**: Moved `flutter` from runtime dependencies to dev dependencies to eliminate compile-time and analysis-time requirements on Flutter for CLI, server, and VM environments.
  - **Stub Removal**: Removed conditional stubs (`flutter_stubs.dart` and `flutter_stubs_flutter.dart`) and the `Logger.attachToFlutterErrors` API.
  - **Manual Hook Setup**: Updated docs to guide manual integration with Flutter error handlers via `FlutterError.onError`.
- ### Performance & Platform Compatibility
  - **Windows Python Venv Support**: Fixed path resolution for starting Python servers in network examples on Windows systems by dynamically mapping `.venv/bin/python` to `.venv/Scripts/python.exe` based on the platform.
  - **Cached Decorator Layouts**: Added static length cache (`getCachedVisibleLength`) for string terminal width estimations, bypassing regex-heavy measurements.
  - **Overhead Reduction**: Reduced `PrefixDecorator` and `SuffixDecorator` rendering overhead by ~25-30% and improved `FullPipeline` throughput by ~24-32%.
- ### Diagnostics & Warnings
  - **NativeEngine Fallback Notifications**: Added a single-trigger warning via `InternalLogger` when `NativeEngine` falls back to `StandardEngine` due to formatter/sink incompatibilities.
- ### Structured Context Filtering
  - **ContextFilter Implementation**: Added `ContextFilter` to filter logs by structured context key presence or exact value matches, supporting exclusions.

## 0.8.3: Performance, Structured Context & Parity

This release introduces critical hot-path optimizations (reducing GC overhead and improving execution latency), full structured context logging support, and key cross-platform Windows compatibility refinements.

- ### Performance Optimizations
  - **Inline-Friendly Cache Resolution**: Split `LoggerCache._resolve` into a highly inlined fast-path check and a slow-path walk, reducing hot-path configuration resolution overhead.
  - **Lazy Timestamp Token Formatting**: Replaced per-log-line Map allocation with lazy, switch-case based token formatting, reordered by token frequency to optimize branch prediction.
  - **Allocation-Free Hierarchy Depth**: Replaced string-split operations with cached dot-counting to eliminate list allocations on the hot path.
  - **Throughput & Latency Gains**: Reduced `FullPipeline` latency by **~34.7%** (from `4.67 us` to `3.05 us`) and increased `Framing Squeeze` throughput by **~43.5%** (from `1,876` to `2,692` Ops/sec).
  - **Descendant Invalidation Reverse-Index**: Replaced $O(n)$ cache scanning on logger reconfigurations with an index-based $O(m)$ descendant invalidation lookup, removing cache scan overhead.
- ### Structured Context Support
  - **Context-Aware Logging**: Added support for passing arbitrary structured context maps (`Map<String, dynamic>`) to all logger levels (e.g., `logger.info('message', context: {'userId': 123})`).
  - **Multi-Formatter Integration**: Integrated structured context serialization into `JsonFormatter`, `JsonPrettyFormatter`, `ToonFormatter`, `ToonPrettyFormatter`, and `PlainFormatter`.
  - **Buffered Context Merging**: Added context support to `LogBuffer` with capabilities to set and dynamically merge context key-value pairs (via `addContext`) before sinking.
- ### Test Suite Hardening & Cross-Platform Parity
  - **Platform-Agnostic Goldens**: Normalized line endings to LF before comparing actual outputs against goldens, resolving Windows-specific CRLF test mismatches.
  - **Windows Path Separators**: Normalized path separators in file rotation sink tests to ensure robust path checks on Windows.
  - **Cross-Platform Temp Directories**: Switched `clock_native_test.dart` to use `Directory.systemTemp` instead of hardcoded `/tmp` paths.
  - **Graceful Network Integration Skipping**: Enhanced Python integration tests to dynamically detect Python executables and fallback safely, skipping tests cleanly when missing dependencies.
  - **Windows Timezone Resolution**: Added a comprehensive Unicode CLDR-based mapping of Windows timezone names to standard IANA timezone identifiers, enabling correct local timezone resolution and preventing invalid location warnings/exceptions on Windows.

---

## 0.8.2: Logger Inheritance Maturation & Diagnostics

This release delivers the maturation of the logger hierarchical inheritance control and diagnostics features.

- ### Inheritance System Control
  - **Selective Unfreeze**: Added `fields` filter to `Logger.unfreezeInheritance()`, allowing restoring dynamic propagation on specific fields (like `logLevel`) while keeping others frozen.
  - **Descendants-Only Unfreeze**: Added `includeSelf` toggle to `Logger.unfreezeInheritance()`. Passing `includeSelf: false` applies unfreezing strictly to descendants of the target logger.
  - **Force Re-snapshot**: Added `force: true` to `Logger.freezeInheritance()`, enabling re-freezing currently frozen fields with updated ancestor configurations, while leaving explicit configuration overrides intact.
  - **Write Tracking**: `Logger.freezeInheritance()` now returns the total count of field configuration changes written across all descendants (returns `0` if it was a complete no-op).
  - **Production Reset & Subtree Clear**: Added static `Logger.reset([String? loggerName])` to reset the entire logger registry (or a specific namespace subtree) and invalidate caches, replacing the internal `@visibleForTesting` `clearRegistry()`.

- ### Diagnostics & Monitoring
  - **Hierarchy Visualization**: Added `Logger.formatHierarchy()` to compile a visual text representation of the registered logger tree, with annotations for explicit/frozen settings and actual effective values.
  - **Hierarchy Redirection**: Enhanced `Logger.printHierarchy()` to accept an optional `sink` function, routing through `InternalLogger.debug` by default.
  - **Effective Value Export**: Enriched `Logger.exportHierarchy()` to include a JSON-serializable `effective` dictionary mapping all resolved primitive properties, formatters, and handler definitions.
  - **Ghost Node Detection**: Added `'implicit'` key in exported metadata to identify lazily-instantiated loggers. Added warnings when `freezeInheritance()` is called on an implicit node or when `configure()` erases a frozen field state.

---

## 0.8.1: FFI Layout Parity & Stabilization

This patch stabilizes the `NativeEngine` rendering pipeline to achieve full visual parity with the Standard Dart-based engine across all supported layout configurations.

- ### NativeEngine / BinaryAnsiEncoder Stabilization
  - **100% Layout Parity**: `BinaryAnsiEncoder` now produces character-for-character identical output to the standard `AnsiEncoder` across a differential matrix of **2,048 test configurations** (varying widths, formatters, and decorators).
  - **State-Aware Word Wrapping**: Implemented a `wrapSegmentText` simulator inside `BinaryAnsiEncoder` that correctly models line-break budgets and segment continuations under tight width constraints.
  - **Nested Decorator Tracking**: Added `_DecoratedState` to track `leadingWidth` accumulation across nested `PrefixDecorator` and `BoxDecorator` boundaries, ensuring indentation is geometrically consistent with the standard path.
  - **Memory Safety**: Confirmed zero memory corruption or leaks under high-throughput stress runs; FFI pointer bounds checking hardened throughout the encoder.

- ### Benchmarking Infrastructure
  - **Three-Engine Comparison**: Introduced `three_engines_comparison.dart` using a `BenchmarkEncodingSink` to measure fully synchronous, end-to-end pipeline throughput across all three engines on a level playing field.
  - **M15 Milestone Record**: Archived the layout parity verification results in `packages/benchmarks/records/M15_FfiLayoutParity.md`.

- ### Fixes & Cleanup
  - Reverted `NativeEngine` as the `Handler` default; `StandardEngine` remains the universal default engine.
  - Corrected `NativeEngine` documentation to reflect **opt-in** production-ready status with 1.5x throughput advantage in layout-heavy scenarios (narrow word-wrapping).
  - **iOS Timezone Crash (issue #21)**: `clock_native.dart` now uses `DateTime.now().timeZoneName` as the primary, process-free timezone source on iOS. `Process.runSync` (used by `systemsetup` and symlink resolution) is sandbox-prohibited on iOS, causing a `ProcessException` on every log call. The fix avoids all process and filesystem access on iOS while preserving the existing macOS symlink + `systemsetup` fallback chain intact.
  - Applied project-wide `dart format` and resolved all outstanding lint warnings.

---

## 0.8.0: The High-Performance Engine Milestone

This milestone introduces a significant leap in logging performance by introducing a **Binary IR (B-IR)** pipeline, an **FFI-ready** execution engine, and an **Arena** object recycling engine. It also matures the **TOON Schema** system for improved AI-agent interoperability.

- ### High-Performance Engine & Binary IR
  - **StandardEngine (Default)**: Leverages standard Dart GC heap, ensuring out-of-the-box cross-platform support (including Web, Desktop, Mobile, and VM).
  - **ArenaEngine (Opt-In)**: Uses isolate-local LIFO object pooling to eliminate GC pressure. Ideal for complex logs with many decorators.
  - **NativeEngine (Opt-In)**: A VM-only execution engine targeting native platforms via B-IR. Achieves up to **10,000+ ops/sec** (1.5x speedup during narrow terminal wrapping) under level-playing-field synchronous benchmarks using direct native C-heap serialization.
  - **Binary IR (B-IR) v1**: A linearized, language-agnostic instruction stream designed for zero-copy FFI compatibility.
  - **Arena Pooling**: Hardened isolate-local object pooling for `ArenaDocument` and `LogNode` types, ensuring zero-allocation steady-state logging with restored semantic integrity.
  - **BinaryAnsiEncoder**: A reference native-compatible renderer that processes B-IR streams in a single pass.
  - **Fallback Safety**: Implemented robust fallback logic in `NativeEngine` to ensure compatibility with non-encoding sinks (e.g., `_MemorySink`).

- ### TOON Schema Maturity
  - **Semantic ToonType System**: Introduced specialized types (`iso8601`, `enum`, `markdown`, `stacktrace`) for rich, self-describing log schemas.
  - **Aligned Schema Headers**: Implemented multi-line, aligned schema headers for improved human and machine readability.
  - **Enum Introspection**: Automatic extraction of log level enums into the schema header.

- ### Architectural Cleanup & Breaking Changes
  - **LogDocument Abstraction**: Refactored `LogDocument` to an abstract class to support specialized engine implementations. Users should now use `StandardDocument` or `factory.checkoutDocument()`.
  - **Standardized B-IR Header**: Aligned packet structure to 16-byte boundaries (including reserved `color` field) for consistent native memory alignment.
  - **Isolate Readiness**: (Planned) Architecture prepared for zero-latency offloading of rendering to background isolates.

---

## 0.7.1: The Flutter Visibility Fix (Critical Patch)

This patch addresses a critical visibility issue where logs were invisible in Flutter IDE consoles (VS Code, Android Studio) due to `ConsoleSink` relying exclusively on `stdout`.

- ### Critical Fixes & Visibility
  - **Automatic Print Delegation**: Enhanced `ConsoleSink` to automatically switch its output mechanism to `print()` when running in a Flutter environment (`dart.library.ui`) or in non-terminal environments (standard for IDE consoles).
  - **Environment Awareness**: Improved `AutoConsoleEncoder` and `ConsoleSink` to gracefully handle environments where `io.stdout` is unavailable or restricted.
  - **Manual Override**: Added `usePrint` parameter to `ConsoleSink` for explicit control over output delegation.

- ### Architectural Refinement
  - **PrintSink Identification**: Introduced `PrintSink` as a dedicated, byte-to-string bridge for `print()`-based output.
  - **API Surface Protection**: Marked `PrintSink` as `@internal`, ensuring the public API remains clean while providing robust internal delegation for `ConsoleSink`.

---

## 0.7.0: [RETRACTED] The Architectural Inversion & Performance Milestone

> [!CAUTION]
> **REVISION NOTICE**: v0.7.0 was retracted shortly after release due to a critical regression where logs were invisible in Flutter IDE consoles. Users are strongly advised to upgrade to **v0.7.1**.
 
This milestone represents a complete overhaul of the `logd` logging pipeline, transitioning from a string-centric model to a zero-allocation, byte-oriented, and semantic-IR-driven architecture. It consolidates all development phases originally intended for 0.6.5.
 
> [!WARNING]
> **Breaking Changes & Architectural Inversion**
> - **SDK Requirements**: `logd` 0.7.0+ now requires **Dart 3.6.0+** to support monorepo workspace configurations and modern language features.
> - **Structural Reorganization**: Internal handler components relocated to domain-specific sub-modules: `document/` (Semantic IR), `layout/` (Physical Rendering), `engine/` (Orchestration), and `decorator/` (Transformation). Direct imports of internal files will break.
> - **Pipeline Factory Transition**: The legacy `LogNodeFactory` has been replaced by the unified `LogPipelineFactory`. All custom formatters and sinks must update their signatures to accommodate the new factory type.
> - **LogContext Removal**: The `LogContext` class and its parameters have been removed from the entire pipeline (`format`, `decorate`, `output`). Metadata is now handled via `LogLine` and `LogDocument` IR.
> - **Width Authority Inversion**: The `lineLength` constraint now originates from `LogSink` (e.g., `ConsoleSink`, `FileSink`), allowing handlers to be completely width-agnostic.
> - **Engine Orchestration**: The `Handler` no longer manages the processing lifecycle directly; it delegates execution to an exchangeable `LogEngine`. Low-level handler overrides require migration.
> - **Encapsulation**: Marked `Handler.log` and `LogEntry` constructor as **`@internal`** to prevent direct manipulation of the internal pipeline.
> - **HTML Encoder**: The legacy `HtmlFormatter` has been removed. All HTML generation is now handled by the high-fidelity `HtmlEncoder`, which can be paired with any standard formatter (e.g., `StructuredFormatter`, `JsonFormatter`) to produce GFM reports.
> - **Markdown Inversion**: The legacy `MarkdownFormatter` has been removed. All Markdown generation is now handled by the high-fidelity `MarkdownEncoder`, which can be paired with any standard formatter (e.g., `StructuredFormatter`, `JsonFormatter`) to produce GFM reports.
 
- ### Handler Module & Execution Engines
  - **Modular Architecture**: Relocated the handler internal suite into domain-specific modules: `document/` (Semantic IR), `layout/` (Physical Rendering), `engine/` (Orchestration), and `decorator/` (Transformation).
  - **Execution Engine Abstraction**: Extracted the core logging lifecycle from `Handler` into the `LogEngine` interface. Users can now choose between `StandardEngine` (heap allocation) and `ArenaEngine` (zero-allocation LIFO pooling) via `Handler.configure()`.
  - **Resource Pooling (Arena)**: Introduced `Arena` as an isolate-local object pool for `LogDocument` and all node types, eliminating GC pressure in high-throughput steady-state logging.
  - **Unified Resource Management**: Introduced `LogPipelineFactory` as the sole authority for allocating IR nodes, allowing engines to swap allocation strategies without modifying formatter logic.
 
- ### Byte-Oriented Pipeline & Serialization Inversion
  - **Zero-Churn Serialization**: Refactored the entire encoding pipeline (`Ansi`, `Json`, `Toon`, `Html`) to write directly to shared `Uint8List` buffers, drastically reducing temporary string churn.
  - **Buffer Recycling**: Introduced `HandlerContext` to manage pooled byte buffers, enabling zero-allocation buffer acquisition during steady-state logging when combined with `ArenaEngine`.
  - **Sink Modernization**: Standardized `LogSink` to operate on byte streams. Optimized `ConsoleSink` and `FileSink` for direct byte output to `stdout`.
  - **FastStringWriter**: Added high-performance byte-constant utility for pre-encoded ANSI and structural tokens.
 
- ### Semantic Layout & Geometric Rendering
  - **Deep Semantic IR**: Completely decoupled visual intent from physical serialization. Formatters now emit a pure semantic tree (`LogDocument`), which is then processed by the geometric layout engine.
  - **TerminalLayout Authority**: Centralized all physical wrapping, TAB-stop calculation, and ANSI segment slicing within the `TerminalLayout` engine.
  - **High-Fidelity HTML Pipeline**: A full Implementation of the semantic rendering pipeline for browsers, providing high-fidelity visual parity with terminal output.
  - **ANSI Resilience**: Improved width calculation accuracy for complex ANSI sequences and double-width characters.
 
- ### Performance, Benchmarking & Infrastructure
  - **Monorepo Migration**: Converted the project into a structured monorepo using Dart workspaces, separating core logic from benchmarks and examples.
  - **Performance Ledger**: Introduced a centralized ledger in `packages/benchmarks/records/README.md` for tracking architectural performance milestones, including the Milestone 11 Arena vs Standard comparison showing up to 49% throughput gains.
  - **AOT Stress Test Suite**: Developed a high-throughput validation suite (`stress_test.dart`) for baseline performance monitoring.
  - **Bitmask Optimizations**: Leveraged `int` bitmasks for `LogTag` handling, significantly reducing overhead in hot path processing.
  - **Agentic Development**: Integrated specialized `.agents` workflows and development rules to standardize AI-assisted coding and architectural integrity across the monorepo.
 
- ### Specialized Formats & Inspection
  - **GFM Markdown Pipeline**: Introduced `MarkdownEncoder` with comprehensive mapping for all `LogNode` types.
    - **Header Flattening**: Consolidates multiple semantic headers (Timestamp, Level, Logger) into a single, elegant `###` line with ` • ` separators.
    - **Aesthetic Refinement**: Optimized vertical whitespace, high-fidelity GFM alerts for errors, and thematic separators (`---`) for professional report generation.
    - **Collapsible Detail Blocks**: Supports `<details>` sections for stack traces and complex payloads.
  - **TOON Hierarchy**: Introduced Token-Oriented Object Notation (TOON), integrated in both flat-row (`ToonFormatter`) and recursive (`ToonPrettyFormatter`) variants for LLM efficiency.
  - **Intelligent JSON Inspection**: `JsonPrettyFormatter` now features recursive detection and pretty-printing of stringified JSON objects nested within lines.
  - **Advanced Layout Features**: Added adaptive stacking (threshold-driven wrapping), composite compaction for maps/lists, and structural safety guards (`maxDepth`).
 
 
## 0.6.4: LogBuffer Enhancements & Project-Wide Refactor
- ### LogBuffer Enhancement & Safety
  - **Error/StackTrace Support**: Added ability to capture `error` and `stackTrace` within `LogBuffer` for more robust multi-line error reporting.
  - **Deterministic Sinking**: Changed default behavior to `autoSink: false` in `Logger.infoBuffer` and related utilities to encourage explicit lifecycle management.
  - **Leak Traceability**: `LogBuffer` now captures and reports the creation stack trace when a buffer is leaked (abandoned without sinking), facilitating rapid debugging of resource leaks.

## 0.6.3: Optimized Stack Trace Parsing & Logger Robustness
- ### Optimizations
  - **Single-Pass Parsing**: Introduced a unified `StackTraceParser.parse` method that extracts both the caller and required stack frames in a single pass, eliminating redundant processing.
  - **Regex Caching**: Implemented class-level caching for stack frame regular expressions to minimize compilation overhead.
- ### Robustness & Validation
  - **Configuration Guards**: Added strict input validation to `Logger.configure`, rejecting negative stack counts and empty handler lists with clear error messages.
  - **Inheritance Efficiency**: Optimized `freezeInheritance` to track actual state changes, skipping expensive cache invalidations when descendant configurations are already fully defined.
  - **Null Message Stability**: Standardized behavior for `null` log messages (converted to empty string) and explicitly documented this behavior in the API.
- ### Refactoring & Quality
  - **Module Reorganization**: Refined the `stack_trace` module structure, moving `StackFrameSet` to a dedicated file and standardizing the parsing API.
  - **Documentation Refresh**: Comprehensively updated roadmap, architecture, and philosophy documents to align with the latest performance and structural improvements.


## 0.6.2: Resilient Network Logging & Timezone Standardization
- ### Features
  - **Network Sinks**: Introduced `HttpSink` and `SocketSink` for robust remote logging.
    - Supports configurable retries, batching, and timeout handling.
    - Compatible with all standard formatters (JSON, semantic formatters).
    - Includes `SocketSink` for TCP/UDP logging (experimental/advanced usage).
- ### Robustness & Standardization
  - **Timezone Engine Overhaul**: Replaced the custom timezone implementation with the industry-standard `package:timezone`.
    - **Standard Integration**: Leverages the official IANA Time Zone Database via `package:timezone`.
    - **Robust Caching**: Implemented a caching layer for `Timezone.local` and `Timezone.named` to eliminate expensive database lookups on every log call.
    - **Web Support**: Fixed compilation issues on Web platforms (`clock_web.dart`). 
  - **Timezone Initialization**: Added `Timezone.ensureInitialized()` for explicit control over timezone database loading.
- ### Fixes
  - **Timezone Resolution**: Fixed an issue where `timezone` fetching could fail or produce repetitive error logs on iOS devices.
  - **Web Platform**: Resolved a `MissingPluginException` and compilation errors related to `clock_web.dart`.

## 0.6.1: Unified Formatter Configuration & Layout Stability

### Breaking Changes
- **Removed `BoxFormatter`**: Finalized the removal of the deprecated `BoxFormatter` in favor of the more flexible `StructuredFormatter` + `BoxDecorator` composition.
- **`LogMetadata` Transition**: Replaced the `LogField` enum with a more focused `LogMetadata` enum (`timestamp`, `logger`, `origin`). 
- **Internal API Shields**: Marked `Handler.log` and the `LogEntry` constructor as **`@internal`** to protect the internal data model while promoting the high-level `Logger` API.

### Enhancements & Features
- **Unified Formatter API**: All formatters now accept a `Set<LogMetadata>` in their constructors, providing a consistent interface for controlling contextual data output while preserving core content (`message`, `level`, `error`).
- **Introducing `SuffixDecorator`**: A new decorator for appending text to log lines, featuring an **aligned mode** to right-justify suffixes against the terminal or box edge.
- **Intelligent JSON Inspection**: `JsonPrettyFormatter` now features recursive detection and pretty-printing of stringified JSON objects nested within messages.
- **Markdown Redesign**: `MarkdownFormatter` now produces high-fidelity output with a single h1 heading, blockquotes for messages, and collapsible (`<details>`) sections for stack traces.
- **Toon & Plain Enhancements**:
  - `ToonFormatter`: Now supports multiline content and separate metadata/field streams.
  - `PlainFormatter`: Reworked with a flow-based layout that correctly wraps long messages and errors containing metadata.
- **Styled Decorators**: `PrefixDecorator` and `HierarchyDepthPrefixDecorator` now support applying a `LogStyle` for high-fidelity semantic coloring.

### Layout & Architecture
- **Centralized Layout Logic**: Text wrapping is now handled implicitly by the `Handler` pipeline, ensuring structural decorators like `BoxDecorator` never receive overflowing lines.
- **Decorator `paddingWidth`**: Decorators can now declare their visual footprint, allowing the `Handler` to calculate precisely how much space is available for the primary log content.
- **Expanded `LogContext`**: Added `totalWidth` and `contentLimit` properties to provide decorators with definitive spatial constraints for precise alignment.
- **Dynamic Hierarchy Depth**: `LogEntry` now computes its `hierarchyDepth` dynamically from the `loggerName`, guaranteeing that visual indentation always reflects the actual logger tree.

### Stability & Fixes
- **Robust ANSI Utilities**: Significant improvements to `visibleLength` (including tab expansion) and a new `wrapWithData` utility that preserves semantic segments across line breaks.
- **Pure-Dart Compatibility**: Eliminated leaked `package:flutter_test` dependencies from the core library.
- **Layout Artifact Removal**: Fixed redundant ANSI reset sequences that caused "phantom" empty lines in narrow terminal widths.

## 0.6.0: LLM-Optimized Logging & Shared Data Model

### Breaking Changes
- **Styling Engine Overhaul**: Replaced the terminal-bound `AnsiColorConfig` and `AnsiColorScheme` with a platform-agnostic **`LogTheme`** system. Visual intent is now decoupled from platform representation.
- **Unified Formatter API**: Standardized metadata extraction via the **`LogField`** enum. 
  - **Removed**: Individual boolean flags (e.g., `showLevel`, `includeTime`) in `JsonFormatter` and `ToonFormatter`.
  - **Note**: Customizable field support for legacy formatters is planned for future versions.
- **Strict Logger Naming**: Enforced deterministic hierarchy traversal via name validation (regex: `^[a-z0-9_]+(\.[a-z0-9_]+)*$`) and automatic normalization to lowercase. This prevents "Ghost Hierarchies" caused by case sensitivity or invalid characters.
- **Decorator Migration**: `ColorDecorator` is now a deprecated alias for **`StyleDecorator`**. All visual transformations now flow through the `LogTheme` resolution logic.

### Major Overhauls & Features
- **ToonFormatter (LLM-Native)**: Introduced **Token-Oriented Object Notation (TOON)**, a header-first streaming format optimized for AI agent context efficiency.
- **Semantic Styling Pipeline**: The internal pipeline now emits rich **`LogStyle`** metadata. Sinks are now responsible for final rendering (e.g., translating `Bold` and `Dim` into ANSI codes or CSS classes).
- **Style Resolution Precision**: Enhanced `JsonPrettyFormatter` to correctly tag and style nested JSON values by mapping them to their corresponding `LogField` types.
- **Shared Field Logic**: Core log metadata (Timestamp, Level, Logger, Message, Error, StackTrace) is now extracted via a centralized, type-safe provider used by all modern formatters.

### Documentation Suite
- **Technical Manuals**: Completely rebuilt the `doc/` module with high-precision architectural guides:
  - **[Architecture](../../doc/handler/architecture.md)**: Details the 4-stage pipeline and operational context (`LogContext`).
  - **[Migration Guide](../../doc/migration.md)**: Outlines the transition from monolithic "God Components" to decentralized behaviors.
  - **[Philosophy](../../doc/logger/philosophy.md)**: Documents foundational principles like Hierarchical Inheritance and Lazy Resolution.
  - **[Decorator Composition](../../doc/handler/decorator_compositions.md)**: Explains execution priority and data-model flow.
- **Roadmap Pivot**: Updated future priorities to include **Structured Context Support** and a **Web-Based Logd Dashboard**.

 
## 0.5.0: Centralized Layout & Rigid Alignment
- ### Core Architecture & Layout
  - **Centralized Layout Management**: Introduced a rigid layout system where `Handler.lineLength` acts as the primary constraint, falling back to `LogSink.preferredWidth` (e.g., 80 for Terminal, dynamic for others)
  - **LogContext Evolution**: `LogContext` now carries `availableWidth`, serving as the single, authoritative source of truth for all layout calculations in formatters and decorators
  - **Parameter Cleanup**: Removed deprecated and redundant `lineLength` parameters from `StructuredFormatter`, `BoxDecorator`, and `BoxFormatter` to enforce centralized control and reduce API surface
- ### Component Enhancements
  - **Const-Friendly Decorators**: Migrated `BoxDecorator` and `JsonPrettyFormatter` to `const` constructors where possible, improving initialization performance
  - **Logical Segment Tags**: Added `LogTag.prefix` to support specialized content prefixes from `PrefixDecorator`, providing better isolation from header coloring
  - **PlainFormatter Refinement**: Improved multi-line message handling in `PlainFormatter` to yield distinct segments, preventing structural breaks during decoration
- ### Quality & Safety
  - **Width Clamping**: Consistent width clamping across the pipeline ensures stability even with extremely narrow terminal configurations
  - **Comprehensive Test Migration**: Full coverage of the new layout model in `null_safety_test.dart`, `layout_safety_test.dart`, and `decorator_composition_test.dart`

## 0.4.2: Semantic Segments & Visual Overhaul
- ### Core Architecture & Structure
  - **Directory Overhaul**: Centralized internal modules under `lib/src/core/` (coloring, context, utils, logger, time, stack_trace) for cleaner package organization
  - **Semantic Tagging Engine**: Migrated the entire pipeline to a segment-based architecture. Formatters now emit `LogLine` objects composed of `LogSegment`s with rich semantic tags (`LogTag`)
- ### New Formatters & Sinks
  - **JsonSemanticFormatter**: Outputs structured JSON containing both raw data and semantic metadata for programmatic analysis
  - **MarkdownFormatter**: Generates beautifully structured Markdown with support for headers, code blocks, and nested lists
  - **HTMLFormatter & HTMLSink**: Dedicated system for producing semantic HTML logs with customizable CSS mapping for browser visualization
- ### Visual Enhancements
  - **Advanced Header Wrapping**: `StructuredFormatter` now intelligently wraps long headers (logger names, levels, timestamps) while preserving fine-grained semantic tags where possible
  - **Expanded Color System**: Refined `ColorScheme` and `ColorConfig` to leverage semantic tags for precise, multi-layered coloring
- ### Developer Experience
  - **Logd Theatre Showcase**: A new flagship example (`example/log_theatre.dart`) providing an interactive, "dashboard-style" demonstration of the entire library capability
  - **Test Rationalization**: Consolidated the fragmented edge-case test suite from 16 files into 5 high-impact safety suites, improving test speed and maintainability
- ### Maintenance & Fixes
  - **Version Correction**: Unified versioning across documentation and package metadata
  - **General Stability**: Fixed several edge-case wrapping bugs in `StructuredFormatter` and `BoxDecorator`

## 0.4.1: Handler Robustness & Stability
- ### Critical Bug Fixes
  - **FileSink Race Condition:** Implemented mutex-based synchronization to serialize concurrent writes, preventing data loss during rapid logging
  - **TimeRotation Accuracy:** Fixed timestamp tracking by updating `lastRotation` after successful writes, ensuring correct rotation triggers
  - **Rotation Error Resilience:** Enhanced error handling to continue writing to original file when rotation fails, preventing data loss
  - **BoxDecorator Width:** Fixed internal content width calculation (`lineLength - 2`) and added width clamping to prevent crashes
  - **PlainFormatter Multi-line:** Now joins multi-line messages to prevent format breaks in file logs
- ### ANSI Code Handling
  - Added `wrapVisiblePreserveAnsi()` to maintain ANSI styles across line breaks, fixing style loss in wrapped content
  - Added `padRightVisiblePreserveAnsi()` to ensure padding inherits styling, preventing visual gaps in colored headers
  - Introduced `AnsiColorScheme` and `AnsiColorConfig` for structured color customization
  - Replaced boolean `colorHeaderBackground` with explicit `AnsiColorConfig(headerBackground: true)`
- ### Robustness & Idempotency
  - Width clamping in `StructuredFormatter` and `BoxDecorator` prevents negative width crashes
  - `BoxDecorator` idempotency check prevents nested box decorations
  - Fixed `LogBuffer` to avoid unnecessary stack trace creation during sink
- ### Examples & Documentation
  - Added 17 comprehensive examples covering basic setups, formatters, decorators, sinks, filters, and edge cases
  - Updated `docs/handler/README.md` with color customization and edge case handling info
  - Added migration guide for `BoxFormatter` and color configuration changes
- ### Test Coverage
  - Added 13+ edge case test files validating concurrency, null handling, Unicode, ANSI codes, extreme widths, rotation timing, and error handling
  - Over 2,400 new lines of test code ensuring robust behavior under edge conditions

## 0.4.0: Context-Aware Decorators & Visual Refinement
- ### Context-Aware Decoration Pipeline
  - **Full Context Access:** `LogDecorator.decorate()` now accepts the full `LogEntry` object, granting decorators access to metadata like `hierarchyDepth`, `tags`, and `loggerName` for smarter transformations.
  - **Automatic Composition Control:** The `Handler` automatically sorts decorators by type (Transform → Visual → Structural) to ensure correct visual composition, with deduplication to prevent redundant processing.
- ### Visual Refinements
  - **Independent Coloring:** `BoxDecorator` now supports its own `useColors` parameter, allowing the structural border to be colored independently of the content. `ColorDecorator` can now be focused purely on content styling.
  - **Header Highlights:** `ColorDecorator` adds a `colorHeaderBackground` option to apply bold background colors specifically to log headers, improving scannability in dense logs without bleeding into structural elements.
  - **Hierarchy Visualization:** Introduced `HierarchyDepthPrefixDecorator` (formerly experimented as `TreeDecorator`). It adds visual indentation (defaulting to `│ `) based on the logger's hierarchy depth, creating a clear tree-like structure in the terminal.
- ### API & Robustness
  - **Simplified BoxDecorator:** Removed internal complexity from `BoxDecorator`, making it a pure `StructuralDecorator` focused on layout.
  - **Robustness Tests:** Expanded test suite to cover deep decorator composition, ensuring that complex chains (Color -> Box -> Indent) render correctly without layout artifacts.

## 0.3.1: Logger Architecture Refactor & Performance Optimization + Critical Bug Fix

- ### Bug Fix: Corrupted Pure Dart support fixed
  - Version 0.3.0 dropped support for pure dart due to a mis-used library. **Fixed in version 0.3.1**.

- ### Architectural Shift: Separated Configuration from Resolution
  - **`LoggerConfig` & `LoggerCache`:** Introduced a dual-component architecture for logger configuration. `LoggerConfig` now strictly holds raw, explicitly set configuration values, while the new `LoggerCache` handles the hierarchical resolution (inheritance) and provides a high-performance caching layer.
  - **Versioned Invalidation:** Implemented a version-based cache invalidation mechanism. `LoggerConfig` tracks changes via a `_version` counter, allowing `LoggerCache` to lazily re-resolve effective settings only when the source configuration or its ancestry changes.
  - **Thread-Safety & Immutability:** Resolved configuration objects (like `handlers` and `stackMethodCount`) are now returned as **unmodifiable** collections, protecting the internal state from accidental external mutation.
- ### Performance: Deep Equality Optimization
  - **Smart Reconfiguration:** `Logger.configure` now performs deep equality checks on collections using internal `listEquals` and `mapEquals` utilities. This prevents redundant cache invalidations and descending tree walks when passing new collection instances that contain identical configurations.
  - **Comprehensive Equality Support:** Implemented `operator ==` and `hashCode` across the entire configuration surface, including:
    - **Handlers:** `Handler` now correctly compares its formatter, sink, filters, and decorators.
    - **Time Engine:** `Timestamp` and `Timezone` (including DST rules and transition logic) now support value-based equality.
    - **Stack Logic:** `StackTraceParser` and `CallbackInfo` now support deep comparison.
    - **Filters & Formatters:** `LevelFilter`, `RegexFilter`, `PlainFormatter`, `BoxFormatter`, and `JsonFormatter` are now value-comparable.
- ### Resilience & Testing
  - **InternalLogger Resilience:** Added targeted tests to verify that `InternalLogger` remains safe and circular-logging-free even when primary handlers fail, preventing stack overflows during failure recovery.
  - **Deep Inheritance:** Expanded the test suite to cover complex, multi-level hierarchy inheritance with partial overrides, ensuring configuration correctly "bubbles" through the tree.
  - **LogBuffer Integration:** Verified the instance-based `LogBuffer` API (`logger.infoBuffer`) and its integration with the logging pipeline.
- ### API & Maintenance
  - **Immutability Enforcement:** Applied `@immutable` annotations to all core configuration and handler classes, providing better compile-time safety and alignment with modern Dart best practices.
  - **Core Utilities:** Centralized collection equality logic into `src/core/utils.dart`.

## 0.3.0: Robust Fallback Logging & Handler Resilience
- ### Fallback Logger for Circularity Prevention
  - Introduced `InternalLogger`, a safe, direct-to-console logging mechanism for library-internal errors.
  - This prevents circular logging loops where a failure in a sink (like `FileSink`) could trigger another error log, leading to infinite recursion.
  - Integrated `InternalLogger` into `Logger`, `FileSink`, `MultiSink`, `LogBuffer`, and `Timezone`.
- ### Improved Handler Resilience
  - `Logger` now catches errors from individual handlers. If one handler fails, it reports the error via `InternalLogger` and continues to process other handlers.
  - `MultiSink` now iterates through its sinks and handles individual sink failures independently, ensuring a single failing sink doesn't stop the entire output pipeline.
- ### Bug Fixes & API Refinements
  - **StackTraceParser:** Fixed a regex bug that prevented parsing frames with spaces in method names, such as `<anonymous closure>`.
  - **API Visibility:** Unhidden `LogEntry` in the public API, as it is required for users to implement custom `LogFormatter` instances.
  - **InternalLogger Visibility:** Marked `InternalLogger` as `@internal` to keep it out of the public surface while still available for internal use.

## 0.2.3: Decoupled System Dependencies for Enhanced Testability
- ### Internal Service Locator for System Dependencies
  - Introduced an internal `Context` class to act as a service locator for system-level dependencies like `Clock` and `FileSystem`.
  - This decouples the library from concrete implementations (e.g., `DateTime.now()`, `dart:io`), making it possible to inject mock implementations during testing.
  - Added `@visibleForTesting` annotations to allow injecting custom `Clock` and `FileSystem` instances in test environments.
  - This change significantly improves the testability and reliability of time-sensitive and file-system-dependent components.

## 0.2.2: Enhanced FileSink Rotation & Custom Formatters
- ### Custom Filename Formatters for Rotated Logs
  - `SizeRotation` and `TimeRotation` now accept an optional `filenameFormatter` function.
  - This allows developers to define custom naming schemes for rotated log files, providing more control over backup organization.
- ### Robust File Rotation & Cleanup Logic
  - The backup cleanup logic has been refactored to be more reliable. It now sorts backup files by their last modified timestamp to determine which to delete, instead of parsing potentially fragile filenames.
  - `SizeRotation` now correctly renames the current log file to the first backup (e.g., `.1`) before compression.
- ### Improved Argument Validation & Reliability
  - `FileSink` now validates the `basePath` to ensure it is not empty or a directory.
  - `FileRotation` and `TimeRotation` constructors now throw an `ArgumentError` for invalid arguments (e.g., negative `backupCount`), replacing previous `assert` checks.
  - `FileSink.write()` now writes to the file with `flush: true` to ensure data is immediately persisted.

## 0.2.1: Comprehensive Time Component Testing & Fixes
- ### Comprehensive Unit Testing
  - **`Time` & `Timezone` Tests:** Added `time_test.dart` and `timezone_test.dart` to verify mockable providers and extensive DST calculations across various rules and hemispheres.
  - **`Timestamp` Formatter Tests:** Added `timestamp_test.dart` to validate formatters, literal parsing, edge cases, and timezone handling.
- ### Bug Fixes & Refinements
  - **Timestamp Formatting:** Corrected `iso8601` and `rfc2822` formatters by removing extra single quotes to fix timezone literal rendering. The formatter token parser was also updated to correctly handle tokens containing underscores and digits.
  - **DST Rules:** Updated internal DST transition rules for several European timezones (`Europe/Paris`, `Europe/London`, `Europe/Berlin`) to use the correct local transition times.
  - **Time Class:** Renamed `Time.resetTimeProvide()` to `Time.resetTimeProvider()` for consistency.
  - **Code Simplification:** Replaced a manual Zeller’s congruence implementation for calculating the day of the week with a simpler call to `DateTime.utc().weekday`.

## 0.2.0: Time Engine Overhaul & Mockable Time Provider
- ### Timestamp & Timezone Overhaul (Performance, DST, API)
  - **Performance:** Implemented a cached token system, eliminating the need to re-parse redundant formatters on every call.
  - **Mockable Time Provider:** Introduced a mockable time provider (`Time.timeProvider`) for robust testing of time-sensitive logic. The `Time` class is now encapsulated with controlled access via `setTimeProvider()` and `resetTimeProvider()`.
  - **DST Support:** Added full support for Daylight Saving Time (DST). The local timezone will resolve to a DST-aware timezone if available on the platform.
  - **`timezone` Renaming (Backward Incompatible):** The `timeZone` parameter was renamed to `timezone` for consistency. The `TimeZone` class was also renamed to `Timezone`.
  - **DST Calculation Fix:** Improved the DST offset calculation logic to better handle transitions.
  - **Platform Support:** Enhanced platform-aware timezone detection, now including web support.
- ### Advanced `Timestamp` Formatter
  - **Literal Support**: The formatter now supports single-quoted literals (e.g., `'on'`, `'at'`) to include static text in the output.
  - **New Format Tokens**:
    - `'F...'`: For microseconds (for high-accuracy benchmarking).
    - `'E...'`: For weekdays (e.g., 'Monday').
    - `'a'`: For lowercase "am/pm".
    - `'z'`: For a standard-compliant timezone offset string (e.g., `Z` or `+0330`).
  - **Token Changes:** Removed the 'SSSS' token as it was redundant.
  - **Factory Constructors**: Introduced common factory constructors like `Timestamp.iso8601()`, `rfc3339()`, `rfc2822()`, and `millisecondsSinceEpoch()`.
- ### Other Changes & Refinements
  - **API Clarity:** Renamed `LogBuffer.sync()` to `LogBuffer.sink()`.
  - **Improved Error Handling:** `LogBuffer` and `FileSink` now use the logger instance for error reporting instead of `print()`.
  - **Code Refinements:** Internal function and variable names related to timezones have been unified for better readability.

## 0.1.5: Async Logging / File Rotation
- ### Asynchronous Logging Pipeline
  -   The entire logging pipeline, from `logger.log()` to `handler.log()` and `sink.output()`, is now `async`.
  -   This prevents I/O operations (like file or network writes) from blocking the main thread.
  -   Error handling has been added to logging calls to catch and print exceptions that occur during the logging process itself.
- ### Advanced File Sink with Rotation
  -   Introduced `FileRotation` abstract class to enable log file rotation policies.
  -   Added `SizeRotation`: Rotates log files when they exceed a specified size (e.g., '10 MB').
  -   Added `TimeRotation`: Rotates logs based on a time interval.
  -   Both rotation policies support keeping a configured number of backup files and optional `gzip` compression for rotated logs.
- ### Minor Refinements
  -   `MultiSink` now outputs to all its sinks concurrently using `Future.wait`.
  -   Added `//ignore: one_member_abstracts` to `LogFilter` and `LogFormatter` to clean up analyzer warnings.

## 0.1.3: Pure Dart Support / Instantaneous Cached Configurations
- ### Pure Dart Optimizations
  - logd in now Dart ready. Decoupled from Flutter dependencies in favor of Dart standalone support.
- ### Instantaneous Cached Configurations
  - **Introduced `_LoggerConfig`:** Configuration is now stored in a separate internal `_LoggerConfig` class, decoupling it from the `Logger` instance itself. This allows `Logger` to act as a lightweight proxy.
  - **Improved Dynamic Hierarchy Propagation:** Configuration changes now dynamically propagate down the logger tree. 
  - **Cached Configuration:** Resolved configuration values are now cached to improve performance by avoiding repeated hierarchy lookups. Caches are automatically cleared when parent configurations change.
  - **Simplified `configure()`:** The `configure()` method now updates the configuration in-place rather than creating a new `Logger` instance.
  - **Normalized Logger Names:** Logger names are now consistently normalized to lowercase to ensure case-insensitivity. The root logger is consistently referred to as 'global'.
  - **Refactored `freezeInheritance()`:** The `freezeInheritance()` method has been updated to work with the new `_LoggerConfig` model, "baking" the current resolved configuration into descendant loggers.
  - **Removed `attachToUncaughtErrors()`:** The method was removed from the `Logger` class.
- ### TimeZone Improvements
  - The `Timestamp` constructor's `formatter` parameter is now required.
  - A new factory constructor, `Timestamp.none()`, is introduced to create a `Timestamp` with an empty formatter.
  - `TimeZone.local()` now correctly includes the system's current time zone offset.
- ### Improved FileSink (Still Under Development)
  - Automatically create parent directories for the log file path.
  - Add more robust error handling:
  - Rethrow exceptions in debug mode for easier debugging.
- ### Comprehensive example demonstrating all `logd` features

## 0.1.2: Minor API Changes

## 0.1.1: Dynamic Logger Tree Hierarchy Inheritance
- ### Dynamic Inheritance
  - Logger tree is now dynamically propagated, rooting at 'global' logger
  - freezeInheritance() is introduced to bake configs into a logger (and it's descendant branch, if any).
  - global getter ditched in favor of uniformity: access global logger using get() or get('global').

## 0.1.0: Dot-separated Logger Tree Hierarchy + Handlers
- ### New Api
  - Logger has new Api surface.
  - Introduced Dot-separated Logger Tree Hierarchy.
  - Introduced functionalities to attach to Flutter/Dart Error and Unhandled Exceptions
- ### Logger Tree Hierarchy
  - Loggers are named, now with a Dot-separated mechanism to inherit from their parent if not explicitly set. (Under Development)
  - global Logger (still) available.
  - Child propagation. (Under Development)
- ### Handlers
  - Introduce Handlers:
    This Replaces Printers in V 0.0.2, no backward compatibility here!
  - Introduced LogFormatters:
    Separated formatting LogEntries from outputting.
  - Introduced LogSinks:
    Separated outputting LogEntries from formatting.
  - Introduce LogFilters
    A way to filter out specific log entries.
- ### Better Structure and Documentation

## 0.0.2: Modularity + Printers
- ### Introduced Modular Loggers
- ### Introduced LogEvents
- ### Introduced Printers
  - Printers are a way of outputting data. (Soon to be replaced with Handlers: Formatters and Sinks)

## 0.0.1: Initial version
- ### Logger Daemon
  - Uses LogBuffer to collect  and output data.
- ### Simple BoxPrinter
  - Formats output in a simple box.
- ### StackTraceParser
- ### TimeStampFormatter and TimeZone
