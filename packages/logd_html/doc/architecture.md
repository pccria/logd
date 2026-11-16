# logd_html Architecture

`logd_html` is the official HTML5 rendering satellite package for the `logd` ecosystem. It transforms logd's semantic intermediate representation (`LogDocument`, `LogNode`) into high-fidelity, interactive, zero-dependency HTML5 diagnostic reports.

---

## 1. Architectural Positioning & Semantic Boundary

Following logd's [Architectural Integrity](../../.agents/rules/architectural-integrity.md) principles, `logd_html` maintains strict separation between semantic logging IR and physical representation:

```
[ LogEntry ]
     │
     ▼
[ StructuredFormatter ] ──> Creates Semantic IR (LogDocument / LogNode)
     │
     ▼
[ HtmlFormatter ]       ──> Injects HtmlEncoder & HtmlView configuration
     │
     ▼
[ Handler / Sink ]      ──> HtmlFileSink manages physical file layout & atomic rewind
     │
     ▼
[ Browser DOM ]         ──> Vanilla JS / CSS Grid in-memory index & correlation
```

* **No Physical Width Arithmetic in Formatters**: The formatter creates pure semantic nodes (`LogSectionNode`, `TableNode`, `MapNode`, `ExceptionNode`).
* **Browser-Native Layout**: Proportional grids, flex layouts, text wrapping, and collapsible sections are handled by standard CSS (`display: grid`, `flex`, `<details>/<summary>`), avoiding artificial terminal wrapping constraints.
* **Zero External Dependencies**: All stylesheets, dark/light themes, SVG icons, and JavaScript interactivity are self-contained. Reports render completely offline in air-gapped or HIPAA/PCI compliant environments without CDN calls.

---

## 2. Core Components

### `HtmlEncoder`
Transforms `LogDocument` semantic nodes into clean, accessible HTML5 elements:
* Maps log levels to semantic CSS classes (`.log-trace`, `.log-debug`, `.log-info`, `.log-warning`, `.log-error`).
* Renders structured payloads (`MapNode`, `ListNode`) as syntax-highlighted key-value tables with interactive `.log-val` badges.
* Automatically creates collapsible `<details open>` containers for log entries with multi-frame stack traces or secondary metadata.
* Embeds the atomic document close marker: `<!-- LOGD_DOCUMENT_CLOSE -->` (`HtmlEncoder.documentCloseMarker`).

### `HtmlFormatter`
Orchestrates formatting by injecting `HtmlEncoder` into document metadata (`AutoEncoder.encoderKey`). When an `HtmlView` is specified, it binds the view configuration so sinks can emit custom headers, control panels, and footers.

### `HtmlFileSink` & Multi-Logger Coordination
Physical persistence is handled by `HtmlFileSink`, an append-resilient sink supporting multiple operational modes:

| `HtmlFileMode` | File Behavior | Use Case |
|---|---|---|
| `appendSession` *(default)* | Rewinds past previous closing tags, inserts a `<div class="log-session-delimiter">` pill, and appends new logs. | Daemon processes, long-running services, crash restarts. |
| `overwrite` | Truncates file upon initialization, writing a fresh document shell. | Short-lived CLI commands, CI build summaries, clean test runs. |
| `fragment` | Emits raw `<div class="log-entry">` elements without `<html>`, `<head>`, or `<body>` shells. | Embedding into existing web portals, admin dashboards, or iframes. |

#### Multi-Logger Thread Safety
When multiple loggers or isolates target the same HTML file on disk, `_SharedHtmlFileCoordinator` manages single-instance file handles, atomic write synchronization, and guarantees that preambles and postambles are emitted strictly once.

---

## 3. Modular View Architecture (`HtmlView`)

`HtmlView` decouples the visual shell from the log stream, allowing complete customization or headless embedding:

