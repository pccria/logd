# ADR-009: Strict Terminal Cell-Grid Authority and Rejection of Client-Side Web Fallback Spacing Hacks

## Status
Accepted (v0.10.2)

## Context
During layout stabilization for `TerminalLayout` and `BoxDecorator`, an issue was investigated regarding right-hand vertical box borders (`│`) appearing visually uneven or shifted in web chat interfaces, IDE markdown previews, and browser code blocks when rendering East Asian / CJK ideographs (e.g. Mandarin, Japanese, Korean) or complex emoji sequences.

A proposal was evaluated to detect multi-byte CJK characters and inject variable client-side ASCII space padding to visually push borders outward to align in web interfaces.

## Investigation & Root Cause

1. **Terminal Grid vs. Monospace Font Advance Mismatch**:
   - In standard terminal emulators (GNOME Terminal, Alacritty, iTerm2, Windows Terminal, tmux, kitty), character rendering is strictly grid-cell based. Per POSIX `wcwidth` and Unicode Standard Annex #11 (East Asian Width), ASCII characters occupy exactly **1 cell**, East Asian Wide/Fullwidth ideographs occupy exactly **2 cells**, and space characters occupy 1 cell. Every line calculated by `TerminalLayout` to a target width (e.g. 60 cells) wraps and aligns to character-cell perfection.
   - In web browsers, chat interfaces, and Electron IDE previews, monospace code blocks rely on font fallback stacks. Standard Latin monospace fonts (Roboto Mono, SF Mono, Consolas) lack CJK glyphs. When rendering ideographs, the browser substitutes a fallback font (such as Noto Sans CJK). In many proportional fallback fonts, a CJK glyph's pixel advance width is narrower than 2 Latin spaces (~16.0 px vs. ~19.3 px at standard 16 px size).
   - Because standard plain-text CLI streams can only emit integer character spaces for padding, the visual width falls short in pixels on web renderers, causing right borders to visually indent.

2. **The Conflict of Space Compensation**:
   - If `TerminalLayout` injects extra ASCII space padding to compensate for web font pixel advance shortfalls, the output will immediately **overshoot and wrap prematurely** on every real terminal emulator, breaking the box layout completely for CLI users.
   - Plain-text streams emitted to `stdout` or log files have no access to client-side DOM font metrics, CSS stylesheets, dpi scaling, or user zoom levels.

## Decision

1. **`TerminalLayout` is the sole authority on terminal physical layout and strictly adheres to standard terminal cell grids.**
   - Width calculations strictly enforce POSIX `wcwidth` / Unicode UAX #11 standards: 1 cell for halfwidth/Latin, 2 cells for fullwidth/wide CJK, and 8-column tab-stop expansions.
   - Plain-text output will never introduce heuristic whitespace compensation for third-party browser font metrics.
2. **Web, HTML, and Rich Interfaces Must Use Dedicated Satellite Formatters**:
   - For web browsers, dashboards, and rich document rendering, users should employ [`package:logd_html`](../../packages/logd_html) or [`package:logd_network`](../../packages/logd_network), where CSS Grid, Flexbox, and HTML DOM table models handle proportional rendering natively without ASCII grid approximations.

## Consequences

### Positive
- **Guaranteed Terminal Fidelity**: Log formatting remains deterministic, predictable, and 100% compliant with standard ANSI terminal emulators.
- **Clear Architectural Separation**: Plain-text terminal layout does not leak browser-specific font assumptions.
- **Zero Overhead**: Eliminates complex, brittle heuristic string calculations on hot logging paths.
