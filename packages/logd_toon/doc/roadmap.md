# logd_toon Roadmap

Package version at time of writing: **0.2.0**

---

## Versioning Strategy

`logd_toon` follows the semver contract defined in
[`doc/semver_contract.md`](../../../doc/semver_contract.md):

| Increment | Triggers |
|---|---|
| **Patch** (`0.2.x`) | Non-breaking formatting bug fixes, decoder edge cases, and token estimator calibrations. |
| **Minor** (`0.x.0`) | New schema inference features, analytical export integrations, or dialect extensions. |
| **Major** (`x.0.0`) | Breaking changes to the core TOON specification format, delimiter conventions, or public APIs. |

---

## Next Milestones

### 🔲 v0.3.0: High-Throughput Streaming & Continuous Ingestion
**Goal**: Vectorized native parsing and live ingestion pipelines for real-time telemetry processing.

- [ ] **Native Vectorized Scanner**:
  - Implement C/FFI vectorized tab and escape scanner via Dart Native Assets (`hook/build.dart`) for high-throughput ingestion (>250,000 rows/sec).
- [ ] **Chunked Continuous Ingestion Stream**:
  - Add reactive backpressure-aware stream decoders with automatic schema drift detection.
- [ ] **ClickHouse & Apache Arrow Bridges**:
  - Extend tabular export utilities beyond DuckDB to generate ClickHouse HTTP schemas and Apache Arrow RecordBatches.

---

### 🔲 v1.0.0: Specification Freeze & Cross-Platform Parity
**Goal**: Lock in the TOON 1.0 specification with multi-language reference implementations (Python, Rust, Go).

- [ ] Complete formal specification validation suite.
- [ ] Cross-language test fixtures for TOON strict and compact dialects.
- [ ] Deprecation cleanup and frozen API surface.

---

## Completed

### ✅ v0.2.0: Bidirectional Decoding, LLM Budgeting & DuckDB Bridge
- [x] **Bidirectional Decoding Engine (`ToonDecoder`)**:
  - Full stream and string decoding into strongly typed `ToonDocument` and `ToonRecord` models.
  - State-machine unescaping for `\t`, `\n`, `\r`, `\\`, `\"`, dialect nulls (`\N` vs empty), and nested map/list tokens.
- [x] **Immutable Schema Representation (`ToonSchema`)**:
  - Structured metadata model with column types, dialects, and zero-allocation 8KB byte scanning (`parseBytes`).
  - Bidirectional JSON serialization (`toJson` / `fromJson`) and preamble reconstruction.
- [x] **LLM Context Window Budgeting (`ToonContextWindow`)**:
  - Token-aware sliding-window tail slicer with invariant schema preamble retention and explicit truncation notice.
  - Zero-dependency BPE heuristic token counter (`ToonTokenEstimator`) and comparative token reduction analysis (`ToonTokenMetrics`).
- [x] **DuckDB Analytical SQL Bridge (`ToonDuckDb`)**:
  - Zero-copy DuckDB SQL queries (`selectQuery`), DDL table creation (`createTableSql`), and COPY ingestion (`ingestSql`).
- [x] **Column Invariance with `contextColumns`**:
  - Fixed-width column projections across heterogeneous log events in `ToonFormatter` and `ToonFileHandler`.
- [x] **Showcase Gallery & Test Suite**:
  - Runnable 6-scenario showcase gallery (`example/showcase_gallery.dart`) and comprehensive 60-test verification suite.

---

### ✅ v0.1.3: Memory Safety Optimization & CRLF Normalization
- [x] **Memory-Safe Windowed Preamble Extraction**:
  - Optimized `ToonEncoder.extractPreamble` to scan an initial 8KB window (`sublistView`) rather than allocating and decoding multi-megabyte/gigabyte byte buffers in full into UTF-16 memory.
- [x] **CRLF Normalization & Input Validation**:
  - Added Windows CRLF line ending normalization (`\r\n` and `\r` to `\n`) in `ToonFormatter` and `ToonPrettyFormatter` before line splitting, preventing trailing carriage returns from corrupting TOON row values.
  - Added strict validation for `delimiter` (rejecting empty or newline characters) and `maxDepth` (`>= 1`).
- [x] **Dependency Alignment**:
  - Updated minimum `logd` dependency constraint to `^0.10.2`.

---

### ✅ v0.1.2: Dependency Resolution
- [x] Tightened `logd` dependency constraint to `^0.10.0`.

---

### ✅ v0.1.0: Initial Release
- [x] Tab-Oriented Object Notation (TOON) formatter, encoder, and file handler (30–50% LLM token reduction), strict and compact dialects, and serialization registry support.
