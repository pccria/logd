import 'dart:async';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';

void main() async {
  registerLogdHtmlSerializers();

  final outDir = Directory('logs/live_test');
  if (outDir.existsSync()) {
    outDir.deleteSync(recursive: true);
  }
  outDir.createSync(recursive: true);

  const reportPath = 'logs/live_test/interactive_report.html';

  print('=== STEP 1: Running Session 1 (Initial Application Startup) ===');

  const fullView = HtmlView(
    title: 'Logd Telemetry & Diagnostics Center',
    header: DefaultHtmlHeader(
      logoText: 'LOGD // PROD',
      subtitle: 'Cluster: us-east-2 • Pod: worker-core-8 • Release: v0.2.0',
      showDate: true,
    ),
    controlPanel: DefaultHtmlControlPanel.all(
      searchPlaceholder: 'Search messages, traces, errors, tags, or values...',
      extraActions: [
        HtmlActionButton(
          id: 'btn-cluster-health',
          label: 'Health: Healthy (99.98%)',
          onClickJs:
              "alert('All 5 subsystems reported optimal health metrics.')",
        ),
        HtmlActionButton(
          id: 'btn-print-report',
          label: 'Print',
          onClickJs: 'window.print()',
        ),
      ],
    ),
    footer: DefaultHtmlFooter(
      attribution: 'Logd Diagnostic Platform',
      customContent:
          '<span style="opacity: 0.6;"> • Logd v0.2.0 Engine • Zero DOM-Cloning Index</span>',
    ),
  );

  // Configure Session 1 with multiple subsystems
  final handlerSession1 = HtmlFileHandler(
    path: reportPath,
    view: fullView,
    fileMode: HtmlFileMode.appendSession,
  );

  final authLogger = Logger.get('auth.service');
  final httpLogger = Logger.get('http.gateway');
  final dbLogger = Logger.get('database.pool');
  final billingLogger = Logger.get('billing.worker');
  final cacheLogger = Logger.get('cache.redis');

  for (final l in [
    'auth.service',
    'http.gateway',
    'database.pool',
    'billing.worker',
    'cache.redis',
  ]) {
    Logger.configure(l, handlers: [handlerSession1]);
  }

  // Session 1 Logs: Rich structured telemetry across all levels
  httpLogger.info(
    'Inbound HTTPS request received: POST /api/v2/checkout/process',
    context: {
      'requestId': 'req-9812',
      'traceId': 'trc-alpha-99',
      'method': 'POST',
      'clientIp': '192.168.1.45',
      'durationMs': 1.2,
    },
  );

  authLogger.debug(
    'JWT token signature validated successfully via RSA-SHA256.',
    context: {
      'userId': 'usr-42',
      'role': 'enterprise-admin',
      'scope': 'billing:write',
      'traceId': 'trc-alpha-99',
    },
  );

  cacheLogger.trace(
    'L2 Redis cache hit for customer account preferences.',
    context: {
      'key': 'tenant:t-8841:profile',
      'hitRatio': '94.2%',
      'latencyMs': 0.38,
      'traceId': 'trc-alpha-99',
    },
  );

  dbLogger.info(
    'Executing transaction: RESERVE_INVENTORY_AND_LOCK_ROW',
    context: {
      'sku': 'PROD-SKU-8819',
      'qty': 3,
      'isolation': 'READ_COMMITTED',
      'warehouseId': 'wh-ohio-2',
      'traceId': 'trc-alpha-99',
      'requestId': 'req-9812',
    },
  );

  billingLogger.info(
    'Dispatched charge authorization to payment gateway.',
    context: {
      'provider': 'Stripe',
      'amountCents': 14999,
      'currency': 'USD',
      'traceId': 'trc-alpha-99',
      'requestId': 'req-9812',
    },
  );

  // Independent background job
  dbLogger.warning(
    'Database connection pool acquisition latency exceeded threshold (420ms).',
    context: {
      'poolUtilization': '88.5%',
      'activeConnections': 42,
      'maxPoolSize': 48,
      'waitQueueLength': 6,
    },
  );

  try {
    throw const SocketException(
      'TLS handshake timeout while connecting to downstream webhook endpoint',
      address: null,
      port: 8443,
    );
  } catch (err, stack) {
    httpLogger.error(
      'Downstream webhook notification dispatch failed.',
      error: err,
      stackTrace: stack,
      context: {
        'endpoint': 'https://hooks.external-partner.com/events',
        'retryCount': 3,
        'traceId': 'trc-beta-77',
        'requestId': 'req-3104',
      },
    );
  }

  // Gracefully close Session 1
  print('Closing Session 1 (simulating process shutdown)...');
  await Logger.flush();
  await handlerSession1.dispose();

  // Give a small pause to simulate restart gap
  await Future<void>.delayed(const Duration(milliseconds: 300));

  print(
    '\n=== STEP 2: Running Session 2 (Application Restart & Resumption) ===',
  );

  // Session 2: Starts with appendSession to the same file
  final handlerSession2 = HtmlFileHandler(
    path: reportPath,
    view: fullView,
    fileMode: HtmlFileMode.appendSession,
  );

  for (final l in [
    'auth.service',
    'http.gateway',
    'database.pool',
    'billing.worker',
    'cache.redis',
  ]) {
    Logger.configure(l, handlers: [handlerSession2]);
  }

  httpLogger.info(
    'Daemon process re-initialized after system update.',
    context: {'workerPid': pid, 'environment': 'production'},
  );

  dbLogger.info(
    'Database pool reconnected and primed with 10 standby connections.',
    context: {'healthy': true, 'poolSize': 10},
  );

  // Continue the exact trace from Session 1 to verify correlation!
  billingLogger.info(
    'Payment settlement confirmation received from gateway for previous order.',
    context: {
      'status': 'SETTLED',
      'traceId': 'trc-alpha-99',
      'userId': 'usr-42',
      'feeCents': 435,
    },
  );

  httpLogger.info(
    'HTTP Gateway processing new incoming batch.',
    context: {
      'requestId': 'req-9999',
      'traceId': 'trc-gamma-12',
      'userId': 'usr-108',
      'method': 'GET',
      'path': '/api/v2/analytics/summary',
    },
  );

  print('Closing Session 2...');
  await Logger.flush();
  await handlerSession2.dispose();

  print('\n=== STEP 3: Verifying HTML Document Integrity on Disk ===');
  final file = File(reportPath);
  final htmlContent = file.readAsStringSync();

  final doctypeCount = '<!DOCTYPE html>'.allMatches(htmlContent).length;
  final htmlCloseCount = '</html>'.allMatches(htmlContent).length;
  final delimiterCount = '<div class="log-session-delimiter">'
      .allMatches(htmlContent)
      .length;
  final footerCount = '<footer class="log-page-footer">'
      .allMatches(htmlContent)
      .length;

  print('Report File Size: ${file.lengthSync()} bytes');
  print('DOCTYPE count: $doctypeCount (Expected: 1)');
  print('</html> count: $htmlCloseCount (Expected: 1)');
  print('Session Delimiters: $delimiterCount (Expected: 1)');
  print('Footers: $footerCount (Expected: 1)');
  final footers = [
    for (final m in '<footer class="log-page-footer">'.allMatches(htmlContent))
      m.start,
  ];
  final delimiters = [
    for (final m in '<div class="log-session-delimiter">'.allMatches(
      htmlContent,
    ))
      m.start,
  ];
  final closes = [for (final m in '</html>'.allMatches(htmlContent)) m.start];
  print('htmlClose matches at: $closes');
  print('footers at: $footers');
  print('delimiters at: $delimiters');

  if (doctypeCount == 1 &&
      htmlCloseCount == 1 &&
      delimiterCount == 1 &&
      footerCount == 1) {
    print('\n✓ ALL DOCUMENT INTEGRITY CHECKS PASSED PERFECTLY!');
  } else {
    print('\n✗ INTEGRITY FAILURE!');
    exit(1);
  }
}
