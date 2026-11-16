# logd_html Roadmap

Package version at time of writing: **0.2.0**

---

## Versioning Strategy

`logd_html` follows the semver contract defined in
[`doc/semver_contract.md`](../../../doc/semver_contract.md):

| Increment | Triggers |
|---|---|
| **Patch** (`0.2.x`) | Non-breaking styling fixes, encoding performance optimizations, and layout corrections. |
| **Minor** (`0.x.0`) | New interactive browser controls, stylesheet customizations, or report formats. |
| **Major** (`x.0.0`) | Breaking changes to CSS architecture, HTML markup contracts, or public handler APIs. |

---

## Active & Upcoming Milestones

### 🔲 v0.3.0: High-Scale Telemetry & Live Streaming

**Goal**: Extend `logd_html` for high-volume enterprise workloads (>100k entries) and integrate live browser-side telemetry feeds.

- [ ] **Virtualized DOM Rendering**:
  - Implement a virtualized scroll container for ultra-large HTML log reports, rendering only visible DOM nodes within the viewport to maintain 60 FPS scrolling on 100,000+ line documents.
- [ ] **Direct WebSocket Live Stream Ingestion**:
  - Add native client-side receiver hook to bind an open HTML report to a running `logd_network` WebSocket stream, enabling live tailing directly in existing static reports.
- [ ] **Timeline Scrubber & Burst Histogram**:
  - Render an interactive SVG time-density bar chart in the header to visually isolate error spikes and request bursts along a chronological timeline.
- [ ] **Saved Search Bookmarks & Hash URL Routing**:
  - Store active search queries, level toggles, and subsystem filters in `window.location.hash` so investigation views can be shared via URL.

---

### 🔲 v0.4.0: Universal Formatter Interoperability & Pipeline Composability

**Goal**: Decouple `HtmlEncoder` and `HtmlFileHandler` from assuming `StructuredFormatter` as the sole upstream generator, ensuring seamless rendering for `PlainFormatter`, `ToonFormatter`, compact formatters, and custom user-defined AST pipelines.

- [ ] **Format-Agnostic Semantic AST Ingestion**:
  - Audit and expand `HtmlEncoder._renderNode` to comprehensively handle all standard `LogNode` types emitted by alternative formatters (such as raw text spans from `PlainFormatter`, compact token blocks, or tabular schema structures from `ToonFormatter`).
- [ ] **First-Class Formatter Pluggability in `HtmlFileHandler`**:
  - Explicitly test and support passing any arbitrary `LogFormatter` (e.g. `PlainFormatter()`, `ToonFormatter()`) into `HtmlFileHandler` and `HtmlFileHandler.async()`.
  - Provide an automatic AST adapter so that documents emitted without `StructuredFormatter`'s metadata still receive appropriate HTML semantic envelopes (`<div class="log-entry">`, level classes, and collapsible bodies).
- [ ] **Decorator-to-HTML Structural Mapping**:
  - Map core logd decorators to native HTML/CSS structural counterparts rather than plain text approximations:
    - `BoxDecorator` -> Responsive HTML `<div class="log-box">` with configurable border styles (`solid`, `rounded`, `double`) instead of ASCII box-drawing characters.
    - `HierarchyDepthPrefixDecorator` -> CSS nested tree indentation lines (`border-left: 1px dashed ...`) rather than repeated string indentation spaces.
    - `PrefixDecorator` / `SuffixDecorator` -> Semantic `<span class="log-leading">` and `<span class="log-trailing">` badges.

---

### 🔲 v0.5.0: Cross-Sink Unified Styling System & Theme Bus Bridge

**Goal**: Unify the visual and semantic styling system across all sinks (HTML, ANSI console, Markdown, live web dashboard) so that defining a single `LogTheme` produces consistent, expected, and harmonious visual experiences everywhere.

- [ ] **Semantic Color & Palette Dual-Mode Export (`LogColor` -> CSS / ANSI)**:
  - Extend the core `LogColor` / `LogTheme` model to natively expose web-compatible color formats (`toHex()`, `toRgbCss()`, `toHslCss()`) alongside ANSI 24-bit/256-color escape codes.
  - Bridge `LogTheme` directly to CSS custom properties (`:root { --log-info: #...; --log-error: #...; }`), eliminating duplicate color declarations between Dart themes and CSS stylesheets.
- [ ] **Dynamic CSS Variable Bridging in `HtmlStylesheet`**:
  - Automatically synthesize `:root` CSS custom properties from the active `LogTheme` attached via `StyleDecorator(theme)` (`document.metadata['logd.theme']`).
  - Provide zero-boilerplate custom theming: declaring `StyleDecorator(MyCustomTheme())` automatically styles both the terminal console and the generated HTML file with identical brand colors without manual CSS injection.
- [ ] **Cross-Sink Visual Parity Contract**:
  - Establish a shared design token contract across `logd` (terminal), `logd_html` (offline reports), and `logd_network` (live WebSocket dashboard), ensuring identical badge geometries, level semantics, tag indicators, and font scale hierarchies across all presentation targets.
- [ ] **High-Contrast & Color-Blind Accessible (a11y) Presets**:
  - Provide WCAG AAA compliant theme presets (e.g. `AccessibleHighContrastTheme`, `ProtanopiaFriendlyTheme`) that seamlessly apply across ANSI terminal output and HTML/CSS web reports.

---

## Completed Milestones

### ✅ v0.2.0: Interactive Standalone Log Explorer & Modular View Architecture
- [x] **Single-Document Integrity & Smart Rewind**:
  - Implemented `HtmlFileSink` with `HtmlFileMode` (`appendSession`, `overwrite`, `fragment`) and `_SharedHtmlFileCoordinator`.
  - Guarantees exactly one `<!DOCTYPE html>`, `<head>`, and closing `</html>` tag across application restarts and multi-logger writes.
  - Automatically rewinds past `<!-- LOGD_DOCUMENT_CLOSE -->` and inserts `<div class="log-session-delimiter">` session demarcations.
- [x] **Zero DOM-Cloning Search & Value Correlation**:
  - Flat in-memory search index (`buildLogIndex`) eliminating browser reflows and DOM-cloning overhead.
  - Dynamic subsystem / logger dropdown selector (`showLoggerFilter: true`).
  - Context value click-to-isolate on `.log-val` tokens.
  - Debounced search input handler for smooth responsiveness on large files.
- [x] **Modular View Architecture**:
  - Introduced `HtmlView` with pluggable `HtmlHeaderComponent`, `HtmlControlPanelComponent`, and `HtmlFooterComponent`.
  - Added `HtmlActionButton` with user-defined JavaScript callbacks.
  - Added `HtmlView.embedded` for embedding log widgets into existing web portals and dashboards.
- [x] **Advanced Interactivity**:
  - Regular expression search mode (`.*` toggle) with TextNode-level `<mark class="log-search-match">` highlighting.
  - Client-side log export (`Export JSON` and `Export CSV`) for currently filtered entries.
  - Live Dark / Light theme toggle (`showThemeToggle: true`) with `localStorage` persistence.
  - Live Follow / Auto-Scroll toggle (`showLiveFollow: true`).
  - Convenience constructor `DefaultHtmlControlPanel.all()`.

---

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
