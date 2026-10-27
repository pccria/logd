# logd Product — Session Log
> Append-only. Records high-level product release decisions, milestones, and architectural pivots.
> Never edit past entries. Add new entries at the top.

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
