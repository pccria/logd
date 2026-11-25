## 0.2.0

- **Bidirectional TOON Parsing & Structured Decoding**:
  - Introduced `ToonDecoder` for high-throughput streaming and string decoding of TOON documents into typed `ToonDocument` and `ToonRecord` structures.
  - Full support for unescaping control sequences (`\t`, `\n`, `\r`, `\\`, `\"`), parsing dialect-specific null representations (`\N` vs empty strings), and reconstructing deeply nested maps and primitive lists from context tokens.
  - Added `decodeStream()` for memory-safe chunked reading of large `.toon` audit logs.
- **Structured Schema Representation (`ToonSchema`)**:
  - Introduced `@immutable final class ToonSchema` representing table structure, column orders, types, and dialect metadata.
  - Added zero-allocation preamble parsing from UTF-8 byte buffers via `ToonSchema.parseBytes()` without decoding entire files.
  - Added bidirectional JSON serialization (`toJson()` / `fromJson()`) and preamble reconstruction (`toPreamble()`).
- **LLM Context Window Budgeting & Tail Slicing**:
  - Introduced `ToonContextWindow` and `ToonWindowSlice` for token-budgeted prompt construction from recent log history.
  - Guaranteed preservation of schema preambles and explicit truncation indicators (`-- [TRUNCATED: omitted N older log entries]`) within token limits.
  - Implemented `ToonTokenEstimator` with calibrated BPE heuristic estimation (cl100k/Claude compatible) and comparative JSON token reduction metrics (`ToonTokenMetrics`).
- **DuckDB & Analytical SQL Bridge (`ToonDuckDb`)**:
  - Added zero-copy DuckDB SQL query generation via `ToonDuckDb.selectQuery()`, `ToonDuckDb.createTableSql()`, and `ToonDuckDb.ingestSql()`.
  - Automatic type mapping from TOON schema column definitions to DuckDB types (`TIMESTAMP`, `VARCHAR`, `JSON`, `BIGINT`, `DOUBLE`, `BOOLEAN`).
- **TOON Column Invariance (`contextColumns`)**:
  - Added optional `contextColumns` to `ToonFormatter` and `ToonFileHandler` to guarantee strict tabular column counts across heterogeneous log events.
  - Fixed-width column projection preserves DuckDB ingestion compatibility and LLM prompt consistency.
- **API Parity & Configuration Registry**:
  - Added parameter parity (`metadata`, `sortKeys`, `maxDepth`, `contextColumns`) across `ToonFileHandler` and `ToonFileHandler.async()`.
  - Marked `ToonEncoder.extractPreamble` as `@Deprecated`, routing calls to `ToonSchema.parseBytes(bytes)?.toPreamble()`.
  - Updated `registerLogdToonSerializers()` with `contextColumns` isolate transfer support.
- **Showcase & Tests**:
  - Added interactive showcase gallery (`example/showcase_gallery.dart`) demonstrating all 6 core workflows.
  - Expanded test coverage across decoders, schemas, LLM tools, DuckDB SQL generators, and context column projections (60 tests).

## 0.1.8

- Requires logd ^0.10.8.
- **Documentation Cleanup**: Removed `comment_references` suppression header from `ToonFileHandler`.

## 0.1.7

- Requires logd ^0.10.6.
- Minimum Dart SDK is now 3.10.0 (the previous 3.6.0 floor could not be resolved because of dependency requirements)
- **Maintenance**: Update repository, issue tracker, documentation, and raw asset URLs to reflect account migration to `pccria`.

## 0.1.5

- **Documentation**: Use absolute raw asset URLs for README visual diagrams to ensure proper rendering on pub.dev.

## 0.1.4

- **Documentation**: Added official high-DPI hero branding and TOON vs JSON token reduction comparison diagram.

## 0.1.3

- **Memory Safety & Buffer Optimization**:
  - Optimized `ToonEncoder.extractPreamble` to scan an initial 8KB window (`sublistView`) rather than allocating and decoding multi-megabyte/gigabyte byte buffers in full into UTF-16 memory.
- **Normalization & Validation**:
  - Added Windows CRLF line ending normalization (`\r\n` and `\r` to `\n`) in `ToonFormatter` and `ToonPrettyFormatter` before line splitting, preventing trailing carriage returns from corrupting TOON row values.
  - Added strict validation for `delimiter` (rejecting empty or newline characters) and `maxDepth` (`>= 1`).
- **Dependency Alignment**: Updated minimum `logd` dependency constraint to `^0.10.2`.

## 0.1.2

- **Dependency Resolution**: Tightened `logd` dependency constraint to `^0.10.0` to prevent ambiguous import collisions during dependency resolution.

## 0.1.1

- **`logd` v0.10.x Support**: Widened dependency constraint to `logd: '>=0.9.7 <0.11.0'`, enabling seamless compatibility with `logd` v0.10.0's pure semantic engine.
- **Clean Imports (No Shims)**: Removed obsolete `hide` clauses from documentation and examples as legacy TOON shims have been permanently deleted in `logd` v0.10.0.
- **Documentation**: Updated migration guide to reflect permanent removal of core shims in `logd` v0.10.0+.

## 0.1.0

- **Initial Release:** Satellite package release of `logd_toon`.
- **Core Components:** Introduced `ToonFormatter`, `ToonEncoder`, and `ToonFileHandler` for highly optimized tab-oriented logging.
- **Controls & Dialects:** Added support for `explicitSchema`, dialect controls (`ToonDialect.strict` vs `ToonDialect.compact`), object depth limits, and map key sorting.
- **Bug Fixes:**
  - Fixed a critical isolate-boundary bug where `LoggerSerializationRegistry` would silently overwrite TOON serializers with deprecated core shims.
  - Fixed preamble extraction bug in `ToonEncoder.extractPreamble` that truncated early on colons.
  - Hardened context ingestion in `ToonFormatter` to safely handle raw strings or non-map objects.
- **Testing & Stability:** Established a robust 27-test suite validating isolate-safe serialization, encoder escaping rules, file handlers, and null-emission behaviors (`\N`).
- **Documentation:** Added comprehensive guides covering TOON architecture, dialect comparisons, throughput benchmarks, and a v0.9.6 migration guide.
- **Examples:** Included standard examples (`example/main.dart`) alongside advanced patterns (`example/extra/`) for file rotation, depth clamping, and schema evolution.
