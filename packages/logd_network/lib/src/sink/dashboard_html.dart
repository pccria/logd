library;

/// The HTML source code for the Logd Viewer Dashboard.
const String dashboardHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Logd Viewer Dashboard</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Outfit:wght@400;500;600;700&family=Fira+Code:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0b0f19;
      --panel-bg: rgba(20, 26, 45, 0.6);
      --border-color: rgba(255, 255, 255, 0.08);
      --text: #f8f9fa;
      --text-muted: #8e9bb3;
      --primary: #50fa7b;
      --primary-glow: rgba(80, 250, 123, 0.15);
      
      --debug: #6272a4;
      --info: #8be9fd;
      --warning: #ffb86c;
      --error: #ff5555;
      
      --font-sans: 'Inter', sans-serif;
      --font-display: 'Outfit', sans-serif;
      --font-mono: 'Fira Code', monospace;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      background-color: var(--bg);
      color: var(--text);
      font-family: var(--font-sans);
      overflow: hidden;
      height: 100vh;
      display: flex;
      flex-direction: column;
    }

    header {
      background: var(--panel-bg);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--border-color);
      padding: 1rem 2rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
      z-index: 10;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 0.75rem;
    }

    .brand h1 {
      font-family: var(--font-display);
      font-size: 1.5rem;
      font-weight: 700;
      letter-spacing: -0.025em;
      background: linear-gradient(135deg, #ffffff 30%, var(--primary) 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .status-badge {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      font-size: 0.8rem;
      font-weight: 500;
      color: var(--text-muted);
      background: rgba(255, 255, 255, 0.04);
      padding: 0.25rem 0.75rem;
      border-radius: 100px;
      border: 1px solid var(--border-color);
    }

    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background-color: var(--error);
      box-shadow: 0 0 8px var(--error);
      transition: all 0.3s ease;
    }

    .status-dot.connected {
      background-color: var(--primary);
      box-shadow: 0 0 8px var(--primary);
    }

    .dashboard-layout {
      flex: 1;
      display: flex;
      overflow: hidden;
    }

    .control-panel {
      width: 320px;
      border-right: 1px solid var(--border-color);
      background: rgba(13, 17, 30, 0.8);
      backdrop-filter: blur(8px);
      padding: 1.5rem;
      display: flex;
      flex-direction: column;
      gap: 1.5rem;
      overflow-y: auto;
    }

    .section-title {
      font-family: var(--font-display);
      font-size: 0.85rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--text-muted);
      margin-bottom: 0.75rem;
    }

    .search-box {
      position: relative;
    }

    .search-box input {
      width: 100%;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border-color);
      padding: 0.75rem 1rem;
      border-radius: 8px;
      color: var(--text);
      font-family: var(--font-sans);
      font-size: 0.9rem;
      outline: none;
      transition: all 0.2s ease;
    }

    .search-box input:focus {
      border-color: var(--primary);
      box-shadow: 0 0 10px var(--primary-glow);
    }

    .filter-group {
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
    }

    .checkbox-btn {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0.65rem 1rem;
      background: rgba(255, 255, 255, 0.02);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      cursor: pointer;
      font-size: 0.9rem;
      font-weight: 500;
      transition: all 0.2s ease;
    }

    .checkbox-btn:hover {
      background: rgba(255, 255, 255, 0.05);
    }

    .checkbox-btn.active {
      background: rgba(255, 255, 255, 0.04);
      border-color: var(--color-target);
    }

    .checkbox-btn input {
      display: none;
    }

    .checkbox-btn .indicator {
      width: 12px;
      height: 12px;
      border-radius: 3px;
      border: 2px solid var(--text-muted);
      transition: all 0.2s ease;
    }

    .checkbox-btn.active .indicator {
      background: var(--color-target);
      border-color: var(--color-target);
    }

    .stats-card {
      background: rgba(255, 255, 255, 0.02);
      border: 1px solid var(--border-color);
      padding: 1rem;
      border-radius: 8px;
      display: flex;
      flex-direction: column;
      gap: 0.25rem;
    }

    .stats-card .value {
      font-family: var(--font-display);
      font-size: 2rem;
      font-weight: 700;
      color: var(--text);
    }

    .stats-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0.75rem;
    }

    .console-container {
      flex: 1;
      display: flex;
      flex-direction: column;
      background: #060913;
      overflow: hidden;
    }

    .console-header {
      background: rgba(13, 17, 30, 0.5);
      border-bottom: 1px solid var(--border-color);
      padding: 0.75rem 1.5rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .console-actions {
      display: flex;
      gap: 0.75rem;
    }

    .btn {
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border-color);
      padding: 0.5rem 1rem;
      border-radius: 6px;
      color: var(--text);
      font-size: 0.85rem;
      font-weight: 500;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 0.5rem;
      transition: all 0.2s ease;
    }

    .btn:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: rgba(255, 255, 255, 0.15);
    }

    .btn.primary {
      background: var(--primary);
      border-color: var(--primary);
      color: #0b0f19;
    }

    .btn.primary:hover {
      opacity: 0.9;
    }

    .console-output {
      flex: 1;
      padding: 1rem 1.5rem;
      overflow-y: auto;
      overflow-x: hidden;
      font-family: var(--font-mono);
      font-size: 0.875rem;
      line-height: 1.6;
      display: flex;
      flex-direction: column;
      gap: 0.35rem;
      tab-size: 16;
      -moz-tab-size: 16;
      position: relative;
      min-width: 0;
      width: 100%;
    }

    /* Flex item constraints to enforce proper CSS text wrapping */
    .dashboard-layout,
    .console-container,
    .console-output,
    .log-row,
    .log-entry,
    .log-main,
    .log-content,
    .log-decorated-content,
    .log-line,
    pre {
      min-width: 0 !important;
      max-width: 100% !important;
      box-sizing: border-box !important;
    }

    /* Default: All text line & pre elements wrap text cleanly */
    .log-content,
    .log-line,
    .details-val,
    pre {
      white-space: pre-wrap !important;
      word-break: break-word !important;
      overflow-wrap: anywhere !important;
      font-family: var(--font-mono);
      tab-size: 16;
      -moz-tab-size: 16;
    }

    .console-output .log-decorated {
      display: flex !important;
      align-items: flex-start !important;
      gap: 0.5rem !important;
      min-width: 0 !important;
      width: 100% !important;
      box-sizing: border-box !important;
    }

    .console-output .log-decorated-content {
      flex: 1 !important;
      min-width: 0 !important;
      width: 100% !important;
      box-sizing: border-box !important;
    }

    /* Option to turn OFF wrapping */
    .console-output.no-wrap .log-content,
    .console-output.no-wrap .log-line,
    .console-output.no-wrap .log-decorated-content,
    .console-output.no-wrap .details-val,
    .console-output.no-wrap pre {
      white-space: pre !important;
      word-break: normal !important;
      overflow-wrap: normal !important;
    }

    .btn.active {
      background: var(--primary-glow);
      border-color: var(--primary);
      color: var(--primary);
    }

    .toon-sticky-header {
      position: sticky;
      top: 0;
      z-index: 30;
      background: rgba(13, 17, 30, 0.95);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      border-bottom: 1px solid rgba(80, 250, 123, 0.3);
      padding: 0.6rem 1.25rem;
      font-family: var(--font-mono);
      font-size: 0.825rem;
      color: var(--primary);
      display: flex;
      align-items: center;
      gap: 0.75rem;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);
      user-select: none;
      flex-wrap: wrap;
    }

    .toon-header-tag {
      font-family: var(--font-display);
      font-weight: 700;
      letter-spacing: 0.05em;
      background: rgba(80, 250, 123, 0.15);
      border: 1px solid rgba(80, 250, 123, 0.35);
      padding: 0.2rem 0.6rem;
      border-radius: 6px;
      color: var(--primary);
    }

    .toon-header-cols {
      display: flex;
      gap: 0.35rem;
      flex-wrap: wrap;
      align-items: center;
    }

    .toon-col-pill {
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border-color);
      padding: 0.15rem 0.45rem;
      border-radius: 4px;
      color: var(--text-muted);
      font-size: 0.75rem;
      font-weight: 500;
    }

    .log-row {
      display: flex;
      flex-direction: column;
      border-radius: 6px;
      padding: 0.5rem 0.75rem;
      background: rgba(255, 255, 255, 0.02);
      border: 1px solid var(--border-color);
      transition: background 0.15s ease;
      width: 100%;
    }

    .log-row:hover {
      background: rgba(255, 255, 255, 0.05);
    }

    .log-main {
      display: flex;
      flex-direction: column;
      gap: 0.25rem;
      cursor: pointer;
      width: 100%;
    }

    .log-meta-info {
      display: flex;
      gap: 0.75rem;
      color: var(--text-muted);
      font-size: 0.8rem;
      white-space: nowrap;
      user-select: none;
      border-bottom: 1px dashed rgba(255, 255, 255, 0.04);
      padding-bottom: 0.25rem;
      margin-bottom: 0.25rem;
    }

    .log-content {
      flex: 1;
      white-space: pre;
      overflow-x: visible;
      font-family: var(--font-mono);
      tab-size: 16;
      -moz-tab-size: 16;
    }

    .log-details {
      margin-top: 0.5rem;
      padding: 0.75rem 1rem;
      background: rgba(0, 0, 0, 0.2);
      border-left: 3px solid var(--border-color);
      border-radius: 0 4px 4px 0;
      display: none;
      flex-direction: column;
      gap: 0.5rem;
    }

    .log-row.expanded .log-details {
      display: flex;
    }

    .details-section {
      display: flex;
      flex-direction: column;
      gap: 0.25rem;
    }

    .details-label {
      font-size: 0.75rem;
      color: var(--text-muted);
      text-transform: uppercase;
      font-weight: 600;
    }

    .details-val {
      font-size: 0.8rem;
      white-space: pre-wrap;
      word-break: break-all;
    }

    .details-val.stack {
      color: var(--text-muted);
    }

    .details-val.context {
      color: var(--info);
    }

    .level-debug { color: var(--debug); }
    .level-info { color: var(--info); }
    .level-warning { color: var(--warning); }
    .level-error { color: var(--error); }
    .panel-resizer {
      width: 6px;
      background: var(--border-color);
      cursor: col-resize;
      user-select: none;
      transition: background 0.2s ease;
      z-index: 40;
      flex-shrink: 0;
    }

    .panel-resizer:hover, .panel-resizer.active {
      background: var(--primary);
      box-shadow: 0 0 10px var(--primary);
    }

    .console-output .log-entry {
      margin-bottom: 0.25rem !important;
      background: rgba(255, 255, 255, 0.02) !important;
      border: 1px solid var(--border-color) !important;
      border-radius: 6px !important;
      transition: background 0.15s ease !important;
      padding: 0.5rem 0.75rem !important;
      position: relative !important;
    }

    .console-output .log-entry:hover {
      background: rgba(255, 255, 255, 0.05) !important;
    }

    .log-copy-btn {
      position: absolute !important;
      top: 0.4rem !important;
      right: 0.5rem !important;
      background: rgba(255, 255, 255, 0.05) !important;
      border: 1px solid var(--border-color) !important;
      color: var(--text-muted) !important;
      opacity: 0 !important;
      cursor: pointer !important;
      padding: 0.25rem !important;
      width: 24px !important;
      height: 24px !important;
      border-radius: 4px !important;
      transition: all 0.15s ease !important;
      display: inline-flex !important;
      align-items: center !important;
      justify-content: center !important;
      z-index: 10 !important;
    }

    .log-entry:hover .log-copy-btn {
      opacity: 0.7 !important;
    }

    .log-copy-btn:hover {
      opacity: 1 !important;
      background: rgba(255, 255, 255, 0.15) !important;
      color: var(--primary) !important;
      border-color: var(--primary) !important;
    }

    .log-copy-btn svg {
      width: 13px !important;
      height: 13px !important;
      pointer-events: none !important;
      stroke: currentColor !important;
    }
  </style>
