# logd Production Cookbook

A collection of battle-tested, production-ready engineering patterns for integrating `logd` into Flutter mobile apps, backend services, network clients, and AI agent pipelines.

---

## Table of Contents

1. [Flutter: Zero-Jank Logging & Crash Resilience](#1-flutter-zero-jank-logging--crash-resilience)
2. [Networking: Secure HTTP Inspection with Dio](#2-networking-secure-http-inspection-with-dio)
3. [Backend: Distributed Request Tracing with Shelf & Dart Frog](#3-backend-distributed-request-tracing-with-shelf--dart-frog)
4. [Storage: Local SQLite Audit Trail & Diagnostic Reporter](#4-storage-local-sqlite-audit-trail--diagnostic-reporter)
5. [Observability: Live Remote Browser Dashboard over Wi-Fi](#5-observability-live-remote-browser-dashboard-over-wi-fi)
6. [AI & Agents: Deterministic Token-Efficient Telemetry (TOON)](#6-ai--agents-deterministic-token-efficient-telemetry-toon)
7. [CI/CD: GitHub Actions Job Summaries in Markdown](#7-cicd-github-actions-job-summaries-in-markdown)

---

## 1. Flutter: Zero-Jank Logging & Crash Resilience

### Problem
1. **120Hz Animation Jank**: File I/O on the main UI isolate causes frame drops and stutters during scrolling or complex transitions.
2. **Mobile Sandbox Path Resolution**: On iOS and Android, relative filesystem paths (like `'logs/app.json'`) fail due to OS-level app sandboxing.
3. **Uncaught Crashes**: Uncaught Flutter framework errors and unhandled asynchronous microtask errors can easily slip through without persistence.

### Solution
Initialize Flutter bindings, resolve the path through `path_provider`'s application support directory, offload file I/O to a background worker isolate using `JsonFileHandler.async()`, and route framework error delegates to `Logger.get('app.crash')`.

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logd/logd.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  // 1. Ensure Flutter engine and binary messenger are initialized before async calls
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Resolve safe, writeable app storage on iOS/Android
  final appSupportDir = await getApplicationSupportDirectory();
  final logFile = File('${appSupportDir.path}/logs/production.json');
  await logFile.parent.create(recursive: true);

  // 3. Configure the root logger hierarchy
  Logger.configure('app',
    logLevel: kReleaseMode ? LogLevel.info : LogLevel.debug,
    handlers: [
      if (kDebugMode)
        ConsoleHandler(theme: const DarkTheme()),

      // Offloads formatting, serialization, and disk writes to a background worker isolate:
      // UI thread returns in ~15µs; 120Hz frames are never dropped.
      JsonFileHandler.async(logFile.path),
    ],
  );

  // 4. Intercept synchronous framework widget & layout errors
  FlutterError.onError = (details) {
    Logger.get('app.crash').error(
      'Flutter framework error: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // 5. Intercept unhandled asynchronous exceptions from microtasks and native channels
  PlatformDispatcher.instance.onError = (error, stack) {
    Logger.get('app.crash').error(
      'Platform unhandled exception',
      error: error,
      stackTrace: stack,
    );
    return true; // Mark as handled to prevent sudden OS kill
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('logd Mobile Demo')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Logger.get('app.ui').info('User tapped checkout button');
            },
            child: const Text('Test Log Action'),
          ),
        ),
      ),
    );
  }
}
```

---

## 2. Networking: Secure HTTP Inspection with Dio

### Problem
1. **Security & Compliance Violations (SOC2 / GDPR)**: Naive network interceptors dump authorization tokens, session cookies, and API keys straight into disk logs in plaintext.
2. **Binary & Streaming Memory Exhaustion**: Buffering large responses or infinite Server-Sent Events (SSE) / token streams to compute metrics causes fatal Out-Of-Memory (OOM) crashes.
3. **Trace Tree Disconnection**: Heterogeneous backends instrumented with OpenTelemetry require standard W3C `traceparent` headers rather than fragmented custom header keys.
4. **Negative/Distorted Latencies**: Using `DateTime.now()` is subject to system clock drifts and NTP sync jumps.
5. **False Negative Errors in Non-Throwing Pipelines**: When applications configure `validateStatus: (s) => true`, 4xx/5xx responses are logged at `info` level, bypassing error monitoring.
6. **Opaque Non-JSON Payloads**: Protocol Buffers, FlatBuffers, or XML payloads cannot be inspected without custom serialization hooks.

### Solution
Use the official satellite package [`package:logd_dio`](../packages/logd_dio). It provides `LogdDioInterceptor` with automatic case-insensitive credential sanitization, W3C TraceContext Level 1 distributed tracing, monotonic `Stopwatch` latency timing, bandwidth profiling, zero-buffering stream telemetry, pluggable serializers, and executable cURL generation.

#### 1. Quick Integration

```dart
import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

// Attach the production interceptor
dio.interceptors.add(LogdDioInterceptor());
```

#### 2. Enterprise Production Configuration

```dart
dio.interceptors.add(
  LogdDioInterceptor(
    LogdDioOptions(
      // Output executable, pretty-formatted, sanitized cURL commands
      logCurl: true,
      prettyCurl: true,

      // Track network latency, byte sizing, and derived throughput (KB/s)
      logMetrics: true,

      // Monitor streaming downloads (SSE, chunked data) with zero heap buffering
      logStreamMetrics: true,

      // Automatically elevate 4xx to warning and 5xx to error in non-throwing pipelines
      elevateHttpErrors: true,
      warningLevel: LogLevel.warning,
      errorLevel: LogLevel.error,

      // W3C TraceContext Level 1 injection (traceparent + tracestate)
      tracePropagationMode: TracePropagationMode.both,
      extractServerTraceContext: true,

      // Truncate payloads longer than 512 characters to prevent log memory exhaustion
      maxBodyLength: 512,

      // Custom replacement token for sensitive values
      redactedPlaceholder: '[CONFIDENTIAL]',

      // Additional company-specific headers to redact
      sensitiveHeaders: {
        ...LogdDioOptions.defaultSensitiveHeaders,
        'x-internal-secret',
        'x-tenant-token',
      },

      // Additional query parameters to redact
      sensitiveQueryParams: {
        ...LogdDioOptions.defaultSensitiveQueryParams,
        'session_key',
        'signature',
      },

      // Treat user cancellations (CancelToken) as debug info rather than error alarms
      cancelLevel: LogLevel.debug,
    ),
  ),
);
```

#### 3. W3C Distributed Tracing with Ambient `LogContext`

When wrapping requests inside `LogContext.run()`, `LogdDioInterceptor` automatically injects standard W3C `traceparent` headers into outgoing requests:

```dart
final trace = W3cTraceContext.generate(isSampled: true);

await LogContext.run({
  'w3cTraceContext': trace.toJson(),
  'requestId': trace.traceId,
}, () async {
  // Outgoing request automatically carries:
  // traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
  // x-request-id: 4bf92f3577b34da6a3ce929d0e0e4736
  await dio.get('/orders');
});
```

#### 4. Zero-Buffering Stream Telemetry

For file downloads, Server-Sent Events (SSE), or chunked LLM token responses, set `logStreamMetrics: true`. The interceptor transparently wraps the `ResponseBody.stream` without retaining chunks in memory, emitting a `STREAM_COMPLETED` log event upon stream finish:

```dart
final response = await dio.get<ResponseBody>(
  '/stream/large-dataset',
  options: Options(responseType: ResponseType.stream),
);

// Stream is piped directly to file with zero heap buffer overhead:
await response.data!.stream.pipe(File('download.bin').openWrite());
// Interceptor automatically emits:
// [STREAM_COMPLETED] GET /stream/large-dataset (Chunks: 128, Bytes: 1048576, Duration: 312ms)
```

> [!TIP]
> **Interactive Runnable Examples**:
> The `packages/logd_dio` package includes a complete, executable demonstration gallery. Run:
> ```bash
> dart run packages/logd_dio/example/showcase_gallery.dart
> ```
> Or inspect individual specialized recipes:
> - [`example/main.dart`](../packages/logd_dio/example/main.dart): Basic integration & quick-start.
> - [`example/security/sanitization_example.dart`](../packages/logd_dio/example/security/sanitization_example.dart): Custom header/query redaction & `FormData`/binary safety.
> - [`example/tracing/distributed_tracing_example.dart`](../packages/logd_dio/example/tracing/distributed_tracing_example.dart): Ambient trace header injection & async zone isolation.
> - [`example/telemetry/w3c_tracing_and_metrics_example.dart`](../packages/logd_dio/example/telemetry/w3c_tracing_and_metrics_example.dart): W3C Level 1 traceparent, child spans, and throughput metrics.
> - [`example/streaming/stream_telemetry_example.dart`](../packages/logd_dio/example/streaming/stream_telemetry_example.dart): Zero-buffering stream telemetry for large/infinite responses.
> - [`example/serializers/custom_serializer_example.dart`](../packages/logd_dio/example/serializers/custom_serializer_example.dart): Pluggable serialization for Protobuf, XML, and custom domain payloads.
> - [`example/resilience/error_and_cancellation_example.dart`](../packages/logd_dio/example/resilience/error_and_cancellation_example.dart): `CancelToken` handling vs HTTP 4xx/5xx status elevation.
> - [`example/advanced/custom_pipeline_example.dart`](../packages/logd_dio/example/advanced/custom_pipeline_example.dart): Pretty-formatted cURL generation, response headers, and dedicated loggers.


---

## 3. Backend: Distributed Request Tracing with Shelf & Dart Frog

### Problem
1. **Parameter Pollution**: Threading `requestId` or `tenantId` through every service, repository, and SQL query signature clutters codebases.
2. **Missing Distributed Tracing**: If the server fails to return the `requestId` in HTTP response headers, clients have no correlation ID to include in error reports.

### Solution
Use `LogContext.run()` inside a Shelf middleware. Ambient metadata is bound to the async `Zone`, automatically propagating through all nested calls, and the `x-request-id` is injected into the outgoing response headers.

```dart
import 'package:logd/logd.dart';
import 'package:shelf/shelf.dart';

Middleware requestTracingMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final requestId = request.headers['x-request-id'] ??
          'req-${DateTime.now().microsecondsSinceEpoch}';
      final clientIp = request.headers['x-forwarded-for'] ??
          (request.context['shelf.io.connection_info'] as dynamic)?.remoteAddress.address ??
          'unknown';

      // LogContext.run binds ambient context to the async zone
      return LogContext.run({
        'requestId': requestId,
        'clientIp': clientIp,
        'method': request.method,
        'path': request.url.path,
      }, () async {
        final stopwatch = Stopwatch()..start();
        Logger.get('api.http').info('Incoming request');

        try {
          final response = await innerHandler(request);
          stopwatch.stop();

          Logger.get('api.http').info(
            'Request completed',
            context: {
              'status': response.statusCode,
              'latencyMs': stopwatch.elapsedMilliseconds,
            },
          );

          // Propagate requestId back to client in response headers for tracing
          return response.change(headers: {'x-request-id': requestId});
        } catch (e, st) {
          Logger.get('api.http').error(
            'Unhandled request failure',
            error: e,
            stackTrace: st,
          );
          rethrow;
        }
      });
    };
  };
}

