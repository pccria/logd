## 0.2.3

- **Diagnostics Alignment**: Migrate `HtmlFileSinkNative` to import `InternalLogger` from `package:logd/advanced.dart`, eliminating all internal implementation import and member suppressions.
- **Dependency Alignment**: Align minimum `package:logd` dependency constraint to `^0.10.8`.

## 0.2.2

- **Maintenance**: Migrate `HtmlFileSink` to invoke `FileRotation.shouldRotate(path, data)` introduced in `package:logd` 0.10.7, removing all internal file system dependencies.
- **Dependency Alignment**: Align minimum `package:logd` dependency constraint to `^0.10.7`.

## 0.2.1

- **Fix**: Replace `checkNeedsRotation` call in `HtmlFileSink` with standard `FileRotation.needsRotation(Context.fileSystem.file(path), data)` to guarantee compatibility with `package:logd` 0.10.6 across all supported platforms (iOS, Android, Linux, macOS, Windows, and Web).

## 0.2.0

- **Single-Document Integrity & Smart Rewind**:
  - Implemented `HtmlFileSink` with `HtmlFileMode` (`appendSession`, `overwrite`, `fragment`) and multi-logger `_SharedHtmlFileCoordinator`.
  - Guarantees exactly one `<!DOCTYPE html>`, `<head>`, and closing `</html>` tag even across application restarts and multiple loggers targeting the same file.
  - Automatically truncates previous closing tags upon append and inserts clean `<div class="log-session-delimiter">` session demarcations.
- **High-Performance Search & Correlation Engine**:
  - Flat in-memory search index (`buildLogIndex`) constructed on demand, replacing expensive `cloneNode(true)` operations and forced browser layout reflows.
  - Dynamic subsystem / logger dropdown selector (`showLoggerFilter: true`) automatically populated from logged entries.
  - Structured context value click-to-isolate: clicking on any `.log-val` token immediately isolates that trace or request in the viewer.
  - Debounced search input handler for smooth responsiveness on large log files.
- **Modular View Architecture**: Introduced `HtmlView` orchestrator with pluggable component interfaces:
  - `HtmlHeaderComponent` and `DefaultHtmlHeader` for custom branding, titles, and timestamp metadata.
  - `HtmlControlPanelComponent`, `DefaultHtmlControlPanel`, and `HtmlActionButton` for client-side search, level filter pills, and custom user action buttons with JavaScript hooks.
  - `HtmlFooterComponent` and `DefaultHtmlFooter` for custom attribution and environment notices.
- **Embedded Fragment Support**: Added `HtmlView.embedded` and `HtmlFileMode.fragment` for generating scoped HTML fragments without `<!DOCTYPE html>`, `<head>`, or `<body>` shells, ready for web portals and dashboards.
- **Advanced Interactivity**:
  - Regular expression search mode (`.*` toggle) with safe, error-tolerant regex compilation.
  - DOM TextNode-level match visual highlighting with `<mark class="log-search-match">` elements.
  - Client-side log export (`Export JSON` and `Export CSV`) for currently visible/filtered logs with automatic browser file downloads.
  - Live Dark / Light mode theme toggle (`showThemeToggle: true`) with `localStorage` user preference persistence.
  - Smooth Live Follow / Auto-Scroll toggle (`showLiveFollow: true`).
- **Convenience Constructors & Composability**:
  - Added `DefaultHtmlControlPanel.all()` to easily enable all interactive tools with a single declaration.
  - Implemented `copyWith` methods across `HtmlView`, `DefaultHtmlHeader`, `DefaultHtmlControlPanel`, and `DefaultHtmlFooter` for ergonomic view transformations.
  - Added `sessionLabel` customization to `HtmlFileSink` and `HtmlFileHandler` to embed operational runtime metadata (e.g. pod name, commit hash) in session resumption pills.
- **Air-Gapped & Offline Security**:
  - Added `includeExternalFonts` to `HtmlView` (defaulted to `false`), preventing unwanted external Google Fonts requests and ensuring strict Content Security Policy (CSP) and air-gapped compliance.
- **Lifecycle & Fail-Safe Hardening**:
  - Guarded `HtmlFileSink.dispose()` with an atomic `_isDisposed` flag for idempotent teardown against duplicate calls.
  - Hardened file rotation against disk/permission errors with a try/catch `InternalLogger` fallback to preserve logd's zero-silent-drop contract.
  - Optimized client-side JSON/CSV export in JavaScript by directly reading from the pre-indexed log store instead of cloning DOM subtrees.
- **Value Equality**: Implemented `operator ==` and `hashCode` across all immutable view components.

## 0.1.7

- Requires logd ^0.10.6.
- Minimum Dart SDK is now 3.10.0 (the previous 3.6.0 floor could not be resolved because of dependency requirements)
- **Maintenance**: Update repository, issue tracker, documentation, and raw asset URLs to reflect account migration to `pccria`.

## 0.1.5

- **Documentation**: Use absolute raw asset URLs for README visual diagrams to ensure proper rendering on pub.dev.

## 0.1.4

- **Documentation**: Added official high-DPI hero branding and self-contained interactive HTML report preview asset.

## 0.1.3

- **CSS Grid Span Protection**:
  - Clamped `colSpan` and `rowSpan` in `TableCellNode` to `>= 1` to ensure generated inline CSS grid styles (`grid-column: span ...`) always output valid, non-zero spans.
- **Dependency Alignment**: Updated minimum `logd` dependency constraint to `^0.10.2`.

## 0.1.2

- **Dependency Resolution**: Tightened `logd` dependency constraint to `^0.10.0` to prevent ambiguous import collisions during dependency resolution.

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