```dart
const customView = HtmlView(
  title: 'Cloud Settlement Mesh',
  header: DefaultHtmlHeader(
    logoText: 'LOGD // MESH',
    subtitle: 'Cluster: us-east-1 • Node: worker-04',
    showDate: true,
  ),
  controlPanel: DefaultHtmlControlPanel.all(
    searchPlaceholder: 'Search traces, users, errors...',
    extraActions: [
      HtmlActionButton(
        id: 'btn-status',
        label: 'Cluster Status: OK',
        onClickJs: "alert('All nodes healthy.')",
      ),
    ],
  ),
  footer: DefaultHtmlFooter(attribution: 'ACME Observability'),
);
```

### Component Hierarchy
* **`HtmlHeaderComponent`** (`DefaultHtmlHeader`): Renders branding logo, subtitle, environment tags, and document creation timestamps.
* **`HtmlControlPanelComponent`** (`DefaultHtmlControlPanel`): Renders search input, regex mode toggle (`.*`), subsystem dropdown (`#log-logger-select`), level filter pills with dynamic count badges, live follow toggle, expand/collapse toggles, and JSON/CSV client-side export buttons.
* **`HtmlFooterComponent`** (`DefaultHtmlFooter`): Renders copyright notices, compliance disclaimers, and engine attribution.
* **`HtmlView.embedded`**: Omits outer HTML document wrappers, generating a standalone container ready to drop into React, Vue, Angular, or Flutter Web webviews.

---

## 4. In-Memory Search & Value Correlation Engine

To prevent UI lag and browser freezing when viewing large log reports (10,000+ entries), `logd_html` completely eliminates DOM cloning and forced layout reflows:

```
[ Page Load ]
     │
     ▼
[ buildLogIndex() ] ──> Flat JS Array: [{ el, level, logger, text }, ...]
     │
     ▼
[ Search Keystroke / Filter Click ]
     │
     ├── Evaluates regex / substring strictly against JS memory strings
     ├── Toggles `el.style.display = 'none'` or `''` directly
     └── Updates level counter badges without full DOM recalculation
```

### Context Value Correlation (Click-to-Isolate)
Every structured value node (`.log-val`) carries an event listener. Clicking on any value (e.g. `trc-fin-99440`, `usr-retail-88`, `ERR_CIRCUIT_OPEN`) automatically fills the search input and isolates the full end-to-end trace across all subsystems.

---

## 5. Isolate Safety & Background Offloading

Disk I/O and HTML encoding can be offloaded entirely to a background Dart worker isolate using `HtmlFileHandler.async()`:

```dart
final handler = HtmlFileHandler.async(
  path: 'logs/production.html',
  view: customView,
);
```

* All configuration models (`HtmlView`, `DefaultHtmlControlPanel`, `LogTheme`) are `@immutable` and compile-time constants, allowing zero-overhead direct transfer across Dart 3.7+ isolate `SendPort`s.
* File coordinators ensure that multiple background isolates writing to the same file path maintain atomic chunk boundaries.

---

## 6. Strategic Evolution: Universal Pipeline & Cross-Sink Theming

Two long-term architectural initiatives expand `logd_html`'s role in the wider ecosystem:

### 1. Universal Formatter Interoperability
While `HtmlFormatter` currently wraps `StructuredFormatter` by default, `HtmlEncoder` is evolving toward total formatter agnosticism. Future releases will natively ingest semantic AST nodes from `PlainFormatter`, `ToonFormatter`, and user-defined formatters, mapping decorators (`BoxDecorator`, `HierarchyDepthPrefixDecorator`) into responsive HTML structural tags rather than plain text approximations.

### 2. Cross-Sink Unified Theming Bus
To preserve intuitive DX and UX across the monorepo, `LogTheme` will bridge directly between terminal ANSI codes and CSS custom properties (`:root { --log-info: #...; }`). Defining a single theme via `StyleDecorator(MyBrandTheme())` will automatically and faithfully style terminal console output, offline HTML reports, and live browser dashboards with identical color palettes and visual hierarchy.
