# Changelog

## 0.3.0

- Requires logd ^0.10.8.
- **Configurable Reconnection & Retry Backoff (`BackoffPolicy`)**:
  - Added `@immutable` `BackoffPolicy` supporting initial delay, max delay, exponential multiplier, and decorrelated randomized jitter to prevent thundering-herd reconnect storms across distributed clients.
  - Integrated into `HttpSink` batch retry progression and `SocketSink` auto-reconnect cycle.
  - Full multi-isolate serialization and deserialization support via `registerLogdNetworkSerializers()`.
- **Flexible Delivery Formats (`HttpDeliveryFormat`)**:
  - Added `HttpDeliveryFormat` supporting `jsonArray` (`application/json`, default), `ndjson` (Newline-Delimited JSON, `application/x-ndjson`), and `raw` (`application/octet-stream`).
  - High-throughput byte stream assembly using zero-allocation `BytesBuilder` joins, avoiding intermediate UTF-16 string allocations.
- **Memory Budgeting & Priority Eviction**:
  - Added `maxBufferBytes` buffer ceiling to `NetworkSink`, `HttpSink`, and `SocketSink` to enforce strict memory bounds in high-throughput environments.
  - Added `DropPolicy.discardByPriority` to evict lowest-severity entries first (`debug` -> `info` -> `warning` -> `error`) when buffer limits are reached.
  - Added atomic pre-validation of available headroom in `discardByPriority` to prevent partial eviction when large incoming entries cannot fit.
  - Exposed `bufferedBytes` and `bufferedLogCount` public telemetry inspection getters on `NetworkSink`.
- **Character Resilience & Stream Hardening**:
  - Configured `allowMalformed: true` in UTF-8 decoders across `SocketSink` and `HttpSink`, eliminating potential infinite reconnect loops triggered by malformed byte sequences.
  - Added graceful fallback stringification (`toEncodable`) in `HttpServerSink` to safely serialize arbitrary non-encodable context objects over WebSockets.
- **Observability Dashboard UX Enhancements (`dashboard_html.dart`)**:
  - **Custom Title Propagation**: Connected the `title` parameter across `HttpDashboardHandler`, `HttpDashboardIsolateHandler`, and `HttpServerSink`, dynamically injecting sanitized titles into `<title>` and `<h1>`.
  - **Lossless Stream Pausing**: Pausing incoming streams buffers events into an in-memory queue (up to 5,000 entries) with live queue count indicators, draining into the DOM upon unpausing without log loss.
  - **Subsystem / Logger Namespace Filtering**: Dynamic dropdown automatically discovers incoming logger names and filters events by logger hierarchy.
  - **Regex Search & Match Counters**: Search input supports `/pattern/flags` regular expression matching across message, logger, origin, context, and error fields, with real-time match count badges.
  - **NDJSON One-Click Export**: Added client-side export button to download active logs as a standardized `.ndjson` payload.
- **Serialization Completeness**:
  - Extended `registerLogdNetworkSerializers()` to cover `SocketSink.protocols` and `HttpServerSink.title`, `allowedHosts`, and `authToken`.
- **Examples & Recipes**:
  - Added `example/delivery_format_example.dart` showcasing NDJSON stream ingestion, jittered backoff policies, and memory budget limits.
  - Added `example/offline_spooling_recipe.dart` showcasing zero-data-loss local queue spooling and automatic reconnection replay.

## 0.2.6

- Requires logd ^0.10.8.
- **Fail-Safe Diagnostics & Metric Alignment**:
  - Migrated `HttpSink`, `SocketSink`, and `HttpServerSink` fail-safe diagnostic logging to `InternalLogger` imported from `package:logd/advanced.dart`, eliminating all internal implementation import and member suppressions.
  - Replaced internal metric mutation with public `LoggerMetrics.incrementDroppedBatches()`.
- **Target Handler Documentation Cleanup**:
  - Cleaned up doc comment parameter references in `HttpDashboardHandler` and removed `comment_references` suppression header.

