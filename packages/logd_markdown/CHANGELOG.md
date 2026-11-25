## 0.2.0

- **CI/CD Step Summary Integration (`GitHubStepSummaryHandler` & `MarkdownRunSummary`)**:
  - Introduced `GitHubStepSummaryHandler`, automatically resolving `$GITHUB_STEP_SUMMARY` (with `path` / `fallbackPath` overrides and safe no-op local fallback) and remaining Web-compatible via conditional imports.
  - Added `MarkdownRunSummary` and `MarkdownSummaryFailure` to track per-severity entry counts, elapsed duration, and bounded failure details, emitting an executive GFM summary table and collapsible failure section on `writeSummary()` / `dispose()`.
- **Compact Table Digest Mode (`MarkdownTableFormatter`)**:
  - Added `MarkdownTableFormatter` for rendering aligned GFM/CommonMark/GitLab table rows with pipe escaping, newline handling (`<br>` vs space), and inline JSON context cells.
- **Multi-Dialect Support (`MarkdownDialect`)**:
  - Introduced `MarkdownDialect` (`gfm`, `commonmark`, `gitlab`) across `MarkdownEncoder`, `MarkdownFormatter`, `MarkdownTableFormatter`, `MarkdownFileHandler`, and `GitHubStepSummaryHandler`.
- **Safe Context Serialization (`MapNode`)**:
  - Updated `MarkdownEncoder` to serialize `MapNode` payloads with `toEncodable` fallbacks for `DateTime`, `Duration`, `Enum`, and custom objects, plus configurable `contextLanguage` (default `'json'`).
- **Handler Parity, Serializers & Showcase**:
  - Added `metadata`, `dialect`, `contextLanguage`, and `tableMode` parameters to `MarkdownFileHandler` and `MarkdownFileHandler.async()`.
  - Updated `registerLogdMarkdownSerializers()` to serialize `MarkdownFormatter` (`dialect`, `contextLanguage`, `metadata`) and `MarkdownTableFormatter`.
  - Added runnable 4-scenario showcase (`example/showcase_gallery.dart`) and expanded test coverage.

## 0.1.7

- Requires logd ^0.10.6.
- Minimum Dart SDK is now 3.10.0 (the previous 3.6.0 floor could not be resolved because of dependency requirements)
- **Maintenance**: Update repository, issue tracker, documentation, and raw asset URLs to reflect account migration to `pccria`.

## 0.1.5

- **Documentation**: Use absolute raw asset URLs for README visual diagrams to ensure proper rendering on pub.dev.

## 0.1.4

- **Documentation**: Added official high-DPI hero branding.

## 0.1.3

- **Code Block Escaping & CommonMark Immunity**:
  - Implemented dynamic code fence sizing (`_writeFencedBlock`) for fenced code blocks (`MapNode`, `LogTag.stackFrame`, collapsible sections), dynamically sizing the backtick fence (e.g. ```` ```` ````) whenever content contains triple backticks to prevent premature fence closing and markdown syntax breakout.
- **Dependency Alignment**: Updated minimum `logd` dependency constraint to `^0.10.2`.

## 0.1.2

- **Dependency Resolution**: Tightened `logd` dependency constraint to `^0.10.0` to prevent ambiguous import collisions during dependency resolution.

## 0.1.1

- **`logd` v0.10.x Support**: Widened dependency constraint to `logd: '>=0.9.7 <0.11.0'`, enabling seamless compatibility with `logd` v0.10.0's pure semantic engine.
- **Clean Imports (No Shims)**: Removed obsolete `hide` clauses from documentation and examples as legacy Markdown shims have been permanently deleted in `logd` v0.10.0.
- **Documentation**: Updated migration guide to reflect permanent removal of core shims in `logd` v0.10.0+.

## 0.1.0

- **Initial Stable Release:** Promoted `logd_markdown` to a mature, standalone satellite package.
- **Core Components:** Introduced `MarkdownFormatter`, `MarkdownEncoder`, and `MarkdownFileHandler` for GitHub-Flavored Markdown (GFM) log rendering.
- **Async Isolate Execution (`MarkdownFileHandler.async`)**: Added `MarkdownFileHandler.async()` for non-blocking disk persistence on a background isolate, leveraging direct `@immutable` formatter/decorator transfer in Dart 3.7+.
- **Exhaustive Semantic IR Support:** Encodes all core semantic IR node types (`TableNode`, `CodeBlockNode`, `ListNode`, `BlockquoteNode`, `MapNode`, and `KeyValueNode`) into valid GFM syntax.
- **Encoder Auto-Injection:** Implemented `MarkdownFormatter` to inject `MarkdownEncoder` dynamically via `AutoEncoder.encoderKey` metadata, maintaining clean separation between semantic formatting and physical string layout.
- **Isolate Registry:** Added `registerLogdMarkdownSerializers()` to register `MarkdownFormatter` and `MarkdownEncoder` with `LoggerSerializationRegistry` for configuration import/export.
- **Testing & Regression Safeguards:** Established a golden test harness validating GFM output against baseline files across standard and error payloads.
- **Documentation & Examples:** Added `architecture.md`, `benchmarks.md`, `migration_guide.md`, standard examples (`example/main.dart`), and file rotation patterns (`example/extra/`).
