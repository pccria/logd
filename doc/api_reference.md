# logd API Reference

A comprehensive catalog of public classes, methods, configurations, and satellite packages in the `logd` ecosystem.

---

## Table of Contents

1. [Core Logging API](#1-core-logging-api)
   - [Logger](#logger)
   - [LogLevel](#loglevel)
   - [LoggerConfig](#loggerconfig)
   - [LogContext (MDC)](#logcontext-mdc)
   - [LogEntry](#logentry)
   - [LogBuffer](#logbuffer)
   - [LoggerMetrics](#loggermetrics)
2. [Handlers & Pipelines](#2-handlers--pipelines)
   - [Pre-Wired Handlers](#pre-wired-handlers)
   - [Handler (Custom Pipeline)](#handler-custom-pipeline)
   - [Formatters](#formatters)
   - [Decorators](#decorators)
   - [Sinks & Rotation](#sinks--rotation)
   - [Filters](#filters)
3. [Execution Engines](#3-execution-engines)
4. [Time & Stack Traces](#4-time--stack-traces)
5. [Satellite Packages API](#5-satellite-packages-api)

---

## 1. Core Logging API

### Logger

The central entry point for logging operations and hierarchy management.

```dart
class Logger {
  final String name;

  // Retrieval
  static Logger get([String? name]);

  // Logging Methods
  void trace(Object? message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context});
  void debug(Object? message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context});
  void info(Object? message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context});
  void warning(Object? message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context});
  void error(Object? message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context});

  // Multi-line Buffers (Null if logger is disabled)
  LogBuffer? get traceBuffer;
  LogBuffer? get debugBuffer;
  LogBuffer? get infoBuffer;
  LogBuffer? get warningBuffer;
  LogBuffer? get errorBuffer;

  // Configuration
  static void configure(String name, {
    LogLevel? logLevel,
    List<Handler>? handlers,
    Timestamp? timestamp,
    StackTraceParser? stackTraceParser,
    bool? enabled,
    bool? includeFileLineInHeader,
    bool? includeOrigin,
  });

  static void configureMultiple(Map<String, LoggerConfig> configs);
  static void configurePattern(String globPattern, {LogLevel? logLevel, bool? enabled, List<Handler>? handlers});

  // Hierarchy Inspection & Optimization
  static void printHierarchy();
  static String formatHierarchy();
  static Map<String, dynamic> exportHierarchy();
  void freezeInheritance({bool force = false});
  void unfreezeInheritance({Set<String>? fields, bool includeSelf = true});

  // Lifecycle & Teardown
  static void reset([String? loggerName]);

  // Fail-Safe Fallback Handler
  static void Function(LogEntry entry, Object? error, StackTrace? stackTrace)? fallbackHandler;
}
```

---

### LogLevel

Enumeration of severity levels:

| Level | Priority | Purpose |
|---|---|---|
| `LogLevel.trace` | Lowest | Deep diagnostic noise, loop iterations, internal engine states |
| `LogLevel.debug` | Low | Development debugging information |
| `LogLevel.info` | Medium | Milestone events (server started, user logged in, order placed) |
| `LogLevel.warning` | High | Recoverable issues or degraded behavior |
| `LogLevel.error` | Highest | Unhandled exceptions and operational failures |

---

### LoggerConfig

A sparse, immutable data class containing explicit overrides for a logger node. Null values denote inheritance from ancestors.

```dart
@immutable
class LoggerConfig {
  const LoggerConfig({
    this.logLevel,
    this.handlers,
    this.timestamp,
    this.stackTraceParser,
    this.enabled,
    this.includeFileLineInHeader,
    this.includeOrigin,
  });

  final LogLevel? logLevel;
  final List<Handler>? handlers;
  final Timestamp? timestamp;
  final StackTraceParser? stackTraceParser;
  final bool? enabled;
  final bool? includeFileLineInHeader;
  final bool? includeOrigin;
}
```

---

### LogContext (MDC)

Zone-based Mapped Diagnostic Context. Automatically propagates structured metadata across async boundaries, microtasks, and child futures.

```dart
abstract final class LogContext {
  /// Binds [context] to the current asynchronous Zone and executes [body].
  /// Downstream calls to any logger inherit these keys with zero parameter passing.
  static R run<R>(Map<String, dynamic> context, R Function() body);

  /// Retrieves the current ambient context map in this Zone.
  static Map<String, dynamic> get current;
}
```

---

### LogEntry

The immutable record dispatched to handlers when a log call is accepted.

```dart
class LogEntry {
  final LogLevel level;
  final String message;
  final String loggerName;
  final DateTime timestamp;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic> context;
  final String? callerOrigin; // (file:line:col) when includeOrigin is true
}
```

---

### LogBuffer

Atomic multi-line buffer extending `StringBuffer`. Prevents log interleaving in concurrent or multi-threaded scenarios.

```dart
class LogBuffer {
  void writeln([Object? obj = '']);
  void write(Object? obj);

  /// Flushes all accumulated lines into a single atomic LogEntry.
  void sink();
}
```

---

### LoggerMetrics

Isolate-local zero-cost telemetry counters for observing logger engine health.

```dart
abstract final class LoggerMetrics {
  static int get totalEntries;
  static int get droppedEntries;
  static int get cacheHits;
  static int get cacheMisses;
  static int get handlerFailures;
  static int get bufferLeaks;

  static Map<String, dynamic> toJson();
  static void reset();
}
```

---

## 2. Handlers & Pipelines

### Pre-Wired Handlers

Ready-to-use handlers that assemble standard formatters, decorators, and sinks:

```dart
// Terminal ANSI output (supports DarkTheme and LightTheme)
ConsoleHandler({LogTheme? theme, int? lineLength})
ConsoleHandler.async({LogTheme? theme, int? lineLength}) // Offloaded to worker isolate

// Structured JSON to file
JsonFileHandler(String path, {bool pretty = false})
JsonFileHandler.async(String path, {bool pretty = false})

// Plain text to file
PlainFileHandler(String path)
PlainFileHandler.async(String path)

// Synchronous in-memory ring buffer (ideal for unit testing and debug drawers)
MemoryHandler({int capacity = 200})
```

---

### Handler (Custom Pipeline)

The core modular processor decoupling formatting, decoration, filtering, and output sinks.

```dart
class Handler {
  Handler({
    required Formatter formatter,
    List<Decorator> decorators = const [],
    required Sink sink,
    List<Filter> filters = const [],
  });

  /// Factory constructor to run any custom pipeline on a background isolate:
  static Handler async({
    required Formatter formatter,
    List<Decorator> decorators = const [],
    required Sink sink,
    List<Filter> filters = const [],
  });
}
```

---

### Formatters

Formatters transform a `LogEntry` into an intermediate semantic document (`LogDocument`).

* `StructuredFormatter`: Formats logs with headers, timestamps, origin paths, and structured context trees.
* `JsonFormatter`: Emits standardized JSON lines with configurable metadata fields (`metadata: {LogMetadata.timestamp, LogMetadata.logger}`).
* `PlainFormatter`: Emits simple, human-readable text logs.

---

### Decorators

Decorators enhance the visual layout or styling of a `LogDocument`:

* `BoxDecorator`: Wraps logs in terminal border boxes (`BorderStyle.rounded`, `BorderStyle.single`, `BorderStyle.double`).
* `StyleDecorator`: Applies ANSI coloring, foreground/background themes, and syntax highlights.
* `HierarchyDepthPrefixDecorator`: Indents logs with tree branch markers (e.g., `│  └── `) based on logger hierarchy depth.

---

### Sinks & Rotation

Sinks write formatted byte/string sequences to physical targets:

* `ConsoleSink(int lineLength)`: Writes to standard output / standard error.
* `FileSink(String path, {FileRotation? fileRotation})`: Writes to a local file.
* `MultiSink(List<Sink> sinks)`: Fans out log output to multiple sinks in parallel.
* `CaptureSink`: In-memory sink capturing entries for unit test assertions (`hasLog()`).

**File Rotation Policies:**
* `SizeRotation(String maxSize, {int backupCount = 5, bool compress = true})` (e.g., `maxSize: '10 MB'`).
* `TimeRotation(Duration interval, {int backupCount = 7, bool compress = true})`.

---

### Filters

Control entry propagation through handler pipelines:

* `LevelFilter(LogLevel minLevel)`: Accepts entries at or above `minLevel`.
* `RegexFilter(Pattern pattern, {bool exclude = false})`: Matches against log message text.
* `ContextFilter(String key, {dynamic value})`: Matches against presence or value of ambient context keys.

---

## 3. Execution Engines

Selectable layout and execution engines tailored to different throughput and memory constraints:

| Engine | Allocation Model | Platform | Use Case |
|---|---|---|---|
| `StandardEngine` | GC Heap | All (VM, Web, Flutter) | Default. High safety and general usage. |
| `ArenaEngine` | LIFO Object Pool | Dart VM / Native | High-frequency logging with zero GC heap churn. |
| `NativeEngine` | C Heap via `dart:ffi` | Dart VM / Native | Maximum throughput ANSI terminal wrapping. |

---

## 4. Time & Stack Traces

### Timestamp & Timezone
* `Timestamp(formatter: 'yyyy-MM-dd HH:mm:ss.SSS', timezone: Timezone.local())`: Precise timestamp formatting.
* `Timestamp.dateOnly('yyyy-MM-dd')`: Fast-path bypass for daily aggregate or audit logs.
* `Timezone.local()`, `Timezone.utc()`, `Timezone.named('America/New_York')`, `Timezone.offset(Duration(hours: 3))`.

### StackTraceParser
* Sanitizes noisy stack traces by stripping internal framework frames:
  ```dart
  StackTraceParser(ignorePackages: ['logd', 'flutter', 'shelf'], maxMethodCount: 8)
  ```

---

## 5. Satellite Packages API

Specialized formatters, databases, and network adapters maintained within the `logd` ecosystem:

### [`package:logd_dio`](../packages/logd_dio)
* **`LogdDioInterceptor([LogdDioOptions options])`**: Production-grade Dio interceptor tracking monotonic latencies, formatted request/response lifecycles, W3C distributed tracing, bandwidth metrics, zero-buffering stream telemetry, and failure diagnostics.
* **`LogdDioOptions(...)`**: Configuration object for interceptor behaviors:
  - `logger`: Explicit `Logger` instance (defaults to `Logger.get('http')`).
  - `requestLevel` / `responseLevel` / `errorLevel`: Log levels for request lifecycle phases (default: `debug`, `info`, `error`).
  - `warningLevel`: Log level for elevated 4xx client errors (default: `LogLevel.warning`).
  - `cancelLevel`: Log level for requests aborted via `CancelToken` (default: `LogLevel.debug`).
  - `elevateHttpErrors`: Automatically elevates 4xx status to `warningLevel` and 5xx to `errorLevel` even in non-throwing pipelines where Dio's `validateStatus` evaluates to true (default: `true`).
  - `logRequestHeaders` / `logRequestBody`: Toggles for request metadata logging (default: `true`, `true`).
  - `logResponseHeaders` / `logResponseBody`: Toggles for response metadata logging (default: `false`, `true`).
  - `logMetrics`: Computes monotonic latency, request/response byte sizing, derived throughput (KB/s), and status categories (default: `true`).
  - `logStreamMetrics`: Monitors streaming downloads (`ResponseType.stream`) transparently with zero heap buffering, emitting a `STREAM_COMPLETED` log event on finish (default: `true`).
  - `logCurl`: Generates copy-pasteable executable cURL command in request log context (default: `false`).
  - `prettyCurl`: Formats generated cURL commands across multiple lines with trailing backslashes and indentation (default: `false`).
  - `maxBodyLength`: Maximum character length before payload strings are safely truncated (default: `1024`).
  - `tracePropagationMode`: Header injection mode: `both` (W3C + custom), `w3c` (`traceparent` + `tracestate`), `custom` (`traceIdHeader`), or `none` (default: `TracePropagationMode.both`).
  - `attachAmbientTraceId`: Automatically injects `LogContext.current['requestId']` into outgoing headers (default: `true`).
  - `traceIdHeader`: Target header name for ambient trace ID injection (default: `'x-request-id'`).
  - `w3cTraceContextKey`: Context key for resolving ambient `W3cTraceContext` (default: `'w3cTraceContext'`).
  - `extractServerTraceContext`: Automatically extracts server-emitted `traceparent` from response headers into `context['serverTraceparent']` (default: `true`).
  - `bodySerializer`: Pluggable `LogdBodySerializer` for custom serialization of domain payloads such as Protobuf, XML, and FlatBuffers.
  - `redactedPlaceholder`: Replacement string for sensitive values (default: `'***REDACTED***'`).
  - `sensitiveHeaders`: Set of header names redacted case-insensitively (default: `defaultSensitiveHeaders`).
  - `sensitiveQueryParams`: Set of query parameter keys redacted case-insensitively (default: `defaultSensitiveQueryParams`).
* **`W3cTraceContext`**: Level 1 W3C Recommendation distributed tracing model:
  - `W3cTraceContext.generate({bool isSampled = true, String? tracestate})`: Generates unique 16-byte `traceId` and 8-byte `spanId`.
  - `W3cTraceContext.parse(String traceparent, {String? tracestate})`: Strictly parses W3C headers (enforcing version `00`).
  - `context.childSpan({String? tracestate})`: Derives a child span preserving root transaction `traceId`.
  - `context.traceparent`: Standard serialized header (`00-${traceId}-${spanId}-${traceFlags}`).
  - `context.toJson()` / `W3cTraceContext.fromJson(map)`: Serialization for ambient `LogContext` propagation across isolates.
* **`HttpMetrics`**:
  - `durationMs`: High-precision monotonic elapsed time.
  - `requestBytes` / `responseBytes`: Total calculated payload and header byte footprint.
  - `throughputKBps`: Derived network throughput in KB/s.
  - `statusCategory`: Classifies status into `1xx`, `2xx`, `3xx`, `4xx`, `5xx`.
* **`StreamMetricsTracker`**: Transparent `StreamTransformer` wrapping `ResponseBody.stream` without intermediate buffering, computing cumulative byte metrics and firing `STREAM_COMPLETED` upon stream termination.
* **`LogdBodySerializer` & `FunctionalBodySerializer`**: Abstract interface and closure wrapper for formatting custom domain objects into inspectable strings prior to sanitization.
* **`LogdCurlGenerator.generate(RequestOptions options, {Set<String> sensitiveHeaders, String placeholder, bool pretty})`**: Generates sanitized, executable cURL commands from Dio request options with `--compressed` auto-detection.
* **`LogdSanitizer`**:
  - `sanitizeHeaders(Map<String, dynamic> headers, Set<String> sensitive, String placeholder)`: Redacts credentials case-insensitively.
  - `sanitizeQueryParams(Map<String, dynamic> query, Set<String> sensitive, String placeholder)`: Redacts query strings.
  - `safeBodyPreview(Object? body, {int maxBodyLength, LogdBodySerializer? serializer, String? contentType, bool isRequest})`: Formats JSON, strings, `FormData`, and binary streams safely without memory crashes.
* **Showcase Gallery Runner**: `dart run packages/logd_dio/example/showcase_gallery.dart` (runs 8 modular scenarios covering basic integration, SOC2 sanitization, distributed tracing, error resilience, cURL generation, W3C tracing, streaming telemetry, and custom serializers).

### [`package:logd_toon`](../packages/logd_toon)
* **`ToonFormatter({ToonDialect dialect = ToonDialect.compact, bool sortKeys = false, int maxDepth = 4, bool explicitSchema = false, String delimiter = '\t', List<String>? contextColumns})`**: Emits Tab-Oriented Object Notation (30–50% fewer tokens than JSON for LLMs) with optional `contextColumns` fixed tabular projection.
* **`ToonFileHandler(String path, {ToonDialect dialect, bool explicitSchema, Set<LogMetadata>? metadata, bool sortKeys, int maxDepth, List<String>? contextColumns, ...})`**: Pre-wired synchronous file logging handler for TOON logs.
* **`ToonFileHandler.async(String path, ...)`**: Offloads TOON formatting, escaping, and disk I/O to a dedicated background isolate worker with full parameter parity.
* **`ToonDecoder({ToonDialect dialect = ToonDialect.compact})`**: Bidirectional parser converting raw TOON text or asynchronous streams into strongly typed `ToonDocument` and `ToonRecord` instances with state-machine unescaping and nested context decoding.
* **`ToonDocument`**: Complete parsed TOON document exposing immutable `schema` and `records`.
* **`ToonRecord`**: Strongly typed row accessor providing `timestamp`, `logger`, `origin`, `level`, `message`, `error`, `stackTrace`, and `context`.
* **`ToonSchema({required String name, required List<String> columns, Map<String, String> columnTypes, ToonDialect dialect})`**: Structured schema model supporting `parse`, `parseBytes` (8KB zero-allocation preamble scan), `toPreamble`, `toJson`, and `fromJson`.
* **`ToonContextWindow.slice(String toonSource, {int? maxTokens, int? maxRows, String? truncationIndicator})` & `ToonContextWindow.sliceBytes(Uint8List bytes, ...)`**: Token-budgeted sliding-window tail slicer for LLM prompts with guaranteed preamble retention and truncation notice.
* **`ToonTokenEstimator.estimateTokens(String text)`**: Zero-dependency calibrated BPE heuristic token counter calibrated against OpenAI cl100k and Anthropic Claude tokenizers.
* **`ToonTokenEstimator.analyze(String toonSource)` & `analyzeDocument(ToonDocument document)`**: Returns `ToonTokenMetrics` measuring exact token savings, byte reductions, and percentage efficiency gains over JSON (`savingsPercent`).
* **`ToonDuckDb.selectQuery(ToonSchema schema, {required String filePath, String? whereClause, int? limit})`**: Generates zero-copy DuckDB SQL queries utilizing `read_csv()`.
* **`ToonDuckDb.createTableSql(ToonSchema schema, {String? tableName, bool ifNotExists = true})` & `ToonDuckDb.ingestSql(ToonSchema schema, {required String filePath, String? tableName})`**: Generates DDL table creation and `INSERT INTO ... SELECT * FROM read_csv(...)` ingestion statements mapping TOON schema column definitions to DuckDB types.
* **`registerLogdToonSerializers()`**: Registers all TOON formatter and handler deserializers with the core `LoggerSerializationRegistry` for multi-isolate configuration syncing.
* **Showcase Gallery Runner**: `dart run packages/logd_toon/example/showcase_gallery.dart` (runs 6 modular scenarios demonstrating file logging, isolate offloading, context columns, decoding, LLM context budgeting, and DuckDB SQL generation).

### [`package:logd_sqlite`](../packages/logd_sqlite)
* **`SqliteHandler(dbPath: ..., maxEntries: 5000, maxAge: Duration(days: 7), walMode: true)`**: WAL-mode SQLite persistence.
* **`sqliteHandler.queryLogs({LogLevel minLevel, String? search, int limit})`**: Rich query engine for offline error diagnostics.
* **`sqliteHandler.fetchLevelCounts()`**: Returns aggregated counts by severity.

### [`package:logd_network`](../packages/logd_network)
* **`HttpDashboardHandler({int port = 8080, String? title, int bufferCapacity = 500, int maxConnections = 32, Set<String>? allowedHosts, String? authToken})`**: Pre-wired handler hosting an embedded real-time browser telemetry dashboard over HTTP + WebSockets. Features live stream pause ring buffering, regex filtering, subsystem dropdown discovery, and NDJSON export.
* **`HttpDashboardHandler.async(...)`**: Spawns the telemetry dashboard inside a dedicated background worker isolate with dynamic ephemeral port binding (`port: 0`), reporting the resolved `boundPort` back to the main isolate.
* **`HttpSink({required String url, int batchSize = 50, Duration flushInterval = const Duration(seconds: 5), HttpDeliveryFormat deliveryFormat = HttpDeliveryFormat.jsonArray, BackoffPolicy backoffPolicy = const BackoffPolicy(), int maxBufferSize = 500, int maxBufferBytes = 2 * 1024 * 1024, DropPolicy dropPolicy = DropPolicy.discardOldest, List<String>? failoverUrls, bool compress = false, FutureOr<Map<String, String>> Function()? headersProvider, void Function(List<Uint8List>)? onDropped})`**: High-throughput HTTP batch log shipping with exponential jittered backoff, circuit-breaker failover routing, dual memory budgeting, GZip compression, and decoupled offline spooling hooks.
* **`SocketSink({required String url, BackoffPolicy backoffPolicy = const BackoffPolicy(), Duration heartbeatInterval = const Duration(seconds: 30), Duration heartbeatTimeout = const Duration(seconds: 10), int maxBufferSize = 500, int maxBufferBytes = 1024 * 1024, DropPolicy dropPolicy = DropPolicy.discardOldest, List<String>? protocols, Map<String, dynamic>? headers})`**: Persistent WebSocket (`ws://` or `wss://`) streaming sink with self-healing reconnect loops, ping/pong heartbeats, and malformed-byte immunity.
* **`HttpServerSink({dynamic address, int port = 8080, String? title, int bufferCapacity = 500, int maxConnections = 32, Set<String>? allowedHosts, Set<String>? allowedOrigins, String? authToken})`**: Low-level embedded HTTP/WebSocket server sink hosting the interactive single-page dashboard and broadcasting live log events.
* **`BackoffPolicy({Duration initialDelay = const Duration(milliseconds: 500), Duration maxDelay = const Duration(seconds: 30), double multiplier = 2.0, bool jitter = false})`**: `@immutable` policy computing exponential backoff delays with randomized decorrelated jitter (`[0.5 * delay, 1.5 * delay]`) to eliminate thundering-herd storms across distributed fleets. Fully serializable across isolates.
* **`HttpDeliveryFormat`**: Ingestion payload formats: `jsonArray` (`application/json`), `ndjson` (Newline-Delimited JSON, `application/x-ndjson`), and `raw` (delimited byte stream, `application/octet-stream`).
* **`DropPolicy`**: Buffer overflow policies: `discardOldest` (FIFO drop), `discardNewest` (drops incoming entries), and `discardByPriority` (preserves critical errors by evicting lowest-severity entries first with atomic headroom pre-validation).
* **`registerLogdNetworkSerializers()`**: Registers all network sink and handler deserializers (`HttpSink`, `SocketSink`, `HttpServerSink`, `HttpDashboardHandler`) with the core `LoggerSerializationRegistry` for multi-isolate configuration syncing.

### [`package:logd_html`](../packages/logd_html)
* **`HtmlFileHandler(String path, ...)`**: Generates self-contained HTML reports with dynamic dark/light theme switching, single-document append resilience, and search indexing.
* **`HtmlFileHandler.async(String path, ...)`**: Offloads HTML document formatting, serialization, and disk persistence to a dedicated background isolate.
* **`HtmlView({HtmlHeaderComponent? header, HtmlControlPanelComponent? controlPanel, HtmlFooterComponent? footer})`**: Modular view orchestrator defining document structure, branding, controls, and footers.
* **`HtmlView.embedded(...)`**: Produces shell-less HTML fragments without `<!DOCTYPE html>`, `<head>`, or `<body>` wrappers, designed for embedding into web portals and dashboards.
* **`DefaultHtmlControlPanel.all(...)`**: Preconfigures the complete interactive toolbar: in-memory search bar, regex mode, subsystem dropdown, level filter pills, live follow auto-scroll, theme toggle, and JSON/CSV export buttons.
* **`HtmlActionButton(String id, String label, String onClickJs)`**: Injects custom interactive toolbar buttons executing arbitrary client-side JavaScript.
* **`HtmlFileMode`**: Controls file output lifecycle: `appendSession` (rewinds closing tags and inserts session delimiter), `overwrite` (truncates file), or `fragment` (raw entry elements).
* **`HtmlEncoder`**: Serializes `LogDocument` semantic nodes into accessible HTML5 markup with zero external CDN dependencies.
* **`HtmlFormatter`**: Semantic formatter that maps `LogEntry` into `LogDocument` and auto-injects `HtmlEncoder`.

### [`package:logd_markdown`](../packages/logd_markdown)
* **`MarkdownFileHandler(String path)`**: Generates GitHub-Flavored Markdown files (ideal for `$GITHUB_STEP_SUMMARY` in CI/CD).
