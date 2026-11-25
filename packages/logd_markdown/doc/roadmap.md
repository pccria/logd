# logd_markdown Roadmap

Package version at time of writing: **0.2.0**

---

## Versioning Strategy

`logd_markdown` follows the semver contract defined in
[`doc/semver_contract.md`](../../../doc/semver_contract.md):

| Increment | Triggers |
|---|---|
| **Patch** (`0.2.x`) | Non-breaking formatting bug fixes, CommonMark escaping corrections, and table formatting passes. |
| **Minor** (`0.x.0`) | New CI integration sinks, syntax highlighting themes, or custom block encoders. |
| **Major** (`x.0.0`) | Breaking changes to Markdown encoding contracts, AST mapping, or public handler APIs. |

---

## Next Milestones

### 🔲 v0.3.0: Richer CI/CD Artifacts & Diff-Aware PR Reports
**Goal**: Expand CI/CD observability with PR comment templates and multi-run trend comparisons.

- [ ] **Bitbucket & Azure DevOps Templates**:
  - Dedicated formatting presets for Bitbucket Pipelines and Azure Pipelines Markdown renderers.
- [ ] **Baseline Comparison Deltas**:
  - Side-by-side severity and duration delta columns in `MarkdownRunSummary` against previous CI artifacts.

---

## Completed

### ✅ v0.2.0: CI/CD Step Summaries, Table Digest Mode & Multi-Dialect Support
- [x] **GitHub Actions `$GITHUB_STEP_SUMMARY` Integration (`GitHubStepSummaryHandler`)**:
  - Auto-resolves `GITHUB_STEP_SUMMARY` (with local fallback and Web-safe conditional imports), tracks `MarkdownRunSummary` severity counts and bounded failures, and appends an executive GFM summary table + collapsible failure details.
- [x] **Compact Table Mode (`MarkdownTableFormatter`)**:
  - Emits aligned GFM/CommonMark/GitLab table rows with pipe escaping and inline JSON context cells.
- [x] **Multi-Dialect Output (`MarkdownDialect`)**:
  - Added `MarkdownDialect.gfm`, `MarkdownDialect.commonmark`, and `MarkdownDialect.gitlab` across formatters, encoders, and handlers.
- [x] **Safe `MapNode` Context Serialization & Handler Parity**:
  - Safe `toEncodable` JSON serialization for non-JSON Dart types, configurable `contextLanguage`, and parameter parity across `MarkdownFileHandler` / `.async()`.

---

### ✅ v0.1.3: CommonMark Dynamic Code Fence Scaling & Dependency Alignment
- [x] **Dynamic Fence Scaling (`_writeFencedBlock`)**:
  - Implemented dynamic code fence sizing for fenced code blocks (`MapNode`, `LogTag.stackFrame`, collapsible sections), dynamically sizing the backtick fence (e.g. ```` ```` ````) whenever content contains triple backticks to prevent premature fence closing and markdown syntax breakout.
- [x] **Dependency Alignment**:
  - Updated minimum `logd` dependency constraint to `^0.10.2`.

---

### ✅ v0.1.2: Dependency Resolution
- [x] Tightened `logd` dependency constraint to `^0.10.0`.

---

### ✅ v0.1.0: Initial Release
- [x] GitHub-Flavored Markdown (GFM) formatter, encoder, and file handler with table rendering, code fences, collapsible sections, and `MarkdownFileHandler.async`.
