# logd_toon Roadmap

Package version at time of writing: **0.1.3**

---

## Versioning Strategy

`logd_toon` follows the semver contract defined in
[`doc/semver_contract.md`](../../../doc/semver_contract.md):

| Increment | Triggers |
|---|---|
| **Patch** (`0.1.x`) | Non-breaking formatting bug fixes, preamble parsing optimizations, and dialect corrections. |
| **Minor** (`0.x.0`) | New schema inference features, DuckDB export utilities, or dialect extensions. |
| **Major** (`x.0.0`) | Breaking changes to the core TOON specification format, delimiter conventions, or public APIs. |

---

## Next Milestones

### 🔲 v0.2.0: DuckDB & Analytics Telemetry Ingestion

**Goal**: Extend TOON from LLM agent context optimization into analytical ingestion and zero-copy tabular processing.

- [ ] **DuckDB Direct Ingestion Helpers**:
  - Provide copy-paste DuckDB SQL schemas and automated ingest scripts for querying `.toon` log files directly via DuckDB.
- [ ] **Dynamic Schema Evolution**:
  - Add schema reconciliation when heterogeneous log events introduce new keys or change scalar types across a single session.
- [ ] **Native Vectorized TOON Parser**:
  - Implement C/FFI vectorized tab scanner for ultra-high-throughput ingestion and validation (>100,000 rows/sec).

---

## Completed

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
