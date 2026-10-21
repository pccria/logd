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
* **`LogdDioInterceptor([LogdDioOptions options])`**: Production-grade Dio interceptor tracking monotonic latencies, formatted request/response lifecycles, and failure diagnostics.
* **`LogdDioOptions(...)`**: Configuration object for interceptor behaviors:
  - `logger`: Explicit `Logger` instance (defaults to `Logger.get('http')`).
  - `requestLevel` / `responseLevel` / `errorLevel`: Log levels for request lifecycle phases (default: `debug`, `info`, `error`).
  - `cancelLevel`: Log level for requests aborted via `CancelToken` (default: `LogLevel.debug`).
  - `logRequestHeaders` / `logRequestBody`: Toggles for request metadata logging (default: `true`, `true`).
  - `logResponseHeaders` / `logResponseBody`: Toggles for response metadata logging (default: `false`, `true`).
  - `logCurl`: Generates copy-pasteable executable cURL command in request log context (default: `false`).
  - `maxBodyLength`: Maximum character length before payload strings are safely truncated (default: `1024`).
  - `attachAmbientTraceId`: Automatically injects `LogContext.current['requestId']` into outgoing headers (default: `true`).
  - `traceIdHeader`: Target header name for ambient trace ID injection (default: `'x-request-id'`).
  - `redactedPlaceholder`: Replacement string for sensitive values (default: `'***REDACTED***'`).
  - `sensitiveHeaders`: Set of header names redacted case-insensitively (default: `defaultSensitiveHeaders`).
  - `sensitiveQueryParams`: Set of query parameter keys redacted case-insensitively (default: `defaultSensitiveQueryParams`).
* **`LogdCurlGenerator.generate(RequestOptions options, {Set<String> sensitiveHeaders, String placeholder})`**: Generates sanitized, executable cURL commands from Dio request options.
* **`LogdSanitizer`**:
  - `sanitizeHeaders(Map<String, dynamic> headers, Set<String> sensitive, String placeholder)`: Redacts credentials case-insensitively.
  - `sanitizeQueryParams(Map<String, dynamic> query, Set<String> sensitive, String placeholder)`: Redacts query strings.
  - `safeBodyPreview(Object? body, {int maxBodyLength})`: Formats JSON, strings, `FormData`, and binary streams safely without memory crashes.
* **Showcase Gallery Runner**: `dart run packages/logd_dio/example/showcase_gallery.dart` (runs 5 specialized interactive scenarios covering basic integration, SOC2 sanitization, distributed tracing, error resilience, and cURL generation).

### [`package:logd_toon`](../packages/logd_toon)
* **`ToonFormatter(dialect: ToonDialect.strict, sortKeys: true, maxDepth: 3)`**: Emits Tab-Oriented Object Notation (30–50% fewer tokens than JSON for LLMs).
* **`ToonFileHandler(String path)`**: Pre-wired file sink emitting TOON logs.
* **`ToonEncoder.extractPreamble(bytes)`**: Extracts schema preamble for sliding-window LLM prompts.

### [`package:logd_sqlite`](../packages/logd_sqlite)
* **`SqliteHandler(dbPath: ..., maxEntries: 5000, maxAge: Duration(days: 7), walMode: true)`**: WAL-mode SQLite persistence.
* **`sqliteHandler.queryLogs({LogLevel minLevel, String? search, int limit})`**: Rich query engine for offline error diagnostics.
* **`sqliteHandler.fetchLevelCounts()`**: Returns aggregated counts by severity.

### [`package:logd_network`](../packages/logd_network)
* **`HttpDashboardHandler(port: 8080, bufferCapacity: 500)`**: Hosts a live real-time browser dashboard over HTTP + WebSockets.
* **`HttpSink(url: ..., batchSize: 50, flushInterval: Duration(seconds: 10))`**: Resilient HTTP batch log shipping with retry policies.
* **`SocketSink(url: 'wss://...')`**: Live streaming to remote log aggregators.

### [`package:logd_html`](../packages/logd_html)
* **`HtmlFileHandler(String path)`**: Generates self-contained HTML reports with dynamic dark/light theme switching.

### [`package:logd_markdown`](../packages/logd_markdown)
* **`MarkdownFileHandler(String path)`**: Generates GitHub-Flavored Markdown files (ideal for `$GITHUB_STEP_SUMMARY` in CI/CD).