## 0.2.5: Security Hardening, DNS Rebinding Protection & Native Headers

- Requires logd ^0.10.6.
- Minimum Dart SDK is now 3.10.0 (the previous 3.6.0 floor could not be resolved because of dependency requirements)
- **DNS Rebinding Protection & Host Header Validation (`HttpServerSink`)**:
  - Enforced strict `Host` header validation for the dashboard HTTP server and WebSocket upgrade endpoint. Requests with non-loopback host headers (`localhost`, `127.0.0.1`, `::1`) are rejected with HTTP 403 Forbidden unless explicitly allowed via `allowedHosts`.
  - Added optional `authToken` parameter requiring bearer or query authentication to access the dashboard.
- **Native Handshake Headers (`SocketSink`)**:
  - Implemented cross-platform WebSocket connection adapter. On native VM platforms, configured `headers` are now transmitted as authentic HTTP headers during the handshake rather than offered as subprotocols, with dedicated support for `protocols`.
- **Diagnostic Endpoint Sanitization (`HttpSink`)**:
  - Sanitized endpoint URLs and error strings in internal logging diagnostics, removing sensitive query strings and credentials before printing failover or drop warnings.
- **Lifecycle & Buffer Drain (`flush`)**:
  - Implemented `Future<void> flush()` on `HttpSink` and `SocketSink` conforming to the core `LogSink.flush()` contract, allowing callers to await pending HTTP transmissions and socket buffer drains before process shutdown.
  - Renamed internal buffer extraction method to `takeBuffer()` to resolve naming conflicts.

## 0.2.4

- **Maintenance**: Update repository, issue tracker, documentation, and raw asset URLs to reflect account migration to `pccria`.

## 0.2.3

- **Documentation**: Use absolute raw asset URLs for README visual diagrams to ensure proper rendering on pub.dev.

## 0.2.2

- **Documentation**: Added official high-DPI hero branding and embedded browser dashboard preview asset.

## 0.2.1

- **Stored Cross-Site Scripting (XSS) Prevention (`dashboard_html.dart`)**:
  - Implemented client-side HTML entity escaping (`escapeHtml()`) for all dynamic variables rendered into dashboard DOM: error messages, stack traces, context objects, logger names, log levels, and tabular tags.
  - Hardened HTML encoder recognition by transmitting explicit `isHtml: boolean` flags from `HttpServerSink`, preventing plain text logs starting with `<div` from bypassing sanitization.
- **Cross-Site WebSocket Hijacking (CSWSH) & Security Response Headers**:
  - Added `allowedOrigins` origin verification on `/ws` upgrades in `HttpServerSink`. Rejects untrusted cross-origin browser WebSocket requests with HTTP `403 Forbidden` while allowing localhost/loopback and configured dashboard domains.
  - Attached standard security response headers on HTTP dashboard requests: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, and `Content-Security-Policy`.
- **DoS & Connection Cap Protection (`maxConnections`)**:
  - Added configurable `maxConnections` safeguard (default: 32) to `HttpServerSink` and `HttpDashboardHandler`. Returns HTTP `503 Service Unavailable` with `Retry-After: 5` when the connection limit is reached.
- **Isolate Handshake Hardening & Dynamic Port 0 Support**:
  - Added bound port reporting from worker isolate back to main isolate in `HttpDashboardIsolateHandler`, enabling `port: 0` ephemeral binding with asynchronous background dashboard handlers.
  - Enhanced worker error propagation to complete `ready.future` with `completeError()` on socket binding failure rather than hanging.
  - Exposed `boundPort` getter on `HttpDashboardHandler` and `HttpDashboardIsolateHandler`.
- **Dependency Alignment**: Updated minimum `logd` dependency constraint to `^0.10.2`.

## 0.2.0

