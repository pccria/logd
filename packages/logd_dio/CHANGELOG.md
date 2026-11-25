# Changelog

## 0.2.0: W3C TraceContext, Network Metrics & Stream Telemetry

- **W3C TraceContext Distributed Tracing (`W3cTraceContext`)**:
  - Full compliance with W3C TraceContext recommendation: supports standard `traceparent` (`00-${traceId}-${spanId}-${traceFlags}`) and `tracestate` headers.
  - Added `TracePropagationMode`: `both` (injects both W3C `traceparent` and custom trace header), `w3c` (W3C standard only), `custom` (legacy single header), or `none`.
  - Automatic extraction of remote server trace IDs (`serverTraceparent`, `serverResponseTraceId`) from response headers (`traceparent`, `x-request-id`, `x-correlation-id`, `x-trace-id`, `x-amzn-trace-id`) attached directly to log context.
- **Fine-Grained Network Metrics & Bandwidth Profiling (`HttpMetrics`)**:
  - Added request/response byte sizing and throughput calculation (`throughputKBps`), attached under the `metrics` context map.
  - Automatic status classification (`statusCategory`: `'1xx'`, `'2xx'`, `'3xx'`, `'4xx'`, `'5xx'`).
- **Non-Blocking Stream & Chunked Response Telemetry (`StreamMetricsTracker`)**:
  - Transparent tracking for streaming downloads and SSE (`ResponseBody.stream`) without buffering chunks in memory.
  - Emits a structured `STREAM_COMPLETED` completion log upon stream finish, recording chunk count, total transferred bytes, and throughput.
- **Pluggable Payload Serializers (`LogdBodySerializer`)**:
  - Added `LogdBodySerializer` and `FunctionalBodySerializer` allowing custom decoders for Protocol Buffers (`GeneratedMessage`), XML, FlatBuffers, or custom binary models before truncation and redaction.
- **HTTP Status Code Classification & Error Elevation**:
  - Added `elevateHttpErrors` (default: `true`) to automatically elevate 4xx responses to `warningLevel` and 5xx responses to `errorLevel` in pipelines using non-throwing status validation (`validateStatus`).
- **cURL Command Enhancements**:
  - Added `prettyCurl: true` to generate multi-line formatted cURL commands with backslash breaks.
  - Added `curlIncludeCompressed: true` to automatically append `--compressed` when `Accept-Encoding` contains `gzip`, `deflate`, or `br`.
- **Examples & Showcases**:
  - Added `example/telemetry/w3c_tracing_and_metrics_example.dart`.
  - Added `example/streaming/stream_telemetry_example.dart`.
  - Added `example/serializers/custom_serializer_example.dart`.
  - Updated `example/showcase_gallery.dart` with interactive options for all new features.

## 0.1.6: Security Sanitization & Key Normalization Hardening

- Requires logd ^0.10.6.
- Minimum Dart SDK is now 3.10.0 (the previous 3.6.0 floor could not be resolved because of dependency requirements)
- **Key Normalization Across Casing Styles**:
  - Enhanced `LogdSanitizer` to normalize keys across camelCase, snake_case, and kebab-case. Keys such as `accessToken`, `refreshToken`, `apiKey`, and `clientSecret` are now reliably matched and redacted against configured security patterns.
- **Form-Encoded Payload Redaction**:
  - Added support for sanitizing `application/x-www-form-urlencoded` request bodies. Sensitive credentials passed in form-encoded strings (e.g., login and OAuth token requests) are redacted before logging.
- **URI UserInfo Redaction**:
  - Enhanced `LogdSanitizer.sanitizeUri` to redact embedded credentials in `Uri.userInfo` (`user:pass@host`), preventing plain-text password leakage in URLs.
- **Error Diagnostic Sanitization**:
  - Added automatic scrubbing of sensitive URLs and query parameters from error messages and exception text in `LogdDioInterceptor.onError`.
- **Default Sensitive Key Expansion**:
  - Expanded `defaultSensitiveHeaders` to include `x-auth-token`, `x-csrf-token`, `x-access-token`, and `api-key`.
  - Expanded `defaultSensitiveBodyKeys` to include `client_secret` and `id_token`.

## 0.1.5

- **Maintenance**: Update repository, issue tracker, documentation, and raw asset URLs to reflect account migration to `pccria`.

## 0.1.4

- **Documentation**: Use absolute raw asset URLs for README visual diagrams to ensure proper rendering on pub.dev.

## 0.1.3

- **Documentation**: Added official high-DPI hero branding and static code-to-terminal result showcase.

## 0.1.2

- **Security & Command Injection Fix (`LogdCurlGenerator`)**:
  - Posix shell escape single quotes (`'\''`) in generated cURL targets and headers.
  - Strip control characters and newlines (`\r\n`) from header keys, header values, and target URIs to prevent terminal command execution breakouts when pasting generated commands.
  - Validate and fallback HTTP method names against shell breakout characters.
- **URI Query Parameter Redaction**:
  - Added `LogdSanitizer.sanitizeUri` to automatically sanitize sensitive query parameters (e.g., `token`, `api_key`, `secret`, `password`) in logged request/response messages and generated cURL command URLs.
- **Payload & Body Key Redaction**:
  - Added `sensitiveBodyKeys` to `LogdDioOptions` (with default redaction for passwords, tokens, API keys, secrets, credit cards, CVVs, SSNs).
  - Added `LogdSanitizer.sanitizeBody` for recursive redaction across nested maps, lists, and raw JSON strings.
  - Integrated body redaction into `LogdSanitizer.safeBodyPreview`, `LogdCurlGenerator.generate`, and request/response/error logging.
- **Dependency Alignment**: Updated minimum `logd` dependency constraint to `^0.10.2`.

## 0.1.1

- **Dependency Constraints**: Raised minimum `dio` dependency constraint to `^5.2.0` for compatibility with `DioException` and `DioExceptionType`.

## 0.1.0: Initial Release

- **`LogdDioInterceptor`**: First-class HTTP request and response logging interceptor for Dio.
- **Monotonic Latency Timing**: Uses monotonic `Stopwatch` timers for accurate, clock-skew-immune latency tracking.
- **Security & Compliance Redaction**: Automatically redacts sensitive headers (`Authorization`, `Cookie`, `x-api-key`, etc.) and query parameters (`token`, `password`, `secret`).
- **cURL Command Generation**: Generates copy-pasteable, executable cURL strings with sanitized headers.
- **Payload Safety**: Safely handles and previews `FormData`, binary streams, and truncates large payloads to prevent out-of-memory errors.
- **Ambient Context / MDC Propagation**: Automatically injects ambient `LogContext.current['requestId']` into outgoing `x-request-id` headers with case-insensitive collision protection.
- **Cancellation Awareness**: Gracefully logs `DioExceptionType.cancel` as non-failure events at configurable log levels.
- **Showcase Gallery & Modular Examples**:
  - `example/showcase_gallery.dart`: Interactive CLI runner to run demos individually (`1-5`) or sequentially (`all`).
  - `example/main.dart`: Clean, minimal Dio integration.
  - `example/security/sanitization_example.dart`: Custom header/query redaction, custom replacement tokens, and binary/FormData safety.
  - `example/tracing/distributed_tracing_example.dart`: Ambient context forwarding and concurrent async zone isolation.
  - `example/resilience/error_and_cancellation_example.dart`: User cancellations vs 4xx/5xx server diagnostics.
  - `example/advanced/custom_pipeline_example.dart`: cURL output, response headers inspection, and custom logger pipelines.