// Deep inside business logic / data repositories:
class OrderService {
  Future<void> submitOrder(String orderId) async {
    // Zero boilerplate: 'requestId', 'clientIp', and 'path' are automatically included!
    Logger.get('api.orders').info('Processing payment for order: $orderId');
  }
}
```

---

## 4. Storage: Local SQLite Audit Trail & Diagnostic Reporter

### Problem
When a mobile app encounters an edge case, flat files are hard to parse and prune. You need a queryable database of recent errors and warnings that can be packaged into a diagnostics bundle.

### Solution
Use [`package:logd_sqlite`](../packages/logd_sqlite) configured in WAL mode. It handles auto-pruning, indexed lookups, and fast aggregation.

```dart
import 'dart:io';
import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:path_provider/path_provider.dart';

late final SqliteHandler sqliteHandler;

Future<void> initializeStorageLogger() async {
  final dir = await getApplicationSupportDirectory();
  final dbPath = '${dir.path}/logs/audit_trail.db';

  sqliteHandler = SqliteHandler(
    dbPath: dbPath,
    maxEntries: 5000,           // Automatically prunes older records
    maxAge: const Duration(days: 7),
    batchSize: 25,
    flushInterval: const Duration(seconds: 1),
    walMode: true,               // Safe non-blocking concurrent reading & writing
  );

  Logger.configure('app', handlers: [sqliteHandler]);
}

