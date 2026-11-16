import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';

/// Custom structured exceptions representing enterprise failure modes.
class PostgreSqlDeadlockException implements Exception {
  PostgreSqlDeadlockException({
    required this.sqlState,
    required this.message,
    required this.activePid,
    required this.blockedPid,
    required this.relation,
  });

  final String sqlState; // 40P01
  final String message;
  final int activePid;
  final int blockedPid;
  final String relation;

  @override
  String toString() =>
      'PostgreSqlDeadlockException(SQLSTATE $sqlState): $message '
      '[PID $activePid waiting for ExclusiveLock on $relation '
      'held by PID $blockedPid]';
}

class CircuitBreakerOpenException implements Exception {
  CircuitBreakerOpenException({
    required this.serviceName,
    required this.failureRate,
    required this.cooldownSeconds,
  });

  final String serviceName;
  final double failureRate;
  final int cooldownSeconds;

  @override
  String toString() =>
      'CircuitBreakerOpenException: [$serviceName] Circuit tripped to OPEN '
      '(Failure rate ${failureRate.toStringAsFixed(1)}% '
      'exceeded 50.0% threshold). '
      'Requests rejected for $cooldownSeconds seconds cooldown.';
}

/// Simulated background fraud-detection worker running in a separate Isolate.
Future<void> _fraudDetectionIsolateWorker(final SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    if (message is Map<String, dynamic>) {
      final replyPort = message['replyTo'] as SendPort;
      final amount = message['amount'] as num;
      final velocity = message['velocity'] as int;

      // Simulate ML inference latency
      await Future<void>.delayed(const Duration(milliseconds: 35));

      final isHighRisk = amount > 5000 && velocity > 3;
      final riskScore = isHighRisk ? 0.942 : 0.018;

      replyPort.send({
        'riskScore': riskScore,
        'action': isHighRisk ? 'FLAG_FOR_REVIEW' : 'ALLOW',
        'mlLatencyMs': 34.8,
      });
    } else if (message == 'SHUTDOWN') {
      break;
    }
  }
}

