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
