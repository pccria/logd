# logd_dio Architecture

`logd_dio` is a specialized satellite package within the `logd` ecosystem providing production-grade HTTP telemetry for the [Dio](https://pub.dev/packages/dio) networking library.

---

## Architectural Principles

### 1. Interceptor Layer Separation
`LogdDioInterceptor` serves as an adapter between the physical HTTP transport layer (Dio) and the semantic logging engine (`logd`):
- It captures HTTP request, response, and error lifecycles.
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
|  - Monotonic Latency (Stopwatch in options.extra)           |
|  - Security Sanitization (LogdSanitizer)                    |
|  - Ambient Tracing Injection (LogContext.current)           |
|  - cURL Command Generation (LogdCurlGenerator)              |
|  - Payload Safety & Truncation (safeBodyPreview)            |
+------------------------------+------------------------------+
                               |
                               v  _logger.debug / info / error
+-------------------------------------------------------------+
|                     logd Core Pipeline                      |
|         (Filters -> Formatters -> Decorators -> Sinks)      |
+-------------------------------------------------------------+
```

---

## Core Components

### 1. `LogdDioInterceptor`
The central interceptor implementing Dio's `Interceptor` interface:
- **`onRequest`**: Captures outgoing method, URI, sanitized headers, query parameters, payload preview, and generated cURL. Attaches a running `Stopwatch` to `RequestOptions.extra` for jitter-free latency calculation. Injects ambient trace IDs (`x-request-id`) from `LogContext.current` if not already present.
- **`onResponse`**: Stops the monotonic stopwatch, formats latency (`ms`), extracts status code, response headers, and sanitized response body.
- **`onError`**: Distinguishes client cancellations (`DioExceptionType.cancel`) from operational network/server errors. Logs cancellations quietly at `cancelLevel` (default: `debug`) to avoid polluting error tracking alerts, while logging real errors at `errorLevel` (default: `error`) with full diagnostics and stack traces.

### 2. `LogdDioOptions`
An `@immutable` configuration object controlling:
- Log severity levels per lifecycle phase (`requestLevel`, `responseLevel`, `errorLevel`, `cancelLevel`).
- Metadata verbosity (`logRequestHeaders`, `logRequestBody`, `logResponseHeaders`, `logResponseBody`, `logCurl`).
- Safety limits (`maxBodyLength` preventing memory bloat on large payloads).
- Security policies (`sensitiveHeaders`, `sensitiveQueryParams`, `redactedPlaceholder`).
- Ambient tracing (`attachAmbientTraceId`, `traceIdHeader`).

### 3. `LogdSanitizer`
A static utility class that safely scrubs sensitive credentials:
- **Case-Insensitive Redaction**: Normalizes header keys and query parameters to lowercase sets for reliable matching regardless of casing variations (`Authorization`, `authorization`, `AUTHORIZATION`).
- **Safe Body Previews**: Handles strings, JSON-encodable maps, multipart `FormData`, and binary byte streams (`List<int>`) without throwing encoding errors. Safely truncates oversized payloads with a clear indicator (e.g. `[truncated 240 chars]`).

### 4. `LogdCurlGenerator`
Formats `RequestOptions` into executable, copy-pasteable `curl` commands for terminal execution and Postman reproduction:
- Preserves method, URL, and query parameters.
- Re-applies security sanitization to headers to prevent exposing live credentials in terminal logs.
- Properly escapes shell single quotes (`'`).
