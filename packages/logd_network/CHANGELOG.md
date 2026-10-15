# Changelog

## 0.2.0

- **Dynamic Auth Hooks (`headersProvider`)**: Added `headersProvider` callback to `HttpSink` for composing dynamic request headers (OAuth2 bearer token refresh, rotating HMAC signatures) evaluated before each batch POST and re-evaluated during retry backoffs.
- **Pure Dart Integration Tests**: Converted integration tests to in-process `dart:io` `HttpServer` and `WebSocketTransformer` servers, eliminating external Python environment dependencies.
- **Document Postamble Drain Fix**: Fixed `HttpSink.dispose()` and `SocketSink.dispose()` to ensure document-level postambles are enqueued and drained before connection shutdown.
- **Expanded Test Coverage**: Added comprehensive unit test coverage for `onDropped` callbacks, transport exception recovery, custom headers, FIFO buffer eviction, and HTTP 404 routing.

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
