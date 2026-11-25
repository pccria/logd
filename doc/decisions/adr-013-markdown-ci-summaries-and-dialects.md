# ADR-013: Multi-Dialect Markdown Encoding, Compact Table Formatting, and CI/CD Step Summary Aggregation

## Status
Accepted (v0.2.0)

## Context
`package:logd_markdown` provides GitHub-Flavored Markdown (GFM) log rendering, primarily used for CI/CD job summaries, PR comments, and human-readable diagnostic reports. In `v0.1.x`, three operational limitations emerged:
1. **Single-Dialect Coupling**: All error and note callouts emitted GitHub-specific alert extensions (`> [!ERROR]`, `> [!NOTE]`) and raw `<details>` HTML blocks, which render poorly or as plain literal tags in strict CommonMark viewers.
2. **Verbosity in High-Volume CI Runs**: Every `LogEntry` emitted a standalone `###` heading, body paragraph, and horizontal rule (`---`), making multi-step CI logs difficult to scan compared to compact tables.
3. **Manual CI Boilerplate**: Consumers writing to GitHub Actions `$GITHUB_STEP_SUMMARY` had to manually inspect environment variables, track pass/fail counts, and guard against local runs where `$GITHUB_STEP_SUMMARY` is unset.
4. **Web Compatibility Constraint**: `package:logd_markdown` supports all 6 Dart platforms including Web, prohibiting unconditional `dart:io` imports for environment/file access.

---

## Decisions

### 1. Multi-Dialect Rendering (`MarkdownDialect`)
We introduce `MarkdownDialect` (`gfm`, `commonmark`, `gitlab`) across `MarkdownEncoder`, `MarkdownFormatter`, `MarkdownTableFormatter`, `MarkdownFileHandler`, and `GitHubStepSummaryHandler`:
- **`MarkdownDialect.gfm`** *(default)*: Preserves `v0.1.7` GFM alert callouts (`> [!ERROR]`, `> [!NOTE]`) and `<details>/<summary>` collapsible blocks.
- **`MarkdownDialect.commonmark`**: Emits pure CommonMark (`> **Error:**`, `> **Note:**`, bold section headings instead of `<details>` HTML, and spaces instead of `<br>` in table cells).
- **`MarkdownDialect.gitlab`**: Emits bold blockquotes alongside `<details>/<summary>` collapsible blocks supported by GitLab Flavored Markdown.

### 2. Compact Table Mode (`MarkdownTableFormatter`)
We introduce `@immutable final class MarkdownTableFormatter implements LogFormatter`:
- Emits a single GFM table header via `MarkdownEncoder.preamble(...)` and one aligned table row per `LogEntry` (`| Timestamp | Level | Logger | Message | Context |`).
- Sanitizes pipe characters (`|` -> `\|`), normalizes newlines (`<br>` in GFM/GitLab, space in CommonMark), and formats `LogEntry.context` as compact inline JSON.

### 3. CI Step Summary Aggregation (`GitHubStepSummaryHandler` & `MarkdownRunSummary`)
We introduce `GitHubStepSummaryHandler extends Handler`:
- **Automatic Environment Resolution**: Reads `Platform.environment['GITHUB_STEP_SUMMARY']` via conditional imports (`github_env_stub.dart` / `github_env_io.dart`), preserving Web platform compatibility. Accepts explicit `path` or `fallbackPath`, and degrades safely to an in-memory collector when no path is resolved.
- **Bounded Run Summary (`MarkdownRunSummary`)**: Tracks per-level counts, elapsed `Duration`, and up to `maxFailures` (default `50`) `MarkdownSummaryFailure` entries without unbounded memory growth.
- **Idempotent Rollup**: On `writeSummary()` or `dispose()`, appends an executive severity metrics table and collapsible failure details block once.

### 4. Safe `MapNode` Context Serialization
`MarkdownEncoder` serializes `MapNode` maps via `jsonEncode(..., toEncodable: _toJsonEncodable)`, safely converting `DateTime`, `Duration`, `Enum`, and non-JSON objects without throwing while preserving compact JSON compatibility.

---

## Consequences
- **Zero Breaking Changes**: Default `MarkdownEncoder()` and `MarkdownFormatter()` remain 100% backward compatible with `v0.1.x` golden outputs.
- **Web-Safe CI Support**: Conditional imports keep `package:logd_markdown` compilable on Web while enabling zero-boilerplate `$GITHUB_STEP_SUMMARY` integration on native CI runners.
- **Zero Extra Dependencies**: Remains dependent solely on `logd` and `meta`.