/// Invoked when a user taps "Send Diagnostic Logs" in the app settings screen
Map<String, dynamic> exportDiagnosticBundle() {
  // Retrieve only warnings and errors to keep the diagnostic payload lightweight
  final recentFailures = sqliteHandler.queryLogs(
    minLevel: LogLevel.warning,
    limit: 50,
  );

  final levelCounts = sqliteHandler.fetchLevelCounts();

  return {
    'exportedAt': DateTime.now().toIso8601String(),
    'levelBreakdown': levelCounts,
    'recentErrors': recentFailures.map((entry) => {
      'timestamp': entry.timestamp.toIso8601String(),
      'logger': entry.loggerName,
      'level': entry.level.name,
      'message': entry.message,
      'error': entry.error?.toString(),
    }).toList(),
  };
}
```

---

## 5. Observability: Live Remote Browser Dashboard over Wi-Fi

### Problem
Testing on physical hardware (Android TV, kiosks, tablets, iPads) without a connected USB debugger makes real-time inspection difficult.

### Solution
Attach `HttpDashboardHandler` from [`package:logd_network`](../packages/logd_network). It spins up a lightweight embedded HTTP/WebSocket server that hosts a live browser dashboard accessible from your development machine.

```dart
import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

void main() {
  Logger.configure('app', handlers: [
    ConsoleHandler(),

    // Serves an interactive dashboard at http://<device-ip>:8080
    HttpDashboardHandler.async(
      port: 8080,
      bufferCapacity: 500, // Ring buffer size for newly connecting browsers
    ),
  ]);

  Logger.get('app').info('Remote dashboard ready. Connect via local network IP:8080');
}
```

---

## 6. AI & Agents: Deterministic Token-Efficient Telemetry (TOON)

### Problem
1. **Context Window Token Waste**: Standard JSON repeats keys (`"timestamp"`, `"level"`, `"message"`, `"metadata"`) on every entry, wasting 30–50% of LLM prompt tokens.
2. **Context Window Overflows**: Naively slicing recent logs by line count risks exceeding token limits when large tool payloads or stack traces occur.
3. **Preamble Stripping**: Ad-hoc tail slicing strips away schema definitions, depriving reasoning models of column types.
4. **Cyclic Map Crashes & Non-Deterministic Order**: Nested tool results from LLM calls can contain cyclic objects or arbitrary key ordering that causes token jitter across runs.

### Solution
Use `ToonFileHandler` with `contextColumns`, `sortKeys: true`, and bounded depth `maxDepth: 3` from [`package:logd_toon`](../packages/logd_toon). Tab-Oriented Object Notation outputs the column schema once in a compact preamble, followed by tab-delimited rows. Use `ToonContextWindow` to slice recent logs strictly within token budgets.

```dart
import 'dart:io';
import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';