</head>
<body>

  <header>
    <div class="brand">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M12 2L2 7L12 12L22 7L12 2Z" stroke="#50fa7b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        <path d="M2 17L12 22L22 17" stroke="#50fa7b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        <path d="M2 12L12 17L22 12" stroke="#50fa7b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
      <h1>logd Dashboard</h1>
    </div>
    <div class="status-badge">
      <div id="statusDot" class="status-dot"></div>
      <span id="statusText">Disconnected</span>
    </div>
  </header>

  <div class="dashboard-layout">
    <aside class="control-panel">
      <div>
        <h3 class="section-title">Search</h3>
        <div class="search-box">
          <input type="text" id="searchInput" placeholder="Search message, tags, origin...">
        </div>
      </div>

      <div>
        <h3 class="section-title">Log Levels</h3>
        <div class="filter-group">
          <label class="checkbox-btn active" style="--color-target: var(--error)" id="lblError">
            <span>Error</span>
            <span class="indicator"></span>
            <input type="checkbox" id="chkError" checked>
          </label>
          <label class="checkbox-btn active" style="--color-target: var(--warning)" id="lblWarning">
            <span>Warning</span>
            <span class="indicator"></span>
            <input type="checkbox" id="chkWarning" checked>
          </label>
          <label class="checkbox-btn active" style="--color-target: var(--info)" id="lblInfo">
            <span>Info</span>
            <span class="indicator"></span>
            <input type="checkbox" id="chkInfo" checked>
          </label>
          <label class="checkbox-btn active" style="--color-target: var(--debug)" id="lblDebug">
            <span>Debug</span>
            <span class="indicator"></span>
            <input type="checkbox" id="chkDebug" checked>
          </label>
        </div>
      </div>

      <div>
        <h3 class="section-title">Statistics</h3>
        <div class="stats-grid">
          <div class="stats-card">
            <span class="section-title" style="font-size:0.7rem; margin:0;">Total</span>
            <span class="value" id="statTotal">0</span>
          </div>
          <div class="stats-card">
            <span class="section-title" style="font-size:0.7rem; margin:0; color:var(--error);">Errors</span>
            <span class="value" id="statErrors" style="color:var(--error);">0</span>
          </div>
        </div>
      </div>
    </aside>

    <div class="panel-resizer" id="panelResizer" title="Drag to resize sidebar"></div>

    <main class="console-container">
      <div class="console-header">
        <span id="logCountLabel" style="font-size: 0.9rem; color: var(--text-muted);">Showing 0 logs</span>
        <div class="console-actions">
          <button class="btn" id="btnWrap" title="Toggle line wrapping for long messages">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M3 12h15a3 3 0 1 1 0 6h-4M3 18h7"/><polyline points="16 16 14 18 16 20"/></svg>
            Wrap Lines
          </button>
          <button class="btn" id="btnPause">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect></svg>
            Pause
          </button>
          <button class="btn" id="btnClear">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>
            Clear
          </button>
        </div>
      </div>

      <div class="console-output" id="consoleOutput"></div>
    </main>
  </div>

  <script>
    const statusDot = document.getElementById('statusDot');
    const statusText = document.getElementById('statusText');
    const consoleOutput = document.getElementById('consoleOutput');
    const searchInput = document.getElementById('searchInput');
    const logCountLabel = document.getElementById('logCountLabel');
    const btnPause = document.getElementById('btnPause');
    const btnClear = document.getElementById('btnClear');
    const btnWrap = document.getElementById('btnWrap');

    // Filter elements
    const chkError = document.getElementById('chkError');
    const chkWarning = document.getElementById('chkWarning');
    const chkInfo = document.getElementById('chkInfo');
    const chkDebug = document.getElementById('chkDebug');

    const lblError = document.getElementById('lblError');
    const lblWarning = document.getElementById('lblWarning');
    const lblInfo = document.getElementById('lblInfo');
    const lblDebug = document.getElementById('lblDebug');

    // Stats
    const statTotal = document.getElementById('statTotal');
    const statErrors = document.getElementById('statErrors');

    let allLogs = [];
    let isPaused = false;
    let ws = null;
    let totalCount = 0;
    let errorCount = 0;

    // Line Wrapping State (Always enabled by default)
    let isWrapped = true;

    function updateWrapState() {
      if (isWrapped) {
        consoleOutput.classList.remove('no-wrap');
        btnWrap.classList.add('active');
      } else {
        consoleOutput.classList.add('no-wrap');
        btnWrap.classList.remove('active');
      }
    }

    btnWrap.addEventListener('click', () => {
      isWrapped = !isWrapped;
      localStorage.setItem('logd_wrap_lines', isWrapped);
      updateWrapState();
    });

    updateWrapState();

    // Draggable Panel Resizer Logic
    const panelResizer = document.getElementById('panelResizer');
    const controlPanel = document.querySelector('.control-panel');
    let isResizing = false;

    const savedWidth = localStorage.getItem('logd_sidebar_width');
    if (savedWidth) {
      controlPanel.style.width = savedWidth + 'px';
    }

    panelResizer.addEventListener('mousedown', (e) => {
      isResizing = true;
      panelResizer.classList.add('active');
      document.body.style.cursor = 'col-resize';
      document.body.style.userSelect = 'none';
    });

    document.addEventListener('mousemove', (e) => {
      if (!isResizing) return;
      const newWidth = Math.max(200, Math.min(e.clientX, window.innerWidth - 300));
      controlPanel.style.width = newWidth + 'px';
      localStorage.setItem('logd_sidebar_width', newWidth);
    });

    document.addEventListener('mouseup', () => {
      if (isResizing) {
        isResizing = false;
        panelResizer.classList.remove('active');
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
      }
    });

    // Connect WebSocket
    function connect() {
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = `\${protocol}//\${window.location.host}/ws`;
      
      ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        statusDot.className = 'status-dot connected';
        statusText.textContent = 'Connected';
      };

      ws.onclose = () => {
        statusDot.className = 'status-dot';
        statusText.textContent = 'Disconnected';
        setTimeout(connect, 3000); // Reconnect loop
      };

      ws.onmessage = (event) => {
        if (isPaused) return;
        try {
          const logPayload = JSON.parse(event.data);
          addLog(logPayload);
        } catch (e) {
          console.error("Failed to parse log event", e);
        }
      };
    }

    // Set up check-btn styles
    const setupFilterBtn = (btn, checkbox) => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        checkbox.checked = !checkbox.checked;
        if (checkbox.checked) {
          btn.classList.add('active');
        } else {
          btn.classList.remove('active');
        }
        applyFilters();
      });
    };

    setupFilterBtn(lblError, chkError);
    setupFilterBtn(lblWarning, chkWarning);
    setupFilterBtn(lblInfo, chkInfo);
    setupFilterBtn(lblDebug, chkDebug);

    searchInput.addEventListener('input', applyFilters);

    btnClear.addEventListener('click', () => {
      allLogs = [];
      consoleOutput.innerHTML = '';
      totalCount = 0;
      errorCount = 0;
      updateStats();
    });

    btnPause.addEventListener('click', () => {
      isPaused = !isPaused;
      if (isPaused) {
        btnPause.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg> Resume';
        btnPause.classList.add('primary');
      } else {
        btnPause.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect></svg> Pause';
        btnPause.classList.remove('primary');
      }
    });

    function escapeHtml(str) {
      if (str === null || str === undefined) return '';
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }

    function ansiToHtml(text) {
      if (!text) return '';
      let html = text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
      
      const ansiMap = {
        '0': 'font-weight: normal; color: var(--text); background: transparent; text-decoration: none;',
        '1': 'font-weight: bold;',
        '3': 'font-style: italic;',
        '4': 'text-decoration: underline;',
        '30': 'color: #1e1e24;',
        '31': 'color: #ff5555;',
        '32': 'color: #50fa7b;',
        '33': 'color: #ffb86c;',
        '34': 'color: #bd93f9;',
        '35': 'color: #ff79c6;',
        '36': 'color: #8be9fd;',
        '37': 'color: #f8f8f2;',
        '90': 'color: #6272a4;',
        '91': 'color: #ff6e6e;',
        '92': 'color: #69ff94;',
        '93': 'color: #ffffa5;',
        '94': 'color: #d6acff;',
        '95': 'color: #ff92df;',
        '96': 'color: #a4ffff;',
        '97': 'color: #ffffff;',
      };
      
      let openSpans = 0;
      html = html.replace(/\\x1B\\[([0-9;]+)m/g, (match, codes) => {
        let style = '';
        const split = codes.split(';');
        for (const code of split) {
          if (ansiMap[code]) {
            style += ansiMap[code];
          }
        }
        
        let result = '';
        while (openSpans > 0) {
          result += '</span>';
          openSpans--;
        }
        if (style) {
          result += `<span style="\${style}">`;
          openSpans++;
        }
        return result;
      });
      
      while (openSpans > 0) {
        html += '</span>';
        openSpans--;
      }
      return html;
    }

    function addLog(payload) {
      totalCount++;
      if (payload.entry.level === 'error') {
        errorCount++;
      }
      updateStats();

      allLogs.push(payload);
      
      // Limit to 1000 logs in DOM for memory
      if (allLogs.length > 1000) {
        allLogs.shift();
      }

      renderLogRow(payload, true);
    }

    function renderLogRow(payload, appendToBottom) {
      if (payload.toon && !document.getElementById('toonHeaderBar')) {
        const headerBar = document.createElement('div');
        headerBar.id = 'toonHeaderBar';
        headerBar.className = 'toon-sticky-header';
        const colPills = payload.toon.columns ? payload.toon.columns.map(c => `<span class="toon-col-pill">\${escapeHtml(c)}</span>`).join('') : '';
        headerBar.innerHTML = `<span class="toon-header-tag">\${escapeHtml(payload.toon.array)}[]</span><div class="toon-header-cols">\${colPills}</div>`;
        consoleOutput.insertBefore(headerBar, consoleOutput.firstChild);
      }

      const isHtml = !!payload.isHtml;
      const isToon = !!payload.toon || (payload.formatted && payload.formatted.includes('log-toon'));

      if (isHtml) {
        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = payload.formatted.trim();
        const htmlElement = tempDiv.firstElementChild || tempDiv;
        htmlElement.dataset.level = payload.entry.level;
        htmlElement.dataset.message = payload.entry.message;
        htmlElement.dataset.logger = payload.entry.loggerName;
        htmlElement.dataset.origin = payload.entry.origin;

        if (!shouldShow(payload.entry)) {
          htmlElement.style.display = 'none';
        }

        if (appendToBottom) {
          consoleOutput.appendChild(htmlElement);
          consoleOutput.scrollTop = consoleOutput.scrollHeight;
          while (consoleOutput.children.length > 1000) {
            consoleOutput.removeChild(consoleOutput.firstChild);
          }
        } else {
          consoleOutput.appendChild(htmlElement);
        }
        return;
      }

      const safeLevel = escapeHtml(payload.entry.level);
      const row = document.createElement('div');
      row.className = `log-row level-\${safeLevel}\${isToon ? ' toon-mode' : ''}`;
      row.dataset.level = payload.entry.level;
      row.dataset.message = payload.entry.message;
      row.dataset.logger = payload.entry.loggerName;
      row.dataset.origin = payload.entry.origin;

      const main = document.createElement('div');
      main.className = 'log-main';

      if (!isToon) {
        const meta = document.createElement('div');
        meta.className = 'log-meta-info';
        const safeUpperLevel = escapeHtml(payload.entry.level ? payload.entry.level.toUpperCase() : '');
        meta.innerHTML = `<span>\${escapeHtml(payload.entry.timestamp)}</span><span class="level-\${safeLevel}">[&nbsp;\${safeUpperLevel}&nbsp;]</span><span>\${escapeHtml(payload.entry.loggerName)}</span>`;
        main.appendChild(meta);
      }

      const content = document.createElement('div');
      content.className = 'log-content';
      content.innerHTML = ansiToHtml(payload.formatted || payload.entry.message);

      main.appendChild(content);
      row.appendChild(main);

      // Expandable details
      const hasError = !!payload.entry.error;
      const hasStack = !!payload.entry.stackTrace;
      const hasContext = payload.entry.context && Object.keys(payload.entry.context).length > 0;

      if (hasError || hasStack || hasContext) {
        const details = document.createElement('div');
        details.className = 'log-details';

        if (hasError) {
          details.innerHTML += `<div class="details-section"><span class="details-label">Error</span><span class="details-val">\${escapeHtml(payload.entry.error)}</span></div>`;
        }
        if (hasContext) {
          details.innerHTML += `<div class="details-section"><span class="details-label">Context</span><span class="details-val context">\${escapeHtml(JSON.stringify(payload.entry.context, null, 2))}</span></div>`;
        }
        if (hasStack) {
          details.innerHTML += `<div class="details-section"><span class="details-label">Stack Trace</span><span class="details-val stack">\${escapeHtml(payload.entry.stackTrace)}</span></div>`;
        }

        row.appendChild(details);

        main.addEventListener('click', () => {
          row.classList.toggle('expanded');
        });
      }

      // Check filters immediately
      if (!shouldShow(payload.entry)) {
        row.style.display = 'none';
      }

      if (appendToBottom) {
        consoleOutput.appendChild(row);
        consoleOutput.scrollTop = consoleOutput.scrollHeight;
        
        // Match 1000 DOM children limit
        while (consoleOutput.children.length > 1000) {
          consoleOutput.removeChild(consoleOutput.firstChild);
        }
      } else {
        consoleOutput.appendChild(row);
      }
    }

    function shouldShow(entry) {
      const search = searchInput.value.toLowerCase();
      
      // Level check
      if (entry.level === 'error' && !chkError.checked) return false;
      if (entry.level === 'warning' && !chkWarning.checked) return false;
      if (entry.level === 'info' && !chkInfo.checked) return false;
      if (entry.level === 'debug' && !chkDebug.checked) return false;

      // Search check
      if (search) {
        const matchesMsg = entry.message.toLowerCase().includes(search);
        const matchesLogger = entry.loggerName.toLowerCase().includes(search);
        const matchesOrigin = entry.origin.toLowerCase().includes(search);
        const matchesContext = entry.context ? JSON.stringify(entry.context).toLowerCase().includes(search) : false;
        
        if (!matchesMsg && !matchesLogger && !matchesOrigin && !matchesContext) {
          return false;
        }
      }

      return true;
    }

    function applyFilters() {
      const rows = consoleOutput.children;
      let visibleCount = 0;

      for (let i = 0; i < rows.length; i++) {
        const row = rows[i];
        const entry = {
          level: row.dataset.level,
          message: row.dataset.message,
          loggerName: row.dataset.logger,
          origin: row.dataset.origin
        };
        
        if (shouldShow(entry)) {
          row.style.style = '';
          row.style.display = 'flex';
          visibleCount++;
        } else {
          row.style.display = 'none';
        }
      }

      logCountLabel.textContent = `Showing \${visibleCount} of \${allLogs.length} logs`;
    }

    function updateStats() {
      statTotal.textContent = totalCount;
      statErrors.textContent = errorCount;
      logCountLabel.textContent = `Showing \${consoleOutput.querySelectorAll('.log-row[style*="display: flex"]').length || consoleOutput.children.length} of \${allLogs.length} logs`;
    }

    // Init
    connect();
  </script>
</body>
</html>
''';
