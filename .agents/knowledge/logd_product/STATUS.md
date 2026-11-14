# logd Product — Status
> Current as of: v0.10.6 | Updated: 2026-11-14

---

## Active Product Focus

v0.10.6 released. Core Resilience & Serialization Stabilization completed. Monorepo CI/CD established. Planning v0.11.0 satellite telemetry expansion and formal multi-isolate model maturation.

---

## High-Level Milestone Tracking

| Milestone | Target Scope | Status |
|---|---|---|
| **v0.8.7 (Core Stable)** | Concurrency, FIFO waiter queue, isolate crash recovery, HTML control panel | ✅ Released |
| **v0.8.8 (Async / HTTP)** | AsyncHandler isolate offloading, HttpServerSink dashboard, HTML concurrency | ✅ Released |
| **v0.8.9 (Hardening)** | Web Source Mapping, polymorphic serialization fix, timezone hardening, ADRs | ✅ Released |
| **v0.1.2 (logd_linters)** | Automated quick-fixes for arena lifecycle, purity, and formatting rules | ✅ Published |
| **v0.9.0–v0.9.2 (API Hardening)** | Symbol audit, semver contract, logd_sqlite satellite package launch | ✅ Released |
| **v0.9.3 (Target Handlers)** | Pre-wired TargetHandler subclasses, dual-mode `.async()`, `advanced.dart` | ✅ Released |
| **v0.9.4 (MDC & Performance)** | Hot-path caller origin bypass, ambient structured context (`LogContext.run`) | ✅ Released |
| **v0.9.5 (logd_network Satellite)** | Decouple HTTP/WS dependencies to satellite package, core soft deprecations | ✅ Released |
| **v0.9.6 (Diagnostics & Safety)** | Serialization error diagnostics, verify helpers, Finalizer leak safety | ✅ Released |
| **v0.9.7 (Core Decoupling)** | Standalone satellite packages (TOON, HTML, Markdown), direct isolate transfer | ✅ Released |
| **v0.10.0 (Zero-Network Core)** | Hard deprecation removal, network-free core, pure semantic engine | ✅ Released |
| **v0.10.1 (Cookbook & Dio)** | Production cookbook, API reference, launch `packages/logd_dio` | ✅ Released |
| **v0.10.2 (Native Safety)** | Bounded Binary IR, dynamic Arena slabs, box decorator tab alignment | ✅ Released |
| **v0.10.6 (Core Resilience)** | Obfuscated frames, process drain/flush contracts, ANSI neutralization, CI matrix | ✅ Released |
| **v0.11.0 (Satellite Telemetry)** | SQLite FTS5 search, HTML client filter/search, network stream compression, Dio W3C tracing | 🔲 Next |
| **v0.12.0 (Native Phase 2)** | SIMD-accelerated colorization, vectorized layout, zero-copy pointer transfer | 🔲 Queued |
| **v1.0.0 (API Freeze & Stability)** | Full stability declaration, breaking-change policy lock, deprecation guides | 🔲 Future |

---

## Current Core Package State

- **Version**: `0.10.6`
- **Dart SDK**: `^3.10.0`
- **Direct Dependencies**: `characters`, `ffi`, `matcher`, `meta`, `timezone`, `source_maps`, `source_span` (zero external network dependencies)
- **Tests**: All 2,054 core unit and integration tests passing; 100% ecosystem validation passing.
- **Lints**: Zero analyzer warnings across entire workspace.

---

## Out-of-Scope (Explicitly Deferred)
- **Automatic log rotation UI**: Not supporting configuration or log-parsing dashboards. `logd` is a pure engine.
- **Fluent logger builders**: API stays structured (`Logger.configure`), not builder-based.
- **Direct database sinks in core**: Satellite package concern only.

---

## Active Product Decisions

- **Why linters are a separate package**: Avoids inflating core package dependency footprint with custom lint tooling.
- **Why Flutter is decoupled**: Pure Dart for CLI, server, and VM use cases without Flutter SDK friction.
- **Why satellite packages are extracted**: `logd_network` and `logd_sqlite` decouple heavy third-party dependencies from core, keeping the engine pure and zero-overhead for general Dart/Flutter applications. Deprecations in core ensure backwards compatibility until v0.10.0.
- **Why sinks come after API stabilization**: Building `logd_sqlite` or `logd_sentry` on an unstable `LogSink` extension point forces synchronized breaking version bumps. Extension points must be `@stable` before satellites target them.
- **No premature facades**: `LogOutput` convenience constructors deferred until the underlying pipeline surface, wrapping, and lifecycle changes settle.