void setupAgentLogging() {
  Logger.configure('agent', handlers: [
    ToonFileHandler.async(
      path: 'logs/agent_session.toon',
      dialect: ToonDialect.strict,
      sortKeys: true, // Deterministic key ordering prevents token variance
      maxDepth: 3,    // Bounded depth guards against circular or deeply nested maps
      contextColumns: const ['tool', 'durationMs', 'status'], // Invariant columns
    ),
  ]);
}

void recordToolExecution(String toolName, Map<String, Object?> arguments, int durationMs) {
  Logger.get('agent.tools').info(
    'Tool executed: $toolName',
    context: {
      'tool': toolName,
      'durationMs': durationMs,
      'status': 'success',
      'args': arguments,
    },
  );
}

/// Slices the TOON log file to fit within an exact LLM prompt token budget
Future<String> buildTokenBudgetedPrompt(String logFilePath, {int maxTokens = 2048}) async {
  final file = File(logFilePath);
  if (!file.existsSync()) return '';
  final bytes = await file.readAsBytes();

  // Slices historical logs from tail up to maxTokens, guaranteeing preamble retention:
  final slice = ToonContextWindow.sliceBytes(
    bytes,
    maxTokens: maxTokens,
  );

  return '''
You are an autonomous engineering agent. Diagnose recent failures from these execution logs:
${slice.content}
''';
}