- **Dynamic Auth Hooks (`headersProvider`)**: Added `headersProvider` callback to `HttpSink` for composing dynamic request headers (OAuth2 bearer token refresh, rotating HMAC signatures) evaluated before each batch POST and re-evaluated during retry backoffs.
- **Circuit Breaker (`CircuitState`)**: Added three-state circuit breaker (`closed`, `open`, `halfOpen`) on `HttpSink` with configurable `failureThreshold` and `recoveryTimeout`. Trips to `open` on repeated backend failures to fast-fail and avoid flooding broken endpoints; automatically enters `halfOpen` probe state to restore service seamlessly.
- **Failover Endpoints (`failoverUrls`)**: Added multi-endpoint high availability fallback list to `HttpSink`. In-flight batch retries automatically cycle through backup endpoints before dropping logs.
- **HTTP Backpressure & `Retry-After` Support**: Added pure-Dart parsing for standard HTTP 429 and 503 `Retry-After` headers (supporting both integer seconds and RFC 1123 / RFC 850 / asctime dates) with zero external or `dart:io` platform dependencies. Automatically pauses outbound batch flushes until server cooldown expires.
- **Batch GZip Compression (`compress`)**: Added optional `compress: true` payload compression on `HttpSink` achieving up to 90%+ bandwidth savings for telemetry ingest. Platform-safe with conditional exports (native GZip on VM/Flutter, fallback passthrough on Web/WASM).
- **WebSocket Heartbeats & Proactive Reconnect**: Added `heartbeatInterval`, `heartbeatTimeout`, `pingMessage`, and `pongMessage` to `SocketSink` with incoming stream monitoring. Automatically detects silent connection drops or half-open TCP links and initiates exponential backoff reconnects without data loss.
- **Pure Dart In-Process Test Infrastructure**: Converted integration and showcase tests to in-process `dart:io` `HttpServer` and `WebSocketTransformer` servers, eliminating external Python environment dependencies.
- **Document Postamble Drain Fix**: Fixed `HttpSink.dispose()` and `SocketSink.dispose()` to ensure document-level postambles are enqueued and drained before connection shutdown.
- **`HttpDashboardHandler` Lifecycle Fix**: Overrode `dispose()` on `HttpDashboardHandler` to call `await sink.dispose()`, cleanly unbinding the embedded HTTP server and closing active WebSockets upon handler disposal.
- **Expanded Test Coverage**: 60 unit and integration tests covering all resilience patterns, circuit breaker state transitions, failover rotations, dynamic token refreshes, and compression payloads.
- **New Working Examples**: Added standalone runnable examples for dynamic auth (`dynamic_auth_example.dart`), circuit breaker & failover (`circuit_breaker_example.dart`), GZip compression (`compression_example.dart`), and WebSocket heartbeats (`heartbeat_example.dart`).
## 0.1.6

- **Dependency Alignment**: Updated `logd` dependency constraint to `^0.10.0`.

## 0.1.5

- **Web & WASM Platform Support Fix**:
  - Split `HttpDashboardIsolateHandler` into conditional native and web stub implementations (`http_dashboard_isolate_handler_native.dart` and `http_dashboard_isolate_handler_stub.dart`), eliminating unconditional `dart:isolate` and `dart:io` imports when compiled for Web or WASM runtimes.
- **`logd` v0.10.x Support**:
  - Widened dependency constraint to `logd: '>=0.9.7 <0.11.0'`, enabling seamless compatibility with `logd` v0.10.0's pure semantic engine.
  - Documented complete decoupling and permanent removal of network sinks from core `logd`.

## 0.1.4

- **Async Dashboard Isolate Execution (`HttpDashboardHandler.async`)**: Added `HttpDashboardHandler.async()` static factory method for running the real-time HTTP/WebSocket dashboard server on a background isolate without blocking the main event loop.
- **Direct Formatter & Decorator Transfer**: Passes `@immutable` `LogFormatter` and `LogDecorator` instances directly to the background dashboard worker isolate without JSON serialization overhead.
- **Lifecycle Hardening & Race-Free `dispose()`**: Awaits isolate initialization before executing teardown, ensuring the embedded HTTP/WebSocket server unbinds cleanly and eliminating race conditions or orphaned ports on rapid shutdown.
- **Serialization Support**: Added `HttpServerSink` serialization support to `registerLogdNetworkSerializers()` for `Logger.exportConfig()` and `Logger.importConfig()`.
- **Documentation**: Added `doc/architecture.md`, `doc/benchmarks.md`, and `doc/migration_guide.md`.
- **Updated Dependencies**: Updated `logd` dependency constraint to `^0.9.7`.

