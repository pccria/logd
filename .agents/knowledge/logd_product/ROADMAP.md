# logd Product — Roadmap & Philosophy
> Canonical product direction, philosophy, and unified roadmap.
> Last Updated: 2026-07-18 | Reflects v0.8.9 + strategic planning session.

---

## Core Product Philosophy

> **"Simplicity integrated into complexity."**
>
> The logging engine should support complex execution needs (object pooling, native FFI, offloaded isolate workers) while exposing a clean, approachable interface for standard developers.

### Core Architectural Pillars
1. **Purity of Representation**: Formatters and decorators operate strictly on Semantic IR (`LogDocument`). Wrapping, layout, and colors are physical layer concerns managed by `TerminalLayout` and Encoders.
2. **Zero Garbage Collection Overhead**: Hot-path logging targets zero heap allocations per 10k log operations via LIFO pooling (`Arena`, `LogBuffer`) and linear serialization (`Binary IR`).
3. **Platform-Agnostic Core**: Compile-time decoupling ensures out-of-the-box browser/web support, VM support, and Flutter independence.
4. **Minimal Core, Rich Ecosystem**: The core package should carry only foundational dependencies. Platform-specific or heavyweight integrations belong in satellite packages.

---

## Criticisms of the Roadmap (Recorded 2026-07-18)

The following is a professional critical analysis of the three-area product roadmap proposed by the author, recorded as a permanent knowledge item for agent continuity.

### Area 1: Dedicated Sinks (SqlSink, MemorySink, SentrySink)

**Strengths**: External sinks are a natural ecosystem driver. Production maturity signals come largely from the integration catalogue.

**Critical Problems**:
- Building and publishing sink packages (`logd_sqlite`, `logd_sentry`) while the core API is unstable forces synchronized breaking-change version bumps across all sink packages the moment the extension contract changes.
- `LogSink`, `LogFormatter`, and `Handler` extension points must be declared `@stable` before any satellite package targets them.

**Decision**: Area 1 should happen in **Phase 2**, after the core public API is stabilized (Phase 1). Building sinks on a moving API is wasteful.

---

### Area 2: API Surface Stabilization & DX for v1.0

**Strengths**: Correct anchor. Gates everything else. Without a stable contract, no ecosystem can form.

**Critical Problems**:
- "Gradually stabilizing" without a concrete mechanism produces API limbo. Developers cannot distinguish safe from unsafe surface.
  - **Required**: Annotate every public symbol as `@stable`, `@experimental`, or `@internal` (via `package:meta`). Commit to per-symbol guarantees.
- "Standard DX" is underspecified without concrete deliverables:
  - Does `Timezone.ensureInitialized()` need to be called manually? Or does the API self-configure?
  - Is there a single `logd.dart` import that works everywhere without conditional logic from the user's side?
  - Are error messages actionable? (e.g., "Add `sink: ConsoleSink()` to your Handler constructor" instead of "Handler has no sink.")
- No breaking-change policy defined. A semver contract document is required before v1.0 can be declared.

**Decision**: This is the correct **Phase 1** anchor. Must produce concrete deliverables:
1. Symbol annotation audit (`@stable` / `@experimental` / `@internal`).
2. Self-initialization review (zero mandatory setup for standard use cases).
3. Error message quality pass.
4. Semver policy document.

---

### Area 3: Extracting Heavy Dependencies (http, socket, ffi) from Core

**Strengths**: Architecturally correct. Developers using `logd` for local/console logging should not pull HTTP stacks. Reduces pub.dev dependency weight and cold start times.

**Current core dependencies to extract**:
- `http: ^1.2.0` — consumed by `HttpServerSink` only.
- `web_socket_channel: ^3.0.0` — consumed by `SocketSink` / WebSocket streaming only.
- `ffi: ^2.1.3` — consumed by `Arena` / `NativeEngine` only.

**Critical Problems**:
- Moving `HttpServerSink` and `SocketSink` out of `package:logd/logd.dart` is a **breaking API change**. It requires a **major version bump**. Cannot be a minor release.
- Correct execution sequence:
  1. Stabilize API (Phase 1).
  2. Cut v1.0 with documented deprecations of `HttpServerSink`, `SocketSink`, `NativeEngine` in core.
  3. Publish `logd_http`, `logd_socket`, `logd_native` as separate satellite packages.
  4. Remove from core in v1.1 or v2.0 per the semver policy.

**Decision**: This is a **Phase 3** concern. It is the final phase because it requires a deprecation cycle and a major version bump.

---

## Unified Phased Roadmap (Revised 2026-07-18)

