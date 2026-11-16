import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';

void main() async {
  registerLogdHtmlSerializers();

  final outDir = Directory('logs/modular_demo');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  // =========================================================================
  // Scenario 1: Standalone View with Custom Branding and Custom Action Buttons
  // =========================================================================
  const standaloneView = HtmlView(
    title: 'ACME Cloud Telemetry Hub',
    header: DefaultHtmlHeader(
      logoText: 'ACME // CLOUD',
      subtitle: 'Cluster: eu-west-1 • Node: worker-04 • Release: v2.4.1',
      showDate: true,
    ),
    controlPanel: DefaultHtmlControlPanel.all(
      searchPlaceholder: 'Search messages, trace IDs, errors, payloads...',
      extraActions: [
        HtmlActionButton(
          id: 'btn-alert-metrics',
          label: 'System Status: OK',
          onClickJs:
              "alert('All cluster services operational. Latency p99: 14ms.')",
        ),
        HtmlActionButton(
          id: 'btn-print',
          label: 'Print Report',
          onClickJs: 'window.print()',
        ),
      ],
    ),
    footer: DefaultHtmlFooter(
      attribution: 'ACME Observability Platform',
      customContent:
          '<span style="color: #64748b; font-size: 11px;"> • Confidential Internal Telemetry • Retention: 30 Days</span>',
    ),
  );

  Logger.configure(
    'acme.payments',
    handlers: [
      HtmlFileHandler.async(
        path: 'logs/modular_demo/standalone_report.html',
        view: standaloneView,
      ),
    ],
  );

  // =========================================================================
  // Scenario 2: Embedded Fragment View (Ready for Web Dashboards & Portals)
  // =========================================================================
  // When embedding within an existing web app, admin portal, or dashboard,
  // HtmlView.embedded generates only the inner container and scoped styles,
  // without conflicting <html>, <head>, or <body> wrappers.
  const embeddedView = HtmlView.embedded(
    controlPanel: DefaultHtmlControlPanel.all(
      searchPlaceholder: 'Filter live dashboard feed...',
      extraActions: [
        HtmlActionButton(
          id: 'btn-dash-clear',
          label: 'Quick Filter Warnings',
          onClickJs:
              "document.querySelectorAll('.log-filter-btn').forEach("
              "b => { if (b.dataset.level !== 'warning' && "
              "b.dataset.level !== 'error') b.click(); })",
        ),
      ],
    ),
  );

  Logger.configure(
    'acme.dashboard',
    handlers: [
      HtmlFileHandler.async(
        path: 'logs/modular_demo/embedded_widget.html',
        view: embeddedView,
      ),
    ],
  );

  // Emit rich telemetry across all 5 levels for standalone report
  Logger.get('acme.payments')
    ..trace(
      'Inbound TLS socket connection established.',
      context: {'peerIp': '198.51.100.42', 'cipher': 'TLS_AES_256_GCM_SHA384'},
    )
    ..debug(
      'Cache lookup for tenant account profile: HIT in L1 memory cache.',
      context: {'tenantId': 'tenant-9082', 'lookupMs': 0.42},
    )
    ..info(
      'Payment authorization request accepted for processing.',
      context: {
        'transactionId': 'txn-87241',
        'amount': 249.50,
        'currency': 'USD',
        'merchant': 'Stripe Connect',
      },
    )
    ..warning(
      'Transient latency spike detected on external credit gateway.',
      context: {
        'gateway': 'stripe-eu',
        'retryAttempt': 1,
        'latencyMs': 840,
        'thresholdMs': 500,
      },
    )
    ..error(
      'Failed to finalize settlement batch for merchant.',
      error: StateError('Gateway connection reset by peer during 2PC commit'),
      stackTrace: StackTrace.current,
      context: {
        'batchId': 'batch-20261116-01',
        'affectedTxnCount': 14,
        'actionRequired': 'Manual reconciliation queued',
      },
    );

  // Emit rich telemetry for dashboard embedded widget
  Logger.get('acme.dashboard')
    ..trace('Heartbeat ping sent to central coordinator.')
    ..debug('Worker threads pool utilization: 4/16 active workers.')
    ..info(
      'Live dashboard synchronization event completed.',
      context: {'activeUsers': 1420, 'cpuLoad': '34%', 'memUsage': '1.2 GB'},
    )
    ..warning(
      'Memory utilization exceeding soft threshold (78%).',
      context: {'heapAllocatedMb': 1240, 'maxLimitMb': 1536},
    )
    ..error(
      'Ingestion buffer backpressure detected on consumer #3.',
      error: Exception('Queue capacity 10000 exceeded: current 10002'),
      stackTrace: StackTrace.current,
      context: {'consumer': 'sqs-ingest', 'droppedEvents': 2},
    );

  // Flush and drain all isolate buffers cleanly
  await Logger.shutdown();

  // Create a simulated SaaS portal hosting the embedded fragment
  final embeddedHtml = File(
    'logs/modular_demo/embedded_widget.html',
  ).readAsStringSync();
  final portalHtml =
      '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ACME Operations Portal (Embedded Logd View Demo)</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=Fira+Code:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --portal-bg: #0b0f19;
      --portal-surface: #111827;
      --portal-border: rgba(255,255,255,0.08);
      --portal-text: #f3f4f6;
      --portal-text-muted: #9ca3af;
      --portal-primary: #3b82f6;
      --portal-accent: #10b981;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--portal-bg);
      color: var(--portal-text);
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    header.portal-nav {
      background: var(--portal-surface);
      border-bottom: 1px solid var(--portal-border);
      padding: 0.85rem 2rem;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .portal-brand {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      font-weight: 700;
      font-size: 1.1rem;
      letter-spacing: -0.02em;
    }
    .portal-badge {
      background: rgba(59, 130, 246, 0.15);
      color: #60a5fa;
      font-size: 0.75rem;
      padding: 0.2rem 0.5rem;
      border-radius: 9999px;
      font-weight: 600;
    }
    .portal-links {
      display: flex;
      gap: 1.5rem;
      font-size: 0.875rem;
      color: var(--portal-text-muted);
    }
    .portal-links a { color: inherit; text-decoration: none; }
    .portal-links a.active { color: var(--portal-text); font-weight: 600; }
    main.portal-content {
      flex: 1;
      padding: 2rem;
      max-width: 1400px;
      width: 100%;
      margin: 0 auto;
      display: flex;
      flex-direction: column;
      gap: 1.5rem;
    }
    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 1rem;
    }
    .kpi-card {
      background: var(--portal-surface);
      border: 1px solid var(--portal-border);
      border-radius: 12px;
      padding: 1.25rem;
    }
    .kpi-title { font-size: 0.8rem; color: var(--portal-text-muted); text-transform: uppercase; font-weight: 600; letter-spacing: 0.05em; }
    .kpi-val { font-size: 1.75rem; font-weight: 700; margin-top: 0.35rem; }
    .kpi-change { font-size: 0.75rem; margin-top: 0.25rem; color: var(--portal-accent); }
    .widget-container {
      background: var(--portal-surface);
      border: 1px solid var(--portal-border);
      border-radius: 12px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }
    .widget-header {
      padding: 1rem 1.5rem;
      border-bottom: 1px solid var(--portal-border);
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .widget-title { font-weight: 600; font-size: 1rem; }
    .widget-subtitle { font-size: 0.8rem; color: var(--portal-text-muted); }
    .widget-body {
      padding: 0;
    }
  </style>
</head>
<body>
  <header class="portal-nav">
    <div class="portal-brand">
      <span>⚡ ACME OPERATIONS</span>
      <span class="portal-badge">PROD CLUSTER</span>
    </div>
    <nav class="portal-links">
      <a href="#">Overview</a>
      <a href="#" class="active">Telemetry</a>
      <a href="#">Deployments</a>
      <a href="#">Security</a>
    </nav>
  </header>
  <main class="portal-content">
    <div class="kpi-grid">
      <div class="kpi-card">
        <div class="kpi-title">Active Gateway Workers</div>
        <div class="kpi-val">16 / 16</div>
        <div class="kpi-change">● 100% Health Status</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-title">P99 Payment Latency</div>
        <div class="kpi-val">18.4 ms</div>
        <div class="kpi-change">↓ 2.1 ms vs 1hr ago</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-title">Settlement Volume</div>
        <div class="kpi-val">\$1.42M</div>
        <div class="kpi-change">↑ 14.8% throughput</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-title">Error Rate</div>
        <div class="kpi-val">0.02%</div>
        <div class="kpi-change" style="color: #f59e0b;">▲ 1 alert requires review</div>
      </div>
    </div>

    <!-- Live Telemetry Widget hosting the modular embedded HtmlView -->
    <div class="widget-container">
      <div class="widget-header">
        <div>
          <div class="widget-title">Live Service Telemetry (Embedded Logd Widget)</div>
          <div class="widget-subtitle">Rendered via HtmlView.embedded into host portal DOM</div>
        </div>
        <span class="portal-badge">Live Socket Stream</span>
      </div>
      <div class="widget-body">
$embeddedHtml
      </div>
    </div>
  </main>
</body>
</html>
''';

  File('logs/modular_demo/dashboard_portal.html').writeAsStringSync(portalHtml);

  print(
    'Generated modular standalone report: logs/modular_demo/standalone_report.html',
  );
  print(
    'Generated modular embedded fragment: logs/modular_demo/embedded_widget.html',
  );
  print('Generated host portal demo: logs/modular_demo/dashboard_portal.html');
}
