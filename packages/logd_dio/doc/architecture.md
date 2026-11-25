# logd_dio Architecture

`logd_dio` is a specialized satellite package within the `logd` ecosystem providing production-grade HTTP telemetry for the [Dio](https://pub.dev/packages/dio) networking library.

---

## Architectural Principles

### 1. Interceptor Layer Separation
`LogdDioInterceptor` serves as an adapter between the physical HTTP transport layer (Dio) and the semantic logging engine (`logd`):
- It captures HTTP request, response, streaming, and error lifecycles.
- It translates transport metadata into semantic `Map<String, dynamic>` context entries without performing physical string formatting or ANSI coloring itself.
- It dispatches logs to a target `Logger` (default: `Logger.get('http')`), allowing all downstream formatters, filters, and asynchronous isolate handlers (`.async()`) to process the event according to user configuration.

```
+-------------------------------------------------------------+
|                         Dio Client                          |
|             (onRequest / onResponse / onError)              |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
|                     LogdDioInterceptor                      |
|  - W3C TraceContext Propagation (traceparent, tracestate)   |
|  - Monotonic Latency (Stopwatch in options.extra)           |
|  - Network Metrics & Bandwidth (HttpMetrics)                |
|  - Zero-Buffering Stream Telemetry (StreamMetricsTracker)   |
|  - Pluggable Custom Payload Serializers (LogdBodySerializer)|
|  - Security Sanitization (LogdSanitizer)                    |
|  - cURL Command Generation (LogdCurlGenerator)              |
|  - Payload Safety & Truncation (safeBodyPreview)            |
+------------------------------+------------------------------+
                               |
                               v  _logger.debug / info / warning / error
+-------------------------------------------------------------+
|                     logd Core Pipeline                      |
|         (Filters -> Formatters -> Decorators -> Sinks)      |
+-------------------------------------------------------------+
```

---

## Core Components

### 1. `LogdDioInterceptor`
The central interceptor implementing Dio's `Interceptor` interface:
- **`onRequest`**: Captures outgoing method, URI, sanitized headers, query parameters, payload preview, and generated cURL. Attaches a running `Stopwatch` to `RequestOptions.extra` for jitter-free latency calculation. Injects W3C `traceparent` and ambient trace IDs (`x-request-id`) from `LogContext.current`.
- **`onResponse`**: Stops the monotonic stopwatch, computes `HttpMetrics` (`durationMs`, `requestBytes`, `responseBytes`, `throughputKBps`), extracts server trace headers, and handles status code elevation (4xx -> warning, 5xx -> error).
- **Stream Tracking**: Wraps `ResponseBody.stream` with non-blocking `StreamMetricsTracker` and dispatches `STREAM_COMPLETED` upon stream finish.
- **`onError`**: Distinguishes client cancellations (`DioExceptionType.cancel`) from operational network/server errors. Logs cancellations quietly at `cancelLevel` (default: `debug`) while logging real errors at `errorLevel` (default: `error`) with full diagnostics and stack traces.

### 2. `W3cTraceContext`
Encapsulates RFC-compliant W3C distributed tracing:
- Generates and parses standard `traceparent` headers (`00-${traceId}-${spanId}-${traceFlags}`) and `tracestate`.
- Correlates client spans with remote cloud gateways and microservices.
- Extracts server response trace identifiers (`serverTraceparent`, `serverResponseTraceId`).

### 3. `HttpMetrics`
An `@immutable` performance snapshot capturing:
- Monotonic duration in milliseconds.
- Payload byte accounting for requests and responses.
- Computed transfer throughput in Kilobytes per second (KB/s).
- Semantic status categorization (`1xx`, `2xx`, `3xx`, `4xx`, `5xx`).

### 4. `StreamMetricsTracker`
Provides transparent streaming telemetry:
- Transparently wraps `ResponseBody.stream` without buffering chunks in RAM.
- Emits completion events with chunk count, total bytes, and transfer speed.

### 5. `LogdBodySerializer`
Pluggable serializer interface allowing applications to register domain decoders (Protocol Buffers, XML, FlatBuffers) that run before truncation and credential sanitization.

### 6. `LogdDioOptions`
An `@immutable` configuration object controlling:
- Log severity levels per lifecycle phase (`requestLevel`, `responseLevel`, `warningLevel`, `errorLevel`, `cancelLevel`, `streamCompleteLevel`).
- Distributed tracing policies (`tracePropagationMode`, `traceIdHeader`, `extractResponseTraceId`).
- Metrics and streaming switches (`logMetrics`, `trackStreamMetrics`, `elevateHttpErrors`).
- Metadata verbosity (`logRequestHeaders`, `logRequestBody`, `logResponseHeaders`, `logResponseBody`, `logCurl`, `prettyCurl`, `curlIncludeCompressed`).
- Safety limits (`maxBodyLength` preventing memory bloat on large payloads).
- Security policies (`sensitiveHeaders`, `sensitiveQueryParams`, `sensitiveBodyKeys`, `redactedPlaceholder`).
- Pluggable serializers (`bodySerializers`).

### 7. `LogdSanitizer`
A static utility class that safely scrubs sensitive credentials:
- **Case-Insensitive Redaction**: Normalizes header keys and query parameters across camelCase, snake_case, and kebab-case.
- **Safe Body Previews**: Handles strings, JSON-encodable maps, multipart `FormData`, binary byte streams (`List<int>`), and custom serializer outputs.
- **Error Scrubbing**: Sanitizes sensitive URLs and query parameters embedded in exception messages.

### 8. `LogdCurlGenerator`
Formats `RequestOptions` into executable, copy-pasteable `curl` commands:
- Preserves method, URL, and query parameters.
- Re-applies security sanitization to headers and payloads.
- Supports `--compressed` auto-detection and pretty multi-line output with backslash breaks.
