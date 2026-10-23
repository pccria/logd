# logd_dio Roadmap

Package version at time of writing: **0.1.2**

---

## Versioning Strategy

`logd_dio` follows the semver contract defined in
[`doc/semver_contract.md`](../../../doc/semver_contract.md):

| Increment | Triggers |
|---|---|
| **Patch** (`0.1.x`) | Non-breaking bug fixes, security hardening, and performance optimizations. |
| **Minor** (`0.x.0`) | New interceptor capabilities, distributed tracing formats, or body serializers. |
| **Major** (`x.0.0`) | Breaking changes to interceptor options, sanitizer APIs, or Dio version compatibility. |

---

## Next Milestones

### 🔲 v0.2.0: Advanced Distributed Tracing & Telemetry Integration

**Goal**: Extend `logd_dio` from HTTP request/response inspection into end-to-end distributed tracing across microservices and cloud backends.

- [ ] **W3C TraceContext Integration**:
  - Automatically inject and extract W3C `traceparent` and `tracestate` headers using ambient `LogContext.current` values, ensuring compliance with OpenTelemetry standards.
- [ ] **Stream & Chunked Response Telemetry**:
  - Add optional bytes-transferred and throughput metrics tracking for long-running streaming responses and chunked file downloads without loading full streams into memory.
- [ ] **Custom Payload Serializers**:
  - Add pluggable request/response payload serializers for custom binary protocols (Protobuf, FlatBuffers) alongside JSON and form-data previews.

---

## Completed

### ✅ v0.1.2: cURL Command Injection Fix & Sensitive Data Redaction
- [x] **Command Injection Immunity (`LogdCurlGenerator`)**:
  - Posix shell escape single quotes (`'\''`) in generated cURL targets and headers.
  - Strip control characters and newlines (`\r\n`) from header keys, header values, and target URIs to prevent terminal command execution breakouts when pasting generated commands.
  - Validate and fallback HTTP method names against shell breakout characters.
- [x] **URI Query Parameter Redaction**:
  - Added `LogdSanitizer.sanitizeUri` to automatically sanitize sensitive query parameters (e.g., `token`, `api_key`, `secret`, `password`) in logged request/response messages and generated cURL command URLs.
- [x] **Payload & Body Key Redaction**:
  - Added `sensitiveBodyKeys` to `LogdDioOptions` (with default redaction for passwords, tokens, API keys, secrets, credit cards, CVVs, SSNs).
  - Added `LogdSanitizer.sanitizeBody` for recursive redaction across nested maps, lists, and raw JSON strings.
  - Integrated body redaction into `LogdSanitizer.safeBodyPreview`, `LogdCurlGenerator.generate`, and request/response/error logging.
- [x] **Dependency Alignment**:
  - Updated minimum `logd` dependency constraint to `^0.10.2`.

---

### ✅ v0.1.1: Dependency Constraint Alignment
- [x] Raised minimum `dio` dependency constraint to `^5.2.0` for compatibility with `DioException` and `DioExceptionType`.

---

### ✅ v0.1.0: Initial Release
- [x] Production-grade `LogdDioInterceptor` with monotonic `Stopwatch` latency timing, automatic case-insensitive SOC2/GDPR credential redaction, cURL generation, ambient distributed tracing propagation, and cancellation awareness (`CancelToken`).
