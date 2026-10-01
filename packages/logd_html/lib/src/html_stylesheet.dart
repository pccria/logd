import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'html_encoder.dart';

/// Controls the CSS and JS output of an [HtmlEncoder] session.
///
/// Implement this interface to customize the visual appearance of generated
/// HTML log files without touching [HtmlEncoder].
abstract interface class HtmlStylesheet {
  /// Generates the CSS string injected into the `<style>` block.
  ///
  /// [theme] is provided by [HtmlEncoder] from the pipeline context.
  String buildCss(final LogTheme theme);

  /// Generates the JavaScript string injected before `</body>`.
  String buildJs();
}

/// The default stylesheet shipped with logd.
@immutable
class DefaultHtmlStylesheet implements HtmlStylesheet {
  /// Creates a [DefaultHtmlStylesheet].
  const DefaultHtmlStylesheet();

  @override
  String buildCss(final LogTheme theme) {
    final isDark = theme.brightness == LogBrightness.dark;

    final bg = isDark ? '#1e1e1e' : '#ffffff';
    final fg = isDark ? '#d4d4d4' : '#000000';

    final cTrace = _cssColor(theme, LogLevel.trace);
    final cDebug = _cssColor(theme, LogLevel.debug);
    final cInfo = _cssColor(theme, LogLevel.info);
    final cWarning = _cssColor(theme, LogLevel.warning);
    final cError = _cssColor(theme, LogLevel.error);

    return '''
    :root {
      --bg: $bg;
      --fg: $fg;
      --trace: $cTrace;
      --debug: $cDebug;
      --info: $cInfo;
      --warning: $cWarning;
      --error: $cError;
      --border: ${isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)'};
      --header-bg: ${isDark ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.02)'};
      --indigo: #6366f1;
    }

    * { box-sizing: border-box; }
    p, div { margin: 0; padding: 0; }

    body {
      background-color: var(--bg);
      color: var(--fg);
      font-family: 'Fira Code', 'SFMono-Regular', Consolas, 'Courier New', monospace;
      font-size: 13px;
      line-height: 1.5;
      margin: 0;
      display: flex;
      flex-direction: column;
      min-height: 100vh;
    }
    .log-container {
      max-width: 1400px;
      margin: 0 auto;
      padding: 1rem 2rem;
      flex: 1;
      width: 100%;
    }

    /* === Session Header === */
    .log-session-header {
      margin-bottom: 2rem;
      padding: 1.5rem 2rem;
      background: var(--header-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-left: 4px solid var(--info);
      font-family: 'Outfit', 'Inter', sans-serif;
    }
    .log-session-branding {
      display: flex;
      align-items: center;
      gap: 1rem;
    }
    .log-session-logo {
      font-family: 'Outfit', sans-serif;
      font-weight: 900;
      font-size: 1.8rem;
      letter-spacing: -1px;
      color: var(--info);
    }
    .log-session-divider { opacity: 0.3; font-size: 1.5rem; }
    .log-session-title { font-weight: 500; font-size: 1.1rem; opacity: 0.8; }
    .log-session-meta { text-align: right; }
    .log-session-date { font-size: 11px; opacity: 0.5; font-weight: 300; }

    /* === Control Panel === */
    .log-control-panel {
      margin-bottom: 2rem;
      padding: 1.5rem;
      background: var(--header-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      display: flex;
      flex-direction: column;
      gap: 1rem;
    }
    .log-controls-row {
      display: flex;
      gap: 1rem;
      align-items: center;
      flex-wrap: wrap;
    }
    .log-controls-row.secondary-controls {
      justify-content: flex-end;
      padding-top: 0.5rem;
      border-top: 1px dashed var(--border);
    }

    .log-search-wrapper {
      flex: 1;
      min-width: 250px;
      position: relative;
    }
    .log-search-wrapper input {
      width: 100%;
      padding: 0.6rem 1rem;
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 6px;
      color: var(--fg);
      font-family: inherit;
      font-size: 13px;
      outline: none;
      transition: border-color 0.2s;
    }
    .log-search-wrapper input:focus {
      border-color: var(--info);
    }

    .log-level-filters {
      display: flex;
      gap: 0.4rem;
      flex-wrap: wrap;
    }
    .log-filter-btn, .log-action-btn {
      background: var(--bg);
      border: 1px solid var(--border);
      color: var(--fg);
      padding: 0.5rem 0.8rem;
      border-radius: 6px;
      font-size: 12px;
      font-family: 'Inter', sans-serif;
      font-weight: 500;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 0.4rem;
      transition: all 0.15s ease;
      user-select: none;
    }
    .log-action-btn {
      font-size: 11px;
      padding: 0.35rem 0.6rem;
      opacity: 0.8;
    }
    .log-action-btn:hover {
      opacity: 1;
      border-color: var(--fg);
    }
    .log-filter-btn .log-level-count {
      background: rgba(255,255,255,0.1);
      padding: 0.1rem 0.4rem;
      border-radius: 10px;
      font-size: 10px;
    }

    /* Filter Active States */
    .log-filter-btn.active[data-level="trace"] { border-color: var(--trace); color: var(--trace); background: rgba(34, 197, 94, 0.08); }
    .log-filter-btn.active[data-level="debug"] { border-color: var(--debug); color: var(--debug); background: rgba(255, 255, 255, 0.08); }
    .log-filter-btn.active[data-level="info"] { border-color: var(--info); color: var(--info); background: rgba(59, 130, 246, 0.08); }
    .log-filter-btn.active[data-level="warning"] { border-color: var(--warning); color: var(--warning); background: rgba(234, 179, 8, 0.08); }
    .log-filter-btn.active[data-level="error"] { border-color: var(--error); color: var(--error); background: rgba(239, 68, 68, 0.08); }

    .log-filter-btn:not(.active) {
      opacity: 0.4;
      text-decoration: line-through;
    }

    /* === Log Entries === */
    .log-entry {
      margin-bottom: 0.75rem;
      padding: 0.75rem 1rem;
      background: var(--header-bg);
      border: 1px solid var(--border);
      border-radius: 6px;
      position: relative;
      transition: background 0.15s;
    }
    .log-entry:hover {
      background: rgba(255,255,255,0.02);
    }
    .log-entry.log-trace { border-left: 3px solid var(--trace); }
    .log-entry.log-debug { border-left: 3px solid var(--debug); }
    .log-entry.log-info { border-left: 3px solid var(--info); }
    .log-entry.log-warning { border-left: 3px solid var(--warning); }
    .log-entry.log-error { border-left: 3px solid var(--error); }

    .log-copy-btn {
      position: absolute;
      top: 0.75rem;
      right: 0.75rem;
      background: var(--header-bg);
      border: 1px solid var(--border);
      color: var(--fg);
      opacity: 0;
      cursor: pointer;
      padding: 0.35rem;
      width: 28px;
      height: 28px;
      border-radius: 6px;
      transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      z-index: 10;
    }
    .log-entry:hover .log-copy-btn {
      opacity: 0.6;
    }
    .log-copy-btn:hover {
      opacity: 1 !important;
      background: var(--bg);
      border-color: var(--info);
      color: var(--info);
      transform: scale(1.05);
    }
    .log-copy-btn:active {
      transform: scale(0.95);
    }
    .log-copy-btn.copied {
      opacity: 1 !important;
      background: rgba(34, 197, 94, 0.15);
      border-color: rgba(34, 197, 94, 0.4);
      color: #22c55e;
    }
    .log-copy-btn svg {
      width: 14px;
      height: 14px;
      stroke-width: 2.2px;
      pointer-events: none;
    }

    .log-header-node { margin-bottom: 0.4rem; font-weight: 600; }
    .log-message-node { margin-bottom: 0.2rem; word-break: break-word; }
    .log-error-node { color: var(--error); font-weight: 500; margin-top: 0.4rem; }
    .log-footer-node { opacity: 0.7; font-size: 11px; margin-top: 0.4rem; }
    .log-line,
    pre {
      margin: 0;
      white-space: pre-wrap;
      word-break: break-word;
      overflow-wrap: anywhere;
      min-width: 0;
      width: 100%;
      box-sizing: border-box;
    }

    /* === Structural Components === */
    .log-box {
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 0.75rem 1rem;
      margin: 0.5rem 0;
      background: rgba(0,0,0,0.1);
      min-width: 0;
      max-width: 100%;
      box-sizing: border-box;
    }
    .log-box-sharp { border-radius: 0; }
    .log-box-double { border-style: double; border-width: 3px; }
    .log-box-none { border: none; padding: 0; background: transparent; }
    .log-box legend {
      padding: 0 0.5rem;
      font-weight: 600;
      font-size: 12px;
    }

    .log-indent {
      padding-left: 1.2rem;
      border-left: 1px dashed var(--border);
      margin: 0.2rem 0;
      min-width: 0;
      max-width: 100%;
      box-sizing: border-box;
    }

    .log-decorated {
      display: flex;
      align-items: flex-start;
      gap: 0.5rem;
      min-width: 0;
      width: 100%;
      box-sizing: border-box;
    }
    .log-decorated-content {
      flex: 1;
      min-width: 0;
      width: 100%;
      box-sizing: border-box;
    }
    .log-leading, .log-trailing {
      opacity: 0.6;
      user-select: none;
      flex-shrink: 0;
    }

    .log-row {
      display: flex;
      gap: 1rem;
      flex-wrap: wrap;
    }
    .log-row-cell { flex: 1; min-width: 150px; }

    .log-section {
      margin: 0.4rem 0;
    }
    .log-section-summary {
      cursor: pointer;
      user-select: none;
      font-weight: 500;
      opacity: 0.9;
    }
    .log-section-body {
      padding-left: 1rem;
      margin-top: 0.4rem;
      border-left: 1px solid var(--border);
    }

    /* === Data Types & Syntax Highlighting === */
    .log-map, .log-list { font-family: inherit; }
    .log-key { color: var(--indigo); font-weight: 500; }
    .log-val { color: var(--fg); }
    .log-punct { opacity: 0.5; }

    .log-timestamp { opacity: 0.5; font-size: 11px; margin-right: 0.5rem; }
    .log-level { font-weight: 700; margin-right: 0.5rem; text-transform: uppercase; font-size: 11px; }
    .log-logger { opacity: 0.7; font-weight: 500; margin-right: 0.5rem; }
    .log-stacktrace { font-size: 11px; opacity: 0.8; font-family: inherit; white-space: pre; overflow-x: auto; }
    .stack-frame { font-size: 11px; opacity: 0.8; font-family: inherit; }

    /* === Page Footer === */
    .log-page-footer {
      text-align: center;
      padding: 2rem;
      font-size: 11px;
      opacity: 0.4;
      font-family: 'Inter', sans-serif;
    }
    .log-page-footer a { color: inherit; }
    ''';
  }

