# logd_dio Roadmap

Package version at time of writing: **0.2.0**

---

## Versioning Strategy

`logd_dio` follows the semver contract defined in
[`doc/semver_contract.md`](../../../doc/semver_contract.md):

| Increment | Triggers |
|---|---|
| **Patch** (`0.2.x`) | Non-breaking bug fixes, security hardening, and performance optimizations. |
| **Minor** (`0.x.0`) | New interceptor capabilities, distributed tracing formats, or body serializers. |
| **Major** (`x.0.0`) | Breaking changes to interceptor options, sanitizer APIs, or Dio version compatibility. |

---

## Completed

### ✅ v0.2.0: Advanced Distributed Tracing & Telemetry Integration

**Goal**: Extend `logd_dio` from HTTP request/response inspection into end-to-end distributed tracing across microservices and cloud backends.

- [x] **W3C TraceContext Integration**:
  - Automatically inject and extract W3C `traceparent` and `tracestate` headers using ambient `LogContext.current` values, ensuring compliance with OpenTelemetry standards.
  - Added `TracePropagationMode` (`both`, `w3c`, `custom`, `none`) for flexible cloud gateway compatibility.
  - Automatic extraction of remote server trace IDs from response headers (`serverTraceparent`, `serverResponseTraceId`).
- [x] **Stream & Chunked Response Telemetry**:
  - Added non-blocking `StreamMetricsTracker` for long-running streaming responses and chunked file downloads without loading full streams into memory.
  - Emits `STREAM_COMPLETED` with chunk count, byte count, and transfer throughput.
- [x] **Fine-Grained Network Metrics**:
  - Added request and response byte size accounting and transfer throughput calculation (`throughputKBps`) under the `metrics` context map.
  - Automatic status classification (`statusCategory`: `1xx`-`5xx`).
- [x] **Custom Payload Serializers**:
  - Added pluggable request/response payload serializers (`LogdBodySerializer`, `FunctionalBodySerializer`) for custom binary protocols (Protobuf, FlatBuffers) alongside JSON and form-data previews.
- [x] **HTTP Status Code Elevation**:
  - Added `elevateHttpErrors` to automatically elevate 4xx responses to `warningLevel` and 5xx to `errorLevel` in non-throwing pipelines (`validateStatus`).
- [x] **cURL Command Enhancements**:
  - Multi-line formatted output (`prettyCurl: true`) and `--compressed` auto-detection.

---

### ✅ v0.1.6: Security Sanitization & Key Normalization Hardening
- [x] Key normalization across camelCase, snake_case, and kebab-case.
- [x] Form-encoded payload redaction (`application/x-www-form-urlencoded`).
- [x] UserInfo URI credential redaction (`user:pass@host`).
- [x] Error message URL and parameter scrubbing.

---

### ✅ v0.1.2: cURL Command Injection Fix & Sensitive Data Redaction
- [x] **Command Injection Immunity (`LogdCurlGenerator`)**:
  - Posix shell escape single quotes (`'\''`) in generated cURL targets and headers.
  - Strip control characters and newlines (`\r\n`) from header keys, header values, and target URIs.
- [x] **URI Query Parameter Redaction**:
  - Added `LogdSanitizer.sanitizeUri` for sensitive query parameter scrubbing.
- [x] **Payload & Body Key Redaction**:
  - Added `sensitiveBodyKeys` to `LogdDioOptions`.
  - Added `LogdSanitizer.sanitizeBody` for recursive redaction across nested maps, lists, and raw JSON strings.

---

### ✅ v0.1.1: Dependency Constraint Alignment
- [x] Raised minimum `dio` dependency constraint to `^5.2.0` for compatibility with `DioException` and `DioExceptionType`.

---

### ✅ v0.1.0: Initial Release
- [x] Production-grade `LogdDioInterceptor` with monotonic `Stopwatch` latency timing, automatic case-insensitive SOC2/GDPR credential redaction, cURL generation, ambient distributed tracing propagation, and cancellation awareness (`CancelToken`).

---

## Next Milestones

### 🔲 v0.3.0: Direct OpenTelemetry Span Export Track
- [ ] **OpenTelemetry Span Bridge**: Direct mapping of Dio HTTP transactions to native OpenTelemetry spans (`SpanKind.client`) when used alongside `logd_opentelemetry`.
- [ ] **HAR (HTTP Archive) Export**: Capability to export serialized Dio request/response sessions to standard `.har` format for web debugging proxies.
