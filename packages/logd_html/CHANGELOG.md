## 0.1.1

- **`logd` v0.10.x Support**: Widened dependency constraint to `logd: '>=0.9.7 <0.11.0'`, enabling seamless compatibility with `logd` v0.10.0's pure semantic engine.
- **Clean Imports (No Shims)**: Removed obsolete `hide` clauses from documentation and examples as legacy HTML shims have been permanently deleted in `logd` v0.10.0.
- **Documentation**: Updated migration guide to reflect permanent removal of core shims in `logd` v0.10.0+.

## 0.1.0

- **Initial Stable Release:** Promoted `logd_html` to a mature, standalone satellite package.
- **Core Components:** Introduced `HtmlFormatter`, `HtmlEncoder`, `HtmlStylesheet`, and `HtmlFileHandler` for modern HTML5 log document rendering with embedded responsive styling.
- **Async Isolate Execution (`HtmlFileHandler.async`)**: Added `HtmlFileHandler.async()` for non-blocking disk persistence on a background isolate, leveraging direct `@immutable` formatter/decorator transfer in Dart 3.7+.
- **Encoder Auto-Injection:** Implemented `HtmlFormatter` to inject `HtmlEncoder` dynamically via `AutoEncoder.encoderKey` metadata, maintaining clean architectural boundaries between formatting and physical encoding.
- **Isolate Registry:** Added `registerLogdHtmlSerializers()` to register `HtmlFormatter` with `LoggerSerializationRegistry` for configuration import/export.
- **Testing & Regression Safeguards:** Established a golden test suite validating HTML5 output formatting and embedded stylesheet generation across standard and error payloads.
- **Documentation:** Added `architecture.md`, `benchmarks.md`, and `migration_guide.md` covering the transition from deprecated `logd` v0.9.7 core shims.
- **Examples & Pub Readiness:** Included standard examples (`example/main.dart`), advanced file rotation patterns (`example/extra/`), BSD-3-Clause `LICENSE`, and comprehensive `README.md`.