  @override
  String buildJs() => '''
    const activeFilters = {
      trace: true,
      debug: true,
      info: true,
      warning: true,
      error: true
    };
    let searchQuery = '';

    function applyFilters() {
      const entries = document.querySelectorAll('.log-entry');
      const counts = { trace: 0, debug: 0, info: 0, warning: 0, error: 0 };
      
      entries.forEach(entry => {
        let show = true;
        
        let entryLevel = '';
        if (entry.classList.contains('log-trace')) entryLevel = 'trace';
        else if (entry.classList.contains('log-debug')) entryLevel = 'debug';
        else if (entry.classList.contains('log-info')) entryLevel = 'info';
        else if (entry.classList.contains('log-warning')) entryLevel = 'warning';
        else if (entry.classList.contains('log-error')) entryLevel = 'error';
        
        if (entryLevel && !activeFilters[entryLevel]) {
          show = false;
        }
        
        if (show && searchQuery) {
          const clone = entry.cloneNode(true);
          const copyBtn = clone.querySelector('.log-copy-btn');
          if (copyBtn) copyBtn.remove();
          const text = clone.innerText || clone.textContent;
          if (!text.toLowerCase().includes(searchQuery.toLowerCase())) {
            show = false;
          }
        }
        
        entry.style.display = show ? '' : 'none';
        
        if (entryLevel) {
          let matchSearch = true;
          if (searchQuery) {
            const clone = entry.cloneNode(true);
            const copyBtn = clone.querySelector('.log-copy-btn');
            if (copyBtn) copyBtn.remove();
            const text = clone.innerText || clone.textContent;
            if (!text.toLowerCase().includes(searchQuery.toLowerCase())) {
              matchSearch = false;
            }
          }
          if (matchSearch) {
            counts[entryLevel]++;
          }
        }
      });
      
      for (const level in counts) {
        const countEl = document.getElementById('count-' + level);
        if (countEl) countEl.textContent = counts[level];
      }
    }

    document.querySelectorAll('.log-filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const level = btn.getAttribute('data-level');
        activeFilters[level] = !activeFilters[level];
        btn.classList.toggle('active', activeFilters[level]);
        applyFilters();
      });
    });

    const searchInput = document.getElementById('log-search-input');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        searchQuery = e.target.value;
        applyFilters();
      });
    }

    const btnExpand = document.getElementById('btn-expand-all');
    if (btnExpand) {
      btnExpand.addEventListener('click', () => {
        document.querySelectorAll('details').forEach(d => d.open = true);
      });
    }

    const btnCollapse = document.getElementById('btn-collapse-all');
    if (btnCollapse) {
      btnCollapse.addEventListener('click', () => {
        document.querySelectorAll('details').forEach(d => d.open = false);
      });
    }

    document.querySelectorAll('.log-copy-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const entry = btn.closest('.log-entry');
        const clone = entry.cloneNode(true);
        const copyBtn = clone.querySelector('.log-copy-btn');
        if (copyBtn) copyBtn.remove();
        const text = clone.innerText || clone.textContent;
        
        navigator.clipboard.writeText(text).then(() => {
          btn.classList.add('copied');
          const originalSvg = btn.innerHTML;
          btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
          setTimeout(() => {
            btn.classList.remove('copied');
            btn.innerHTML = originalSvg;
          }, 1500);
        });
      });
    });

    applyFilters();
  ''';