/// Measures token reduction of TOON against standard JSON
void logTokenSavings(String logContent) {
  final document = ToonDecoder().decode(logContent);
  final metrics = ToonTokenEstimator.compareWithJson(
    toonText: logContent,
    records: document.records.map((r) => r.toMap()).toList(),
  );

  print('JSON Tokens: ${metrics.jsonTokens}');
  print('TOON Tokens: ${metrics.toonTokens}');
  print('Saved: ${metrics.savedTokens} tokens (${metrics.reductionPercent.toStringAsFixed(1)}%)');
}

/// Generates DuckDB SQL query to analyze tool durations
String getDuckDbQuery(String logFilePath) {
  return ToonDuckDb.selectQuery(logFilePath);
}
```

---

## 7. CI/CD: GitHub Actions Job Summaries in Markdown

### Problem
In automated CI runs, raw terminal logs are thousands of lines long, making test results and error diagnostics hard to skim.

### Solution
Use `MarkdownFileHandler` from [`package:logd_markdown`](../packages/logd_markdown) to write formatted test summaries directly to `$GITHUB_STEP_SUMMARY`.

```dart
import 'dart:io';
import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';

void setupCiLogging() {
  final summaryPath = Platform.environment['GITHUB_STEP_SUMMARY'] ?? 'logs/ci_summary.md';

  Logger.configure('ci', handlers: [
    ConsoleHandler(),
    MarkdownFileHandler(summaryPath),
  ]);

  final logger = Logger.get('ci.pipeline');
  logger.info('Pipeline execution initialized');
}
```

---

## 8. Distributed Telemetry: Resilient NDJSON Ingestion with Jittered Backoff & Offline Spooling

### Problem
In high-throughput edge nodes, microservices, or mobile apps:
1. JSON array batching forces the server to buffer the entire payload in memory before parsing.
2. Network blips cause thousands of nodes to reconnect simultaneously, overwhelming log collection servers with thundering herds.
3. Network outages can lead to unbounded memory buffer growth and client-side Out-Of-Memory (OOM) crashes.

### Solution
Use `HttpSink` from [`package:logd_network`](../packages/logd_network) with:
- `HttpDeliveryFormat.ndjson` for streaming Newline-Delimited JSON ingestion with zero-copy `BytesBuilder` assembly.
- `BackoffPolicy(jitter: true)` to randomize retry delays and prevent thundering-herd storms.
- `maxBufferBytes` combined with `DropPolicy.discardByPriority` for atomic client memory budgeting that prioritizes error retention.
- `onDropped` hook to spool dropped logs locally and replay upon reconnection without coupling network sinks to disk dependencies.

```dart
import 'dart:typed_data';
import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

void setupResilientTelemetry() {
  final offlineSpool = <List<Uint8List>>[];

  final httpSink = HttpSink(
    url: 'https://telemetry.example.com/v1/logs/ndjson',
    deliveryFormat: HttpDeliveryFormat.ndjson, // Streamable Newline-Delimited JSON
    batchSize: 100,
    flushInterval: const Duration(seconds: 3),
    
    // Exponential backoff with decorrelated randomized jitter [0.5 * delay, 1.5 * delay]
    backoffPolicy: const BackoffPolicy(
      initialDelay: Duration(milliseconds: 250),
      maxDelay: Duration(seconds: 30),
      multiplier: 2.0,
      jitter: true,
    ),

    // Strict memory budgeting: 2 MB ceiling, evict lowest-severity logs first (debug -> info -> warning)
    maxBufferBytes: 2 * 1024 * 1024,
    dropPolicy: DropPolicy.discardByPriority,

    // Failover endpoint during prolonged primary cluster outages
    failoverUrls: ['https://telemetry-backup.example.com/v1/logs/ndjson'],

    // Intercept dropped batches during prolonged offline states to spool locally
    onDropped: (droppedBatches) {
      offlineSpool.add(droppedBatches);
    },
  );

  Logger.configure('telemetry', handlers: [
    Handler(
      formatter: const JsonFormatter(),
      sink: httpSink,
    ),
  ]);

  Logger.get('telemetry.worker').info(
    'Worker initialized with jittered NDJSON streaming telemetry',
  );
}
```
