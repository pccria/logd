# logd_network Roadmap

Package version at time of writing: **0.1.3**

---

## Versioning Strategy

`logd_network` follows the semver contract defined in
[`doc/semver_contract.md`](../../../doc/semver_contract.md) and summarized
here for satellite-specific context:

| Increment | Triggers |
|---|---|
| **Patch** (`0.1.x`) | Non-breaking bug fixes and optimization passes. |
| **Minor** (`0.x.0`) | New backward-compatible features. Breaking or removal of `@experimental` APIs only. |
| **Major** (`x.0.0`) | Breaking changes to any implicitly stable public API (e.g. removing an enum variant not marked `@experimental`). |

**This roadmap is thematic, not release-correlated.** A single milestone may
ship across multiple patch or minor versions. Version labels on milestones
indicate the *minimum semver slot* required by the changes in that group, not a
committed release tag.

**Decoupled from `logd` core versioning.** `logd_network` has its own release
cadence. A `logd` core minor bump does not automatically trigger a
`logd_network` minor bump, and vice versa.

---

## Completed

### ✅ v0.1.3: Correctness Fixes
**Goal**: Eliminate the two known runtime bugs. No API surface changes.
**Result**: Fixed `SocketSink` reconnect timer cancel-on-dispose race condition and added eager `assert` + `@Deprecated` annotation to `DropPolicy.block`.
- [x] Fix `SocketSink` reconnect-after-dispose race: store reconnect timer on `_SocketState` and cancel in `dispose()`.
- [x] Harden `DropPolicy.block`: fail eagerly at construction time with constructor `assert` and add `@Deprecated` targeting `1.0.0` removal.

### ✅ v0.2.0 (Minor): Dynamic Auth Hooks

**Goal**: Introduce the first non-breaking transport enhancement: dynamic
request header composition for OAuth2, HMAC, and rotating credentials.

- [x] Add `FutureOr<Map<String, String>> Function()? headersProvider` to
      `HttpSink`. When provided, it is awaited before each batch POST and its
      result is merged on top of the static `headers` map.
- [x] `headersProvider` is a transient field — not round-tripped across
      isolates in `registerLogdNetworkSerializers()`. Document this explicitly.

---

## Next Milestones

### 🔲 v0.3.0 (Minor): Circuit Breaker & HTTP Resilience

**Goal**: Replace the naive retry loop in `HttpSink` with a proper Circuit
Breaker and honor standard HTTP backpressure signals.

- [ ] Implement Circuit Breaker state machine on `_HttpState`:
  - `Closed` (normal operation) → `Open` (backend is down, fail fast) →
    `Half-Open` (probe request to test recovery).
  - Configurable `failureThreshold` (default: 5 consecutive failures) and
    `recoveryTimeout` (default: 60 s).
  - Store open/closed state on `_HttpState` via the existing `Expando` pattern
    to preserve `const` constructor.
- [ ] Honor `429 Too Many Requests` and `503 Service Unavailable` responses:
  - Parse `Retry-After` header (seconds or HTTP-date) and delay accordingly
    instead of applying the exponential backoff formula blindly.
- [ ] Add `failoverUrls: List<String>?` to `HttpSink` for primary/fallback
      endpoint cycling. On circuit open, rotate to the next URL before
      entering `Open` state.

---

### 🔲 v0.4.0 (Minor): Payload Compression & WebSocket Heartbeats

**Goal**: Reduce network overhead for high-throughput apps and harden
`SocketSink` against half-open TCP connections.

- [ ] **GZip compression** (`compress: bool = false` on `HttpSink`): compress
      the JSON batch body with `dart:io`'s `GZipCodec` and set
      `Content-Encoding: gzip`. Disable on Web via conditional import (same
      pattern as `http_server_sink.dart`).
- [ ] **WS ping/pong heartbeats** (`heartbeatInterval: Duration?` on
      `SocketSink`): send a periodic WS ping frame and treat a missed pong as
      a connection failure, triggering the existing reconnect path. Prevents
      silent drops through mobile network handoffs and aggressive reverse
      proxies.

---

### 🔲 Dashboard UX Track (version TBD)

Separate track targeting `dashboardHtml.dart` exclusively. Does not affect
any transport class. Will be versioned as a minor bump when transport
milestones (v0.2.0–v0.4.0) are complete and the dashboard scope is finalized.

- [ ] **Stream pause / resume**: freeze incoming WebSocket messages in the UI
      while buffering continues silently on the server side.
- [ ] **Live search with regex**: filter visible log rows by message, logger
      name, or context key. Show match count.
- [ ] **Logger namespace filter tree**: collapsible sidebar tree view of active
      logger hierarchies (e.g. `app`, `app.db`, `app.network`) with per-node
      toggles.
- [ ] **Expandable entry detail panel**: click any log row to reveal full
      structured context map (syntax-highlighted JSON), stack traces, and TOON
      column values.
- [ ] **One-click export**: download buffered log history as NDJSON.

---

## Out of Scope for logd_network

The following ideas were considered and explicitly rejected for this package.
They are recorded here to prevent re-evaluation without context.

### Disk-Backed Buffer Spooling
Introducing a `SpoolingNetworkSink` backed by `logd_sqlite` would create a
circular satellite dependency. The correct integration point for disk-backed
durability is a user-composed pipeline:
`SqliteHandler` (from `logd_sqlite`) → feeds a replay mechanism → `NetworkSink`.
`logd_network` must remain pure-network with no storage dependencies.

### OpenTelemetry / OTLP, Syslog, NDJSON Protocol Sinks
These belong in dedicated satellite packages (`logd_opentelemetry`,
`logd_syslog`) per the satellite extraction convention (ADR-007). Adding
protocol-specific encoders here would bloat the package and undermine the
single-responsibility principle that motivated the satellite split in the
first place.

### DropPolicy.block as a True Blocking Mechanism
A real blocking drop policy would require `output()` to suspend the calling
isolate until buffer space is available. This conflicts with Dart's cooperative
concurrency model and would introduce deadlock risk under any sustained network
outage. The enum value will be deprecated and retired at `1.0.0`, not
implemented.