  String _cssColor(final LogTheme theme, final LogLevel level) {
    final color = theme.colorForLevel(level);
    final isDark = theme.brightness == LogBrightness.dark;

    final map = isDark ? _darkColorMap : _lightColorMap;
    return map[color] ?? 'inherit';
  }

  static const _darkColorMap = <LogColor, String>{
    LogColor.black: '#000000',
    LogColor.red: '#ef4444',
    LogColor.green: '#22c55e',
    LogColor.yellow: '#eab308',
    LogColor.blue: '#3b82f6',
    LogColor.magenta: '#a855f7',
    LogColor.cyan: '#06b6d4',
    LogColor.white: '#f1f5f9',
    LogColor.brightBlack: '#374151',
    LogColor.brightRed: '#f87171',
    LogColor.brightGreen: '#4ade80',
    LogColor.brightYellow: '#fde047',
    LogColor.brightBlue: '#60a5fa',
    LogColor.brightMagenta: '#c084fc',
    LogColor.brightCyan: '#22d3ee',
    LogColor.brightWhite: '#f8fafc',
  };

  static const _lightColorMap = <LogColor, String>{
    LogColor.black: '#000000',
    LogColor.red: '#b91c1c',
    LogColor.green: '#15803d',
    LogColor.yellow: '#b45309',
    LogColor.blue: '#1d4ed8',
    LogColor.magenta: '#6d28d9',
    LogColor.cyan: '#0f766e',
    LogColor.white: '#334155',
    LogColor.brightBlack: '#1e293b',
    LogColor.brightRed: '#991b1b',
    LogColor.brightGreen: '#166534',
    LogColor.brightYellow: '#92400e',
    LogColor.brightBlue: '#1e40af',
    LogColor.brightMagenta: '#5b21b6',
    LogColor.brightCyan: '#115e59',
    LogColor.brightWhite: '#0f172a',
  };
}
