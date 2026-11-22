# logd_network Architecture

`logd_network` provides real-time network logging, HTTP batch ingesters, WebSocket streams, and live browser dashboard sinks for the `logd` logging ecosystem.

## Core Components

### 1. `HttpSink`
A high-throughput, batch-oriented `LogSink` that buffers log entries and POSTs them to remote HTTP endpoints:
- **Delivery Formats (`HttpDeliveryFormat`)**: Supports standard JSON array batches (`jsonArray`, `application/json`), Newline-Delimited JSON streams (`ndjson`, `application/x-ndjson`), and raw byte streams (`raw`, `application/octet-stream`). Payload joining utilizes zero-copy `BytesBuilder` assembly.
- **Batching & Buffering (`batchSize`, `flushInterval`, `maxBufferBytes`)**: Reduces network socket overhead with dual count and byte-based memory budgeting.
- **Resilience & Backoff**: Configurable retry counts (`maxRetries`) paired with `BackoffPolicy` supporting decorrelated randomized jitter to prevent thundering-herd reconnect storms.
- **Circuit Breaker (`CircuitState`) & Failovers**: Seamless failover to secondary endpoints (`failoverUrls`) and automatic fast-failing during prolonged outages with probe-based half-open recovery.
- **HTTP Backpressure & Compression**: Pure-Dart `Retry-After` cooldown parsing and GZip batch compression.

### 2. `SocketSink`
A WebSocket streaming `LogSink` that maintains a persistent connection (`wss://` or `ws://`) to stream log entries in real time:
- **Self-Healing Reconnection**: Employs `BackoffPolicy` for exponential, jittered reconnect loops on connection drops.
- **Heartbeats & Stream Health**: Sends periodic ping frames (`heartbeatInterval`) and verifies pong responses (`heartbeatTimeout`), catching dead TCP links instantly.
- **Native Handshake Headers**: Supplies cross-platform HTTP handshake headers and subprotocols.

### 3. `BackoffPolicy` & Memory Eviction
- **`BackoffPolicy`**: An `@immutable` policy determining backoff delays between attempts. Computes exponential progressions with optional decorrelated randomized jitter (`[0.5 * delay, 1.5 * delay]`), capped at `maxDelay`. Fully serializable across Dart isolates.
- **Priority Eviction (`DropPolicy.discardByPriority`)**: Under high memory pressure (`maxBufferBytes` or capacity limits), evicts lowest-severity log entries first (`debug` -> `info` -> `warning` -> `error`), guaranteeing retention of critical failures.

### 4. `HttpServerSink` & `HttpDashboardHandler`
A self-contained HTTP/WebSocket server that hosts an interactive real-time HTML browser dashboard (`dashboard_html.dart`):
- Serves an inline single-page log viewer dashboard over HTTP GET `/` protected by host validation, origin checks, and optional auth tokens.
- Broadcasts formatted log entries over WebSocket (`ws://`).
- Features client-side lossless queue buffering on pause, logger namespace hierarchy filtering, regex search with live match counters, and NDJSON file export.
- `HttpDashboardHandler.async(...)` runs the dashboard server in a background Dart isolate with dynamic port 0 discovery.
