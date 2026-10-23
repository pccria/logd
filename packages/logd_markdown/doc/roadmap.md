# logd_markdown Roadmap

Package version at time of writing: **0.1.3**

---

## Versioning Strategy

`logd_markdown` follows the semver contract defined in
[`doc/semver_contract.md`](../../../doc/semver_contract.md):

| Increment | Triggers |
|---|---|
| **Patch** (`0.1.x`) | Non-breaking formatting bug fixes, CommonMark escaping corrections, and table formatting passes. |
| **Minor** (`0.x.0`) | New CI integration sinks, syntax highlighting themes, or custom block encoders. |
| **Major** (`x.0.0`) | Breaking changes to Markdown encoding contracts, AST mapping, or public handler APIs. |

---

## Next Milestones

### 🔲 v0.2.0: CI/CD Platform Observability & Automated Step Summaries

**Goal**: Seamlessly bridge developer log telemetry with modern CI/CD step summary interfaces.

- [ ] **GitHub Actions `$GITHUB_STEP_SUMMARY` Integration**:
  - Add native handler to stream formatted execution logs, benchmark summaries, and error diagnostics directly to the GitHub Actions Job Summary output.
- [ ] **GitLab CI & Bitbucket Pipelines Formatter**:
  - Add specialized markdown templates tailored for GitLab CI collapsible log sections and Bitbucket Pipelines report artifacts.
- [ ] **Syntax-Highlighted Context Blocks**:
  - Automatic language tag inference (`json`, `yaml`, `dart`, `sql`) for code blocks based on context payload structure.

---

## Completed

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
