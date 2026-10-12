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
