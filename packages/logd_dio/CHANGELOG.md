# Changelog

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