## 0.1.3

- **`SocketSink` Reconnect Timer Fix**:
  - Replaced fire-and-forget `Future.delayed` with a cancellable `Timer` stored on `_SocketState`. Cancels pending reconnection timers in `dispose()` to prevent memory leaks and unhandled callbacks firing into disposed sinks.
- **`DropPolicy.block` Eager Validation & Deprecation**:
  - Added `@Deprecated` annotation to `DropPolicy.block` targeting `v1.0.0` removal.
  - Added eager constructor `assert` in `NetworkSink` to catch unsupported `DropPolicy.block` configurations at construction time rather than during runtime buffer overflow.

## 0.1.2

- **Web & WASM Compatibility**:
  - Replaced `dart:io` `HttpException` with `http.ClientException` in `HttpSink` to enable full Web and WASM runtime compatibility across browser targets (restoring 20/20 platform support score).
- **Example Tab Discovery Fix**:
  - Updated `example/main.dart` to contain the clean production usage showcase (`HttpDashboardHandler` + `HttpSink`) so pub.dev's Example tab renders the production example directly.
  - Moved interactive CLI menu gallery runner to `example/showcase_gallery.dart`.
  - Hidden deprecated core network exports in examples to prevent shadow analyzer warnings.

## 0.1.1

- **Pub.dev Score & Example Fixes**:
  - Hide deprecated core network exports in `example/example.dart` to resolve analyzer deprecation warnings.
  - Added `example/example.dart` standard example entrypoint for automated pub score discovery.
  - Added `platforms` metadata (`android`, `ios`, `linux`, `macos`, `web`, `windows`) and pub `topics` tags for 100% pub.dev score.

## 0.1.0

- Initial release of `logd_network`, a dedicated satellite package providing HTTP telemetry, WebSocket streaming, and embedded browser dashboards for `logd`.
- **`HttpSink`**: High-performance HTTP log collector sink supporting:
  - In-memory log entry batching (`batchSize`, `flushInterval`).
  - Exponential backoff retry algorithm with configurable max attempts (`maxRetries`).
  - Configurable drop policies (`DropPolicy.discardOldest`, `DropPolicy.discardNewest`) to prevent memory leaks during endpoint outages.
  - Custom HTTP headers and authorization token support.
- **`SocketSink`**: Real-time WebSocket streaming sink supporting:
  - Frame-by-frame live streaming over `ws://` and `wss://`.
  - Automatic reconnection logic with configurable `reconnectInterval`.
  - Offline log buffering during network downtime and atomic flush upon reconnection.
- **`HttpServerSink`**: Embedded local server sink supporting:
  - Loopback HTTP and WebSocket server hosting on configurable ports (`address`, `port`).
  - Embedded single-page browser dashboard UI with real-time WebSocket log streaming.
  - In-memory ring buffer (`bufferCapacity`) to replay past log history to new browser connections.
- **`HttpDashboardHandler`**: ADR-006 compliant pre-wired `Handler` subclass:
  - Zero-configuration plug-and-play setup for local browser log monitoring.
  - Pre-wires `StructuredFormatter`, `HtmlEncoder`, and `HttpServerSink` out of the box.
- **Cross-Isolate Serialization**:
  - `registerLogdNetworkSerializers()` helper for registering deserializers with `LoggerSerializationRegistry` in background worker isolates.
- **Interactive Showcases & Test Harness**:
  - Interactive CLI showcase gallery in `example/main.dart` with 4 dedicated showcases (`http_sink_showcase.dart`, `socket_sink_showcase.dart`, `http_server_sink_showcase.dart`, `http_dashboard_showcase.dart`).
  - Comprehensive unit and integration test suite (17/17 tests passing).