```
Phase 1 (v0.9.x) — Foundation, DX & Performance
  - Audit public symbols: @stable / @experimental / @internal
  - Publish semver contract document
  - TargetHandler convenience subclasses (ADR-006) & dual-mode .async() offloading
  - Unified theming & HtmlStylesheet extraction
  - Ambient Structured Context (LogContext.run / MDC) & caller origin bypass
  - Extract `logd_network` satellite package & soft-deprecate core network classes (v0.9.5)

Phase 2 (v0.10.x) — Zero-Dependency Core Engine & Isolate Topology
  - Hard removal of deprecated network classes & dependencies from core (`http`, `web_socket_channel`)
  - Evaluate `logd_time` (IANA timezone) and `logd_native` (FFI) extractions (see `SATELLITE_EXTRACTION_STRATEGY.md`)
  - Principled Multi-Isolate Architecture (explicit topology roles, configuration broadcast protocol, ambient context bridging — see `logd_isolate_model/`)
  - Satellite ecosystem expansion (`logd_sqlite`, `logd_network`, `logd_linters`, `logd_flutter`)

Phase 3 (v1.0.0) — Major Release & API Stability Lock
  - Public declaration of complete API stability across single and multi-isolate models
  - Zero breaking changes to @stable symbols without major semver bumps
  - Complete zero-external-dependency core engine verification
```

---

## Satellite Extraction Roadmap (See `SATELLITE_EXTRACTION_STRATEGY.md`)

- [x] Publish `logd_sqlite` (SQLite WAL persistence & rich query engine) — v0.9.0
- [x] Extract & Publish `logd_network` (`HttpSink`, `SocketSink`, `HttpServerSink`, `HttpDashboardHandler`) — v0.9.5
- [x] Hard-remove network classes & `http`/`web_socket_channel` deps from core — v0.10.0
- [x] Unify FileRotation to path-first `shouldRotate` and soft-deprecate `needsRotation` — v0.10.7
- [ ] Hard-remove deprecated `needsRotation` and `checkNeedsRotation` from core — v0.11.0
- [ ] Evaluate `logd_time` extraction (remove `timezone` dependency from core) — v0.11.x
- [ ] Evaluate `logd_native` extraction (remove `ffi` dependency from core for 100% Web/Dart purity) — v0.10.x
- [ ] Evaluate `logd_deobfuscate` extraction (remove `source_maps`/`source_span` from core) — v0.10.x
- [ ] Develop `logd_flutter` (In-app log viewer widget, overlay toasts, DevTools extension panel)

---

## Phase Timeline Detail

### Phase 1: Foundation, DX & Performance (v0.9.x)
**Goal**: Establish clean DX, robust theming, ambient structured logging, and hot-path execution efficiency.
- Symbol annotation audit (`@stable`, `@experimental`, `@internal` via `package:meta`)
- Publish semver contract document in `doc/`
- TargetHandler pre-wired subclasses (ADR-006)
- Ambient Structured Context (`LogContext.run`) & hot-path caller origin bypass (`includeOrigin: false`)
- Theming unification (`LogBrightness`, `lightScheme`)

### Phase 2: Multi-Isolate Architecture & Ecosystem Expansion (v0.10.x)
**Goal**: Design and iterate on a principled multi-isolate semantic model with full design freedom before committing to v1.0 API freeze.
- Explicit topology roles (`primary`, `worker`)
- Deterministic binary configuration broadcast protocol
- Cross-isolate ambient context serialization & restoration bridges
- Centralized unified ingestion stream vs. distributed pipeline validation
- Satellite packages launch: `logd_sqlite`, `logd_memory`, `logd_sentry`

### Phase 3: Major Release & API Stability Lock (v1.0.0)
**Goal**: Publicly declare full API stability across all execution models.
- Zero breaking changes relative to `@stable` symbols
- Full semver breaking-change commitment for production consumers
- Formal deprecation notices for heavy transitive network/FFI dependencies in core

### Phase 4: Lean Core (v1.1+ / v2.0)
**Goal**: Reduce core to a minimal, fast, dependency-light foundation.
- Publish `logd_http` (HttpServerSink + WebSocket dashboard)
- Publish `logd_socket` (SocketSink, network reconnect)
- Publish `logd_native` (Arena, NativeEngine, FFI pool)
- Remove extracted sinks from core
- Core dependencies reduced to: `timezone`, `meta`, `characters`, `source_maps`, `source_span`

---

## Out-of-Scope (Explicitly Deferred)
- **Automatic log rotation UI**: Not planning to support configuration or log parsing dashboards. Keep `logd` as a pure, lightweight engine.
- **Fluent logger builders**: Configuration remains structured (`Logger.configure`) rather than builder-based, keeping the API footprint small.
- **Direct database sinks in core**: Database persistence is a satellite package concern, not a core package concern.
