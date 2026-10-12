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
