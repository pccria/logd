# logd_network

[![pub package](https://img.shields.io/pub/v/logd_network.svg)](https://pub.dev/packages/logd_network)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

![logd_network Hero](https://raw.githubusercontent.com/pooriaaskarim/logd/master/assets/img/logd_network_hero.webp)

Network-based sinks and live observability handlers for [`logd`](https://pub.dev/packages/logd).

Features HTTP batch shipping with exponential backoff retries, real-time WebSocket log streaming with automatic reconnection buffering, and an embedded local HTTP/WebSocket browser dashboard (`HttpDashboardHandler` / `HttpServerSink`).

---

## Installation

Add `logd` and `logd_network` to your `pubspec.yaml`:

```yaml
dependencies:
  logd: ^latest_version
  logd_network: ^latest_version
```

---

## Quick Start

Use the pre-wired `HttpDashboardHandler` to host a local real-time browser logging dashboard with zero setup:

```dart
import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

void main() {
  final dashboard = HttpDashboardHandler(
    port: 8080,
    title: 'Production Telemetry Stream',
    bufferCapacity: 200,
  );

  Logger.configure('app', handlers: [dashboard]);

  final logger = Logger.get('app.service');
  logger.info('Server started cleanly.');
  logger.warning('High memory pressure', context: {'usage': '87%'});

  // Open http://localhost:8080 in your browser to view logs in real time!
}
```

---

## Features & Component Overview

| Component | Type | Description |
|---|---|---|
| [`HttpDashboardHandler`](#1-httpdashboardhandler-embedded-browser-viewer) | TargetHandler | Pre-wired convenience handler for local browser log monitoring via HTTP/WebSocket (supports sync and `.async()` isolate mode). |
| [`HttpSink`](#2-httpsink-batch-shipping--exponential-retries) | Physical Sink | Accumulates logs in memory and ships in POST batches with exponential backoff retries. |
| [`SocketSink`](#3-socketsink-real-time-websocket-streaming) | Physical Sink | Streams logs frame-by-frame over WebSockets with offline reconnect buffering. |
| [`HttpServerSink`](#4-httpserversink-low-level-custom-dashboard-sink) | Physical Sink | Low-level server sink for hosting custom HTML/ANSI dashboards on custom ports. |

---

## Platform Compatibility

| Component | Role | Android / iOS | Windows / macOS / Linux | Web / WASM | Notes |
|---|:---:|:---:|:---:|:---:|---|
| **[`HttpSink`](#2-httpsink-batch-shipping--exponential-retries)** | HTTP Client |  |  |  | Batch-posts logs to remote HTTP collector endpoints via `package:http`. |
| **[`SocketSink`](#3-socketsink-real-time-websocket-streaming)** | WebSocket Client |  |  |  | Streams logs to remote WebSocket servers (`ws://`, `wss://`) via native & browser WebSockets. |
| **[`HttpDashboardHandler`](#1-httpdashboardhandler-embedded-browser-viewer)** | HTTP/WS Server |  |  | ❌ | Binds a local server port on `localhost`. Throws `UnsupportedError` on Web. |
| **[`HttpServerSink`](#4-httpserversink-low-level-custom-dashboard-sink)** | HTTP/WS Server |  |  | ❌ | Embedded server for custom HTML/ANSI dashboards. Throws `UnsupportedError` on Web. |

---

### 1. `HttpDashboardHandler` (Embedded Browser Viewer)
Pre-wired, zero-configuration handler that boots a lightweight local HTTP and WebSocket server hosting an interactive real-time log viewer.

> **Platform Note:** Designed for native/VM environments (server, desktop, CLI) where local TCP sockets can be bound. Throws `UnsupportedError` on Web platforms where hosting embedded servers is unsupported. For web apps, stream logs to an external collector with [`SocketSink`](#3-socketsink-real-time-websocket-streaming) or [`HttpSink`](#2-httpsink-batch-shipping--exponential-retries).

```dart
// Synchronous handler (runs server on main thread)
final dashboard = HttpDashboardHandler(
  port: 8080,
  title: 'Real-Time Observability Dashboard',
);

// Or run offloaded to a background isolate (zero UI latency)
final asyncDashboard = HttpDashboardHandler.async(
  port: 8080,
  title: 'Isolate Observability Stream',
);

Logger.configure('app', handlers: [dashboard]);
```

<p align="center">
  <img src="https://raw.githubusercontent.com/pooriaaskarim/logd/master/assets/img/logd_network_dashboard_preview.webp" alt="logd_network Embedded Dashboard Preview" width="780" />
</p>

---

### 2. `HttpSink` (Batch Shipping, Circuit Breaker & Resilience)
Accumulates log entries in memory and posts them in batches to remote log aggregators (e.g. Datadog, Loggly, Vector, or custom HTTP ingestion endpoints) with enterprise-grade resilience:

- **Dynamic Auth Hooks (`headersProvider`)**: Evaluated before each batch POST and re-evaluated during retry backoffs for seamless OAuth2 token refreshing.
- **Circuit Breaker (`CircuitState`)**: Configurable `failureThreshold` and `recoveryTimeout`. Trips to `open` on repeated outages to fail-fast into memory buffers, probe back via `halfOpen`, and close automatically.
- **Failover Endpoints (`failoverUrls`)**: In-flight retries seamlessly cycle to backup endpoints before dropping logs.
- **HTTP Backpressure (`Retry-After`)**: Transparently parses and respects server-instructed 429/503 `Retry-After` cooldowns (integer seconds and standard HTTP-date formats).
- **GZip Batch Compression (`compress: true`)**: Shrinks payload sizes by up to 90%+ over the wire (platform-safe across VM, Flutter, and Web).

```dart
final httpHandler = Handler(
  formatter: const JsonFormatter(),
  sink: HttpSink(
    url: 'https://primary.example.com/api/v1/ingest',
    // Failover Endpoints: seamless fallback if primary endpoint fails
    failoverUrls: const [
      'https://backup-1.example.com/api/v1/ingest',
      'https://backup-2.example.com/api/v1/ingest',
    ],
    // Dynamic Auth: evaluated before each batch POST & re-evaluated on retry
    headersProvider: () async {
      final token = await authManager.getFreshAccessToken();
      return {'Authorization': 'Bearer $token'};
    },
    // GZip Compression: up to 90%+ bandwidth savings for telemetry batches
    compress: true,
    // Circuit Breaker: prevents endpoint flooding during prolonged outages
    failureThreshold: 3,
    recoveryTimeout: const Duration(seconds: 30),
    // Batching & Buffer configuration
    batchSize: 50,
    flushInterval: const Duration(seconds: 30),
    maxRetries: 5,
    dropPolicy: DropPolicy.discardOldest,
  ),
);

Logger.configure('app', handlers: [httpHandler]);
```

**Drop Policies:**
- `DropPolicy.discardOldest`: Evicts the oldest buffered entry when capacity is reached.
- `DropPolicy.discardNewest`: Rejects incoming entries when buffer is full.

---

### 3. `SocketSink` (Real-Time WebSocket Streaming & Heartbeats)
Streams logs frame-by-frame over WebSockets with automatic reconnection, offline buffering, and proactive connection health checks:

- **WebSocket Heartbeats**: Periodically sends ping frames (`heartbeatInterval`). If a pong response is not received within `heartbeatTimeout`, the connection is proactively marked dead and reconnected.
- **Stream Monitoring**: Listens to the incoming WebSocket channel stream to catch silent drops and remote TCP termination instantly.

> **Platform Note:** Fully compatible across all platforms including Web and WASM via `package:web_socket_channel`. In browser targets, it connects directly using native browser WebSockets (`window.WebSocket`).

```dart
final wsHandler = Handler(
  formatter: const PlainFormatter(metadata: {LogMetadata.timestamp, LogMetadata.logger}),
  decorators: const [StyleDecorator(), BoxDecorator()],
  sink: SocketSink(
    url: 'wss://stream.example.com/live-logs',
    reconnectInterval: const Duration(seconds: 5),
    // WebSocket Heartbeats: proactive dead-link detection
    heartbeatInterval: const Duration(seconds: 15),
    heartbeatTimeout: const Duration(seconds: 5),
    pingMessage: '{"type":"ping"}',
    pongMessage: '{"type":"pong"}',
  ),
);

Logger.configure('app.stream', handlers: [wsHandler]);
```

---

### 4. `HttpServerSink` (Low-Level Custom Dashboard Sink)
If you want to use custom formatters (like `ToonFormatter`), custom decorators, or custom encoders while hosting a local browser server, use `HttpServerSink` directly:

> **Platform Note:** Supported on VM platforms only (server, desktop, CLI). Throws `UnsupportedError` on Web runtimes.

```dart
final serverSink = HttpServerSink(
  address: 'localhost',
  port: 8085,
  encoder: const HtmlEncoder(title: 'Custom Terminal Stream'),
  bufferCapacity: 500,
);

final customHandler = Handler(
  formatter: const ToonFormatter(),
  sink: serverSink,
);

Logger.configure('custom', handlers: [customHandler]);
```

---

## Cross-Isolate Serialization

If transferring logger configurations to background worker isolates via `Logger.exportConfig()` and `Logger.importConfig()`, register network serializers in the worker isolate before importing:

```dart
import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

void workerIsolateEntry(SendPort sendPort) {
  // Register logd_network serializers
  registerLogdNetworkSerializers();

  // Import config passed from main isolate
  Logger.importConfig(exportedJson);
}
```

---

## Interactive CLI Examples Gallery

`logd_network` provides an interactive CLI showcase menu in `example/showcase_gallery.dart`:

```bash
# Run interactive CLI showcase menu
dart run example/showcase_gallery.dart

# Or run non-blocking automated summary
dart run example/showcase_gallery.dart all
```

Or run individual standalone showcase scripts:

```bash
dart run example/showcase/http_sink_showcase.dart
dart run example/showcase/socket_sink_showcase.dart
dart run example/showcase/http_server_sink_showcase.dart
dart run example/showcase/http_dashboard_showcase.dart
```

### Standalone Resilience & Transport Demos

Run self-contained in-process demonstrations with zero external dependencies:

```bash
# 1. Dynamic Authentication & Token Rotation Demo
dart run example/dynamic_auth_example.dart

# 2. Circuit Breaker, Failover & Retry-After Demo
dart run example/circuit_breaker_example.dart

# 3. GZip Batch Compression Demo (90%+ Bandwidth Savings)
dart run example/compression_example.dart

# 4. WebSocket Heartbeat & Self-Healing Reconnect Demo
dart run example/heartbeat_example.dart
```

---

## Migration from `logd` <=0.9.7

In `logd` v0.10.0, all network transport sinks (`NetworkSink`, `HttpSink`, `SocketSink`, `HttpServerSink`, `HttpDashboardHandler`) were permanently removed from core `package:logd`.

- All network logging, HTTP batch shipping, and embedded dashboard capabilities are now exclusively provided by `package:logd_network`.
- Core `package:logd` contains zero network dependencies (e.g. `package:http`, `package:web_socket_channel`).
- For detailed migration instructions, see the [Migration Guide](doc/migration_guide.md).

---

## Documentation & Monorepo

For deep-dive documentation on `logd` architecture, migration guides, and execution engines:

- [**logd Monorepo Root**](https://github.com/pooriaaskarim/logd)
- [**Migration Guide**](https://github.com/pooriaaskarim/logd/blob/master/doc/migration.md)
- [**ADR-007: Satellite Package Architecture**](https://github.com/pooriaaskarim/logd/blob/master/doc/decisions/adr-007-satellite-package-extraction.md)

---

## License

This package is licensed under the **BSD 3-Clause License**. See the [LICENSE](LICENSE) file for details.
