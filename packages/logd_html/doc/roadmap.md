# logd_html Roadmap

Package version at time of writing: **0.1.3**

---

## Versioning Strategy

`logd_html` follows the semver contract defined in
[`doc/semver_contract.md`](../../../doc/semver_contract.md):

| Increment | Triggers |
|---|---|
| **Patch** (`0.1.x`) | Non-breaking styling fixes, encoding performance optimizations, and layout corrections. |
| **Minor** (`0.x.0`) | New interactive browser controls, stylesheet customizations, or report formats. |
| **Major** (`x.0.0`) | Breaking changes to CSS architecture, HTML markup contracts, or public handler APIs. |

---

## Next Milestones

### 🔲 v0.2.0: Interactive Standalone Log Explorer

**Goal**: Elevate generated HTML log files from static visual reports into zero-dependency, self-contained interactive diagnostic tools that run in any browser offline.

- [ ] **Client-Side Search Bar**:
  - Embed zero-dependency vanilla JavaScript search functionality allowing users to filter log messages, logger names, and context fields in real-time with substring and regex matching.
- [ ] **Dynamic Level Filter Pills**:
  - Add interactive toggle pills (`Verbose`, `Debug`, `Info`, `Warning`, `Error`, `WTF`) to dynamically show/hide specific log tiers in the report.
- [ ] **Collapsible Context & Stack Trace Panels**:
  - Provide interactive click-to-expand details for complex objects, structured tables, and deep stack frames, keeping the primary log stream compact and readable.
- [ ] **One-Click Export**:
  - Add a client-side button to export currently filtered log entries as raw JSON or CSV directly from the browser without server interaction.

---

## Completed

### ✅ v0.1.3: CSS Grid Span Protection & Dependency Alignment
- [x] **CSS Grid Column & Row Span Clamping**:
  - Clamped `colSpan` and `rowSpan` in `TableCellNode` to `>= 1` to ensure generated inline CSS grid styles (`grid-column: span ...`) always output valid, non-zero spans.
- [x] **Dependency Alignment**:
  - Updated minimum `logd` dependency constraint to `^0.10.2`.

---

### ✅ v0.1.2: Dependency Resolution
- [x] Tightened `logd` dependency constraint to `^0.10.0`.

---

### ✅ v0.1.0: Initial Release
- [x] Modern HTML5 log document rendering, embedded dynamic dark/light stylesheet, and `HtmlFileHandler.async` for non-blocking disk persistence on a dedicated background isolate.
