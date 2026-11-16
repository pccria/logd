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
    .log-header-divider { opacity: 0.3; font-size: 1.5rem; }
    .log-session-title { font-weight: 500; font-size: 1.1rem; opacity: 0.8; }
    .log-session-meta { text-align: right; }
    .log-session-date { font-size: 11px; opacity: 0.5; font-weight: 300; }

    /* === Session Resumption Delimiter === */
    .log-session-delimiter {
      margin: 2rem 0 1.5rem;
      text-align: center;
      position: relative;
    }
    .log-session-delimiter::before {
      content: '';
      position: absolute;
      top: 50%;
      left: 0;
      right: 0;
      border-top: 1px dashed var(--border);
      z-index: 1;
    }
    .log-session-pill {
      position: relative;
      z-index: 2;
      display: inline-block;
      padding: 0.35rem 0.85rem;
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 9999px;
      font-size: 0.75rem;
      font-family: 'Fira Code', monospace;
      color: var(--fg);
      opacity: 0.85;
    }

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
    .log-search-wrapper input.with-tool-btn {
      padding-right: 2.75rem;
    }
    .log-search-tool-btn {
      position: absolute;
      right: 8px;
      top: 50%;
      transform: translateY(-50%);
      background: transparent;
      border: 1px solid var(--border);
      border-radius: 4px;
      color: var(--fg);
      opacity: 0.55;
      font-size: 11px;
      font-family: inherit;
      font-weight: 700;
      padding: 2px 6px;
      cursor: pointer;
      user-select: none;
      transition: all 0.15s ease-in-out;
    }
    .log-search-tool-btn:hover {
      opacity: 0.95;
      border-color: var(--info);
    }
    .log-search-tool-btn.active {
      opacity: 1;
      background: var(--info);
      color: #ffffff;
      border-color: var(--info);
    }
    .log-search-wrapper input:focus {
      border-color: var(--info);
    }

    .log-select {
      background: var(--bg);
      border: 1px solid var(--border);
      color: var(--fg);
      padding: 0.5rem 0.8rem;
      border-radius: 6px;
      font-size: 12px;
      font-family: 'Inter', sans-serif;
      font-weight: 500;
      cursor: pointer;
      outline: none;
      transition: all 0.15s ease;
    }
    .log-select:focus {
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
    .log-action-btn.active {
      background: var(--info);
      color: #ffffff;
      border-color: var(--info);
      opacity: 1;
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
    .log-val {
      color: var(--fg);
      cursor: pointer;
      border-bottom: 1px dotted rgba(255, 255, 255, 0.2);
      transition: color 0.15s ease, border-bottom-color 0.15s ease;
    }
    .log-val:hover {
      color: var(--info);
      border-bottom-color: var(--info);
    }
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

    mark.log-search-match {
      background: rgba(234, 179, 8, 0.35);
      color: inherit;
      padding: 0 2px;
      border-radius: 2px;
      font-weight: 600;
    }

    body.light-theme, .log-container.light-theme {
      --bg: #ffffff;
      --fg: #1f2937;
      --border: rgba(0,0,0,0.1);
      --header-bg: rgba(0,0,0,0.02);
      background-color: var(--bg);
      color: var(--fg);
    }
    body.light-theme .log-val, .log-container.light-theme .log-val {
      border-bottom-color: rgba(0, 0, 0, 0.25);
    }
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
    let activeLogger = '';
    let searchQuery = '';
    let isRegexMode = false;
    let searchRegex = null;
    let hasHighlights = false;
    let logIndex = null;

    function buildLogIndex() {
      const entries = document.querySelectorAll('.log-entry');
      const idx = [];
      for (let i = 0; i < entries.length; i++) {
        const el = entries[i];
        let level = '';
        if (el.classList.contains('log-trace')) level = 'trace';
        else if (el.classList.contains('log-debug')) level = 'debug';
        else if (el.classList.contains('log-info')) level = 'info';
        else if (el.classList.contains('log-warning')) level = 'warning';
        else if (el.classList.contains('log-error')) level = 'error';

        const loggerEl = el.querySelector('.log-logger');
        const logger = loggerEl ? (loggerEl.textContent || '').trim() : '';

        const text = el.textContent || '';
        idx.push({ el: el, level: level, logger: logger, text: text });
      }
      return idx;
    }

    function ensureIndex() {
      if (!logIndex) {
        logIndex = buildLogIndex();
      }
      return logIndex;
    }

    function escapeRegex(s) {
      let res = '';
      for (let i = 0; i < s.length; i++) {
        const c = s[i];
        if ('.*+?^(){}|[]\\\\'.indexOf(c) !== -1 || c === '\$') {
          res += '\\\\' + c;
        } else {
          res += c;
        }
      }
      return res;
    }

    function updateSearchMatcher(query) {
      if (!query) {
        searchRegex = null;
        return;
      }
      if (isRegexMode) {
        try {
          searchRegex = new RegExp(query, 'i');
        } catch (e) {
          searchRegex = null;
        }
      } else {
        searchRegex = new RegExp(escapeRegex(query), 'i');
      }
    }

    function clearHighlights(root) {
      if (!root) return;
      root.querySelectorAll('mark.log-search-match').forEach(mark => {
        const parent = mark.parentNode;
        if (parent) {
          parent.replaceChild(document.createTextNode(mark.textContent), mark);
          parent.normalize();
        }
      });
    }

    function highlightText(node, regex) {
      if (node.nodeType === 3) {
        const text = node.nodeValue;
        if (!text) return;
        regex.lastIndex = 0;
        const match = regex.exec(text);
        if (!match || match[0].length === 0) return;

        const matchIndex = match.index;
        const matchStr = match[0];

        const mark = document.createElement('mark');
        mark.className = 'log-search-match';
        mark.textContent = matchStr;

        const afterText = text.substring(matchIndex + matchStr.length);
        node.nodeValue = text.substring(0, matchIndex);

        const parent = node.parentNode;
        if (parent) {
          parent.insertBefore(mark, node.nextSibling);

          if (afterText.length > 0) {
            const afterNode = document.createTextNode(afterText);
            parent.insertBefore(afterNode, mark.nextSibling);
            highlightText(afterNode, regex);
          }
        }
      } else if (node.nodeType === 1) {
        const tag = node.tagName.toUpperCase();
        if (tag === 'BUTTON' || tag === 'SCRIPT' || tag === 'STYLE' || tag === 'INPUT' || tag === 'MARK') return;
        if (node.classList && node.classList.contains('log-copy-btn')) return;
        Array.from(node.childNodes).forEach(child => highlightText(child, regex));
      }
    }

    function applyFilters() {
      const index = ensureIndex();
      const counts = { trace: 0, debug: 0, info: 0, warning: 0, error: 0 };

      if (!searchRegex && hasHighlights) {
        clearHighlights(document.querySelector('.log-container') || document.body);
        hasHighlights = false;
      }

      for (let i = 0; i < index.length; i++) {
        const item = index[i];
        let show = true;

        if (item.level && !activeFilters[item.level]) {
          show = false;
        }

        if (show && activeLogger && item.logger !== activeLogger) {
          show = false;
        }

        if (show && searchRegex) {
          if (!searchRegex.test(item.text)) {
            show = false;
          }
        }

        item.el.style.display = show ? '' : 'none';

        if (show && searchRegex) {
          clearHighlights(item.el);
          highlightText(item.el, searchRegex);
          hasHighlights = true;
        }

        if (item.level) {
          let matchSearch = true;
          if (activeLogger && item.logger !== activeLogger) {
            matchSearch = false;
          }
          if (matchSearch && searchRegex && !searchRegex.test(item.text)) {
            matchSearch = false;
          }
          if (matchSearch) {
            counts[item.level]++;
          }
        }
      }

      for (const level in counts) {
        const countEl = document.getElementById('count-' + level);
        if (countEl) countEl.textContent = counts[level];
      }
    }

    function populateLoggerDropdown() {
      const select = document.getElementById('log-logger-select');
      if (!select) return;
      const index = ensureIndex();
      const loggers = new Set();
      for (let i = 0; i < index.length; i++) {
        if (index[i].logger) loggers.add(index[i].logger);
      }
      if (loggers.size <= 1) {
        select.style.display = 'none';
        return;
      }
      select.innerHTML = '<option value="">All Loggers (' + loggers.size + ')</option>';
      const sorted = Array.from(loggers).sort();
      for (let i = 0; i < sorted.length; i++) {
        const opt = document.createElement('option');
        opt.value = sorted[i];
        opt.textContent = sorted[i];
        select.appendChild(opt);
      }
      select.addEventListener('change', () => {
        activeLogger = select.value;
        applyFilters();
      });
    }

    document.querySelectorAll('.log-filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const level = btn.getAttribute('data-level');
        activeFilters[level] = !activeFilters[level];
        btn.classList.toggle('active', activeFilters[level]);
        applyFilters();
      });
    });

    const btnRegexToggle = document.getElementById('btn-regex-toggle');
    if (btnRegexToggle) {
      btnRegexToggle.addEventListener('click', () => {
        isRegexMode = !isRegexMode;
        btnRegexToggle.classList.toggle('active', isRegexMode);
        updateSearchMatcher(searchQuery);
        applyFilters();
      });
    }

    let debounceTimer = null;
    const searchInput = document.getElementById('log-search-input');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          searchQuery = e.target.value.trim();
          updateSearchMatcher(searchQuery);
          applyFilters();
        }, 120);
      });
    }

    // Context Value Correlation: Click on structured values to isolate stream
    document.addEventListener('click', (e) => {
      const valEl = e.target.closest('.log-val');
      if (valEl) {
        const text = (valEl.textContent || '').trim();
        if (text && searchInput) {
          searchInput.value = text;
          searchQuery = text;
          isRegexMode = false;
          if (btnRegexToggle) btnRegexToggle.classList.remove('active');
          updateSearchMatcher(searchQuery);
          applyFilters();
          searchInput.focus();
        }
      }
    });

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

    const btnThemeToggle = document.getElementById('btn-theme-toggle');
    if (btnThemeToggle) {
      btnThemeToggle.addEventListener('click', () => {
        const container = document.querySelector('.log-container') || document.body;
        const isLight = container.classList.toggle('light-theme');
        document.body.classList.toggle('light-theme', isLight);
        btnThemeToggle.textContent = isLight ? '🌙 Dark' : '☀️ Light';
        try {
          localStorage.setItem('logd-theme-pref', isLight ? 'light' : 'dark');
        } catch (_) {}
      });

      try {
        if (localStorage.getItem('logd-theme-pref') === 'light') {
          const container = document.querySelector('.log-container') || document.body;
          container.classList.add('light-theme');
          document.body.classList.add('light-theme');
          btnThemeToggle.textContent = '🌙 Dark';
        }
      } catch (_) {}
    }

    let isLiveFollow = false;
    const btnLiveFollow = document.getElementById('btn-live-follow');
    if (btnLiveFollow) {
      btnLiveFollow.addEventListener('click', () => {
        isLiveFollow = !isLiveFollow;
        btnLiveFollow.classList.toggle('active', isLiveFollow);
        btnLiveFollow.textContent = isLiveFollow ? '⚡ Live Follow [ON]' : '⚡ Live Follow [OFF]';
        if (isLiveFollow) {
          window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
        }
      });
    }

    function getVisibleLogData() {
      const visibleEntries = Array.from(document.querySelectorAll('.log-entry')).filter(
        e => e.style.display !== 'none'
      );
      return visibleEntries.map(entry => {
        let level = 'info';
        ['trace', 'debug', 'info', 'warning', 'error'].forEach(lvl => {
          if (entry.classList.contains('log-' + lvl)) level = lvl;
        });

        const clone = entry.cloneNode(true);
        clone.querySelectorAll('.log-copy-btn, button').forEach(b => b.remove());

        const tsEl = clone.querySelector('.log-timestamp');
        const timestamp = tsEl ? tsEl.textContent.trim() : '';

        const loggerEl = clone.querySelector('.log-logger');
        const logger = loggerEl ? loggerEl.textContent.trim() : '';

        const originEl = clone.querySelector('.log-origin');
        const origin = originEl ? originEl.textContent.trim() : '';

        const text = (clone.innerText || clone.textContent).trim();

        return {
          level: level,
          timestamp: timestamp,
          logger: logger,
          origin: origin,
          message: text
        };
      });
    }

    function triggerDownload(content, filename, mimeType) {
      const blob = new Blob([content], { type: mimeType });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }

    const btnExportJson = document.getElementById('btn-export-json');
    if (btnExportJson) {
      btnExportJson.addEventListener('click', () => {
        const data = getVisibleLogData();
        const jsonStr = JSON.stringify(data, null, 2);
        const now = new Date().toISOString().replace(/[:.]/g, '-');
        triggerDownload(jsonStr, 'logs_export_' + now + '.json', 'application/json');
      });
    }

    const btnExportCsv = document.getElementById('btn-export-csv');
    if (btnExportCsv) {
      btnExportCsv.addEventListener('click', () => {
        const data = getVisibleLogData();
        const headers = ['Level', 'Timestamp', 'Logger', 'Origin', 'Message'];
        const escapeCell = val => '"' + String(val || '').replace(/"/g, '""') + '"';
        const lines = [
          headers.map(escapeCell).join(','),
          ...data.map(d => [
            escapeCell(d.level),
            escapeCell(d.timestamp),
            escapeCell(d.logger),
            escapeCell(d.origin),
            escapeCell(d.message.replace(/[\\r\\n]+/g, ' '))
          ].join(','))
        ];
        const now = new Date().toISOString().replace(/[:.]/g, '-');
        triggerDownload(lines.join('\\r\\n'), 'logs_export_' + now + '.csv', 'text/csv;charset=utf-8;');
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

    populateLoggerDropdown();
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
