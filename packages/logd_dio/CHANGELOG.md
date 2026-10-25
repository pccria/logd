# Changelog

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