void main() async {
  registerLogdHtmlSerializers();

  final outDir = Directory('logs/live_test');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  const reportPath = 'logs/live_test/enterprise_showcase.html';
  final reportFile = File(reportPath);
  if (reportFile.existsSync()) {
    reportFile.deleteSync();
  }

  print(
    '\x1B[1m\x1B[36m'
    '====================================================================\n'
    ' logd_html | Enterprise Microservices & Distributed Tracing Demo   \n'
    '===================================================================='
    '\x1B[0m',
  );

  const enterpriseView = HtmlView(
    title: 'Enterprise Settlement Mesh • Operational Diagnostics',
    header: DefaultHtmlHeader(
      logoText: 'LOGD // MESH TELEMETRY',
      subtitle:
          'Region: us-east-1 • Mesh: prod-settlement-mesh • Target: 99.999%',
      showDate: true,
    ),
    controlPanel: DefaultHtmlControlPanel.all(
      searchPlaceholder:
          'Filter by trace ID, user, tenant, error code, or regex...',
      extraActions: [
        HtmlActionButton(
          id: 'btn-isolate-incident',
          label: 'Filter Incident (trc-fin-99440)',
          onClickJs:
              "const inp = document.getElementById('log-search-input'); "
              "if (inp) { inp.value = 'trc-fin-99440'; "
              "inp.dispatchEvent(new Event('input')); }",
        ),
        HtmlActionButton(
          id: 'btn-clear-search',
          label: 'Reset Filters',
          onClickJs:
              "const inp = document.getElementById('log-search-input'); "
              "if (inp) { inp.value = ''; "
              "inp.dispatchEvent(new Event('input')); } "
              "const sel = document.getElementById('log-logger-select'); "
              "if (sel) { sel.value = ''; "
              "sel.dispatchEvent(new Event('change')); }",
        ),
        HtmlActionButton(
          id: 'btn-print',
          label: 'Export PDF / Print',
          onClickJs: 'window.print()',
        ),
      ],
    ),
    footer: DefaultHtmlFooter(
      attribution: 'logd Diagnostic IR Engine • Zero-CDN Self-Contained',
      customContent:
          '<span style="opacity: 0.6;"> '
          'Enterprise Observability Hub • Confidential Financial Telemetry '
          '</span>',
    ),
  );

  // Initialize background Isolate for ML Fraud Scorer
  final fraudWorkerReceivePort = ReceivePort();
  final fraudIsolate = await Isolate.spawn(
    _fraudDetectionIsolateWorker,
    fraudWorkerReceivePort.sendPort,
  );
  final fraudWorkerSendPort = await fraudWorkerReceivePort.first as SendPort;

  // =========================================================================
  // SESSION 1: Nominal Operations, Concurrency, and Cascading Outage
  // =========================================================================
  print(
    '\n\x1B[1m--> STAGE 1: Starting Session 1 (Production Ingress)...\x1B[0m',
  );

  final handler1 = HtmlFileHandler(
    path: reportPath,
    view: enterpriseView,
    fileMode: HtmlFileMode.appendSession,
  );

  final services = [
    'mesh.ingress.gateway',
    'auth.jwt.guard',
    'ledger.order.saga',
    'inventory.warehouse',
    'acquirer.stripe.gateway',
    'fraud.ml.scorer',
    'db.aurora.pool',
    'event.kafka.broker',
  ];

  for (final s in services) {
    Logger.configure(s, handlers: [handler1]);
  }

  final gateway = Logger.get('mesh.ingress.gateway');
  final auth = Logger.get('auth.jwt.guard');
  final saga = Logger.get('ledger.order.saga');
  final inventory = Logger.get('inventory.warehouse');
  final payment = Logger.get('acquirer.stripe.gateway');
  final fraud = Logger.get('fraud.ml.scorer');
  final db = Logger.get('db.aurora.pool');
  final kafka = Logger.get('event.kafka.broker');

  // --- Scenario 1.1: Golden Path Transaction (trc-fin-98101) ---
  print('  [Session 1] Processing Transaction 1: Golden (trc-fin-98101)...');

  gateway.info(
    'Inbound HTTPS POST /api/v3/transactions/settle received.',
    context: {
      'traceId': 'trc-fin-98101',
      'spanId': 'sp-001',
      'clientIp': '198.51.100.24',
      'tenantId': 'tenant-nordic-tech',
      'userId': 'usr-enterprise-401',
      'amountCents': 149999,
      'currency': 'EUR',
      'httpMethod': 'POST',
    },
  );

  auth.debug(
    'Verified RS256 JWT bearer signature against tenant JWKS cache.',
    context: {
      'traceId': 'trc-fin-98101',
      'spanId': 'sp-002',
      'parentId': 'sp-001',
      'tenantId': 'tenant-nordic-tech',
      'userId': 'usr-enterprise-401',
      'roles': ['FINANCIAL_SETTLEMENT_OFFICER'],
      'jwksCacheHit': true,
      'durationMs': 0.38,
    },
  );

  saga.info(
    'Initiated distributed settlement saga: saga-98101-alpha.',
    context: {
      'traceId': 'trc-fin-98101',
      'spanId': 'sp-003',
      'sagaId': 'saga-98101-alpha',
      'sagaStep': 'LOCK_INVENTORY',
      'status': 'STARTED',
    },
  );

  inventory.debug(
    'Acquired distributed Redis lock for inventory reservation.',
    context: {
      'traceId': 'trc-fin-98101',
      'spanId': 'sp-004',
      'lockKey': 'lock:sku-nordic-servers-48',
      'warehouse': 'arn:aws:wh:us-east-1:rack-12',
      'reservedQty': 2,
    },
  );

  // Invoke ML fraud check in background isolate
  final mlResponsePort = ReceivePort();
  fraudWorkerSendPort.send({
    'replyTo': mlResponsePort.sendPort,
    'amount': 1499.99,
    'velocity': 1,
  });
  final mlResult = await mlResponsePort.first as Map<String, dynamic>;

  fraud.info(
    'Asynchronous ML Fraud Inference complete: verdict ALLOW.',
    context: {
      'traceId': 'trc-fin-98101',
      'spanId': 'sp-005',
      'riskScore': mlResult['riskScore'],
      'verdict': mlResult['action'],
      'inferenceLatencyMs': mlResult['mlLatencyMs'],
      'modelId': 'xgb-fraud-v3.8.2',
    },
  );

  payment.info(
    'Dispatched charge authorization to Stripe Acquirer API.',
    context: {
      'traceId': 'trc-fin-98101',
      'spanId': 'sp-006',
      'idempotencyKey': 'idem-fin-98101-v1',
      'provider': 'stripe',
      'endpoint': 'https://api.stripe.com/v1/charges',
      'cardBrand': 'VISA',
      'last4': '4242',
    },
  );

  db.debug(
    'Committed ledger double-entry journal transaction.',
    context: {
      'traceId': 'trc-fin-98101',
      'spanId': 'sp-007',
      'isolationLevel': 'READ_COMMITTED',
      'journalId': 'jrn-2026-11-98101',
      'debitAccount': 'ACC-AR-EUROPE',
      'creditAccount': 'ACC-MERCHANT-NORDIC',
      'queryDurationMs': 1.84,
    },
  );

  kafka.info(
    'Published settlement event to topic "settlement.cleared.v1".',
    context: {
      'traceId': 'trc-fin-98101',
      'spanId': 'sp-008',
      'topic': 'settlement.cleared.v1',
      'partition': 3,
      'offset': 1049281,
    },
  );

  gateway.info(
    'HTTP 201 Created sent to client (End-to-End Latency: 42.1ms).',
    context: {
      'traceId': 'trc-fin-98101',
      'spanId': 'sp-009',
      'statusCode': 201,
      'e2eDurationMs': 42.1,
      'tenantId': 'tenant-nordic-tech',
      'userId': 'usr-enterprise-401',
    },
  );

  // --- Scenario 1.2: Concurrent Batch Reconciliation (trc-reconcile-8812) ---
  print('  [Session 1] Emitting Concurrent Batch (trc-reconcile-8812)...');

  saga.info(
    'Scheduled automated end-of-window reconciliation cycle triggered.',
    context: {
      'traceId': 'trc-reconcile-8812',
      'batchJobId': 'batch-rec-hourly-04',
      'recordsScanned': 14200,
      'discrepancies': 0,
    },
  );

  db.info(
    'Bulk ledger checkpoint snapshot saved to Aurora replica.',
    context: {
      'traceId': 'trc-reconcile-8812',
      'snapshotId': 'snap-aurora-20261116',
      'snapshotSizeBytes': 48192004,
      'durationMs': 184.2,
    },
  );

  // --- Scenario 1.3: Cascading Failure Incident (trc-fin-99440) ---
  print('  [Session 1] Simulating Cascading Failure (trc-fin-99440)...');

  gateway
    ..warning(
      'High ingress queue depth detected: 8,420 pending requests.',
      context: {
        'queueDepth': 8420,
        'maxThreshold': 5000,
        'saturationPercent': '94.8%',
      },
    )
    ..info(
      'Inbound HTTPS POST /api/v3/transactions/settle received.',
      context: {
        'traceId': 'trc-fin-99440',
        'spanId': 'sp-inc-01',
        'clientIp': '203.0.113.88',
        'tenantId': 'tenant-global-pay',
        'userId': 'usr-retail-88',
        'amountCents': 899000,
        'currency': 'USD',
      },
    );

  auth.info(
    'Authenticated tenant-global-pay for high-value clearance.',
    context: {
      'traceId': 'trc-fin-99440',
      'tenantId': 'tenant-global-pay',
      'userId': 'usr-retail-88',
    },
  );

  saga.info(
    'Initiated settlement saga: saga-99440-incident.',
    context: {
      'traceId': 'trc-fin-99440',
      'sagaId': 'saga-99440-incident',
      'status': 'AWAITING_PAYMENT',
    },
  );

  // Failure Step 1: Upstream Stripe Gateway times out
  payment
    ..warning(
      'Attempt 1/3: Socket timeout while connecting to Stripe API.',
      context: {
        'traceId': 'trc-fin-99440',
        'attempt': 1,
        'maxAttempts': 3,
        'timeoutSeconds': 2.5,
        'errorCode': 'ERR_SOCKET_TIMEOUT',
      },
    )
    ..warning(
      'Attempt 2/3: Upstream returned HTTP 504 Gateway Timeout.',
      context: {
        'traceId': 'trc-fin-99440',
        'attempt': 2,
        'statusCode': 504,
        'backoffMs': 1200,
        'errorCode': 'ERR_GATEWAY_TIMEOUT',
      },
    );

  try {
    throw CircuitBreakerOpenException(
      serviceName: 'acquirer.stripe.gateway',
      failureRate: 78.4,
      cooldownSeconds: 30,
    );
  } catch (err, stack) {
    payment.error(
      'Circuit breaker tripped to OPEN state! Failure limit reached.',
      error: err,
      stackTrace: stack,
      context: {
        'traceId': 'trc-fin-99440',
        'attempt': 3,
        'circuitState': 'OPEN',
        'consecutiveFailures': 5,
        'errorCode': 'ERR_CIRCUIT_OPEN',
      },
    );
  }

  // Failure Step 2: Database concurrency deadlock
  try {
    throw PostgreSqlDeadlockException(
      sqlState: '40P01',
      message: 'deadlock detected between PID 4102 and PID 4109',
      activePid: 4102,
      blockedPid: 4109,
      relation: 'ledger_journal',
    );
  } catch (err, stack) {
    db.error(
      'Transaction rolled back due to row-level concurrency deadlock.',
      error: err,
      stackTrace: stack,
      context: {
        'traceId': 'trc-fin-99440',
        'sqlState': '40P01',
        'errorCode': 'ERR_PG_DEADLOCK_40P01',
        'activePid': 4102,
        'blockedPid': 4109,
        'tableName': 'ledger_journal',
      },
    );
  }

  // Failure Step 3: Saga Compensation Rollback
  saga.warning(
    'Triggering automated Saga Compensation Rollback for transaction.',
    context: {
      'traceId': 'trc-fin-99440',
      'sagaId': 'saga-99440-incident',
      'compensationStatus': 'ROLLING_BACK',
      'reason': 'PAYMENT_ACQUIRER_CIRCUIT_OPEN',
    },
  );

  inventory.info(
    'Compensated: Released reserved stock back to active inventory.',
    context: {
      'traceId': 'trc-fin-99440',
      'warehouse': 'arn:aws:wh:us-east-1:rack-12',
      'action': 'RELEASE_LOCK_AND_INVENTORY',
    },
  );

  kafka.warning(
    'Published compensation notice to topic "settlement.aborted.v1".',
    context: {
      'traceId': 'trc-fin-99440',
      'topic': 'settlement.aborted.v1',
      'sagaStatus': 'COMPENSATED_AND_ABORTED',
    },
  );

  gateway.error(
    'Inbound request failed with HTTP 503 Service Unavailable.',
    context: {
      'traceId': 'trc-fin-99440',
      'statusCode': 503,
      'retryAfterSeconds': 30,
      'tenantId': 'tenant-global-pay',
      'userId': 'usr-retail-88',
      'errorCode': 'ERR_CIRCUIT_OPEN',
    },
  );

  // Gracefully finalize Session 1
  print('  [Session 1] Flushing logs and simulating pod restart...');
  await Logger.flush();
  await handler1.dispose();

  // Clean up fraud worker isolate
  fraudWorkerSendPort.send('SHUTDOWN');
  fraudWorkerReceivePort.close();
  fraudIsolate.kill(priority: Isolate.immediate);

  await Future<void>.delayed(const Duration(milliseconds: 300));

  // =========================================================================
  // SESSION 2: Self-Healing, Cluster Resumption, and Trace Recovery
  // =========================================================================
  print(
    '\n\x1B[1m--> STAGE 2: Session 2 (Resumption & Post-Mortem)...\x1B[0m',
  );

  final handler2 = HtmlFileHandler(
    path: reportPath,
    view: enterpriseView,
    fileMode: HtmlFileMode.appendSession,
  );

  for (final s in services) {
    Logger.configure(s, handlers: [handler2]);
  }

  gateway.info(
    'Pod container registered with Service Mesh discovery.',
    context: {
      'podName': 'mesh-worker-04b',
      'node': 'ip-10-0-14-99.ec2.internal',
      'kubeVersion': 'v1.31.2',
      'resumptionState': 'CLEAN_BOOT',
    },
  );

  payment
    ..info(
      'Circuit breaker cooldown expired; transitioned to HALF_OPEN.',
      context: {
        'service': 'acquirer.stripe.gateway',
        'circuitState': 'HALF_OPEN',
        'probeRequestLimit': 1,
      },
    )
    ..info(
      'Canary synthetic probe to Stripe Acquirer succeeded in 38.4ms.',
      context: {
        'circuitState': 'CLOSED',
        'probeLatencyMs': 38.4,
        'status': 'HEALTHY',
      },
    );

  db.info(
    'PostgreSQL connection pool re-established with healthy replicas.',
    context: {
      'poolSize': 32,
      'idleConnections': 30,
      'deadlockResolverActive': true,
    },
  );

  // Reconcile the orphaned transaction from Session 1!
  saga.info(
    'Automated saga reconciliation completed for orphaned trace.',
    context: {
      'traceId': 'trc-fin-99440',
      'sagaId': 'saga-99440-incident',
      'auditStatus': 'RECONCILED_CLEAN',
      'refundProcessed': false,
      'chargeStatus': 'NOT_CHARGED',
      'tenantId': 'tenant-global-pay',
      'userId': 'usr-retail-88',
    },
  );

  gateway.info(
    'Cluster operational health restored to 100%. P99 Latency: 12.8ms.',
    context: {
      'healthStatus': 'OPTIMAL',
      'activeNodes': 12,
      'meshUptime': '99.999%',
    },
  );

  print('  [Session 2] Flushing logs and finalizing document...');
  await Logger.flush();
  await handler2.dispose();

  // =========================================================================
  // STAGE 3: Document Integrity Validation
  // =========================================================================
  print(
    '\n\x1B[1m--> STAGE 3: Validating Single Shell HTML Integrity...\x1B[0m',
  );

  final file = File(reportPath);
  final html = file.readAsStringSync();

  final doctypeMatches = '<!DOCTYPE html>'.allMatches(html).length;
  final headMatches = '<head>'.allMatches(html).length;
  final bodyMatches = '<body'.allMatches(html).length;
  final htmlCloseMatches = '</html>'.allMatches(html).length;
  final delimiterMatches =
      '<div class="log-session-delimiter">'.allMatches(html).length;
  final footerMatches =
      '<footer class="log-page-footer">'.allMatches(html).length;

  print('  File size: ${file.lengthSync()} bytes');
  print('  <!DOCTYPE html>: $doctypeMatches (Expected: 1)');
  print('  <head>:          $headMatches (Expected: 1)');
  print('  <body>:          $bodyMatches (Expected: 1)');
  print('  </html>:         $htmlCloseMatches (Expected: 1)');
  print('  Delimiters:      $delimiterMatches (Expected: 1)');
  print('  Footers:         $footerMatches (Expected: 1)');

  if (doctypeMatches == 1 &&
      headMatches == 1 &&
      bodyMatches == 1 &&
      htmlCloseMatches == 1 &&
      delimiterMatches == 1 &&
      footerMatches == 1) {
    print(
      '\n\x1B[32m✓ ALL ENTERPRISE HTML INTEGRITY INVARIANTS SATISFIED!\x1B[0m',
    );
  } else {
    print('\n\x1B[31m✗ INTEGRITY FAILURE!\x1B[0m');
    exit(1);
  }
}
