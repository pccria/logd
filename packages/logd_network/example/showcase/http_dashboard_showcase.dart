import 'dart:async';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

/// Demonstrates using the high-level pre-wired [HttpDashboardHandler] DX preset.
Future<void> main() async {
  print(
    '\x1B[1m\x1B[96mlogd_network\x1B[0m | HttpDashboardHandler DX Showcase',
  );
  print(
    '\x1B[2m─────────────────────────────────────────────────────────────\x1B[0m',
  );

  // Single-line pre-wired setup with custom title
  final dashboard = HttpDashboardHandler(
    port: 8088,
    title: 'Fleet Observability & Telemetry Center',
    bufferCapacity: 500,
  );

  Logger.configure('app', handlers: [dashboard]);
  final authLogger = Logger.get('app.auth');
  final billingLogger = Logger.get('app.billing');
  final orderLogger = Logger.get('app.orders');
  final dbLogger = Logger.get('app.db');

  print('\x1B[1m\x1B[92m[Dashboard Started via HttpDashboardHandler]\x1B[0m');
  print('👉 Open browser: \x1B[1;34mhttp://localhost:8088\x1B[0m');
  print('Press Ctrl+C to terminate.');
  print(
    '\x1B[2m─────────────────────────────────────────────────────────────\x1B[0m',
  );

  // Initial seed entries
  authLogger.info(
    'User admin authenticated from 192.168.1.5',
    context: {'role': 'superadmin', 'method': 'MFA_TOTP'},
  );
  billingLogger.info(
    'Enterprise subscription renewed',
    context: {'plan': 'Enterprise Tier', 'amount': '\$4,500/mo'},
  );
  billingLogger.warning(
    'Stripe webhook processing delayed (>1200ms)',
    context: {'latencyMs': 1240, 'attempt': 2},
  );
  dbLogger.debug('Connection pool initialized (16/16 connections healthy)');

  try {
    throw StateError(
      'Payment gateway circuit tripped: downstream bank API 503',
    );
  } catch (err, stack) {
    orderLogger.error(
      'Checkout transaction #TX-9821 failed',
      error: err,
      stackTrace: stack,
      context: {
        'txId': 'TX-9821',
        'userId': 'usr_4921',
        'items': 3,
        'diagnostics': Stopwatch()
          ..start(), // Non-serializable context object verified
      },
    );
  }

  int step = 0;
  Timer.periodic(const Duration(milliseconds: 1500), (final _) {
    step++;
    final cycle = step % 6;
    switch (cycle) {
      case 0:
        authLogger.info(
          'OAuth2 bearer token refreshed',
          context: {'expiresIn': '3600s', 'clientId': 'mobile-app-v2'},
        );
      case 1:
        dbLogger.debug('Slow query detected on orders table (142ms)');
      case 2:
        billingLogger.info(
          'Invoice generated and dispatched',
          context: {'invoiceId': 'INV-${1000 + step}', 'status': 'PAID'},
        );
      case 3:
        orderLogger.info(
          'Order #ORD-${5000 + step} placed successfully',
          context: {'customer': 'acme-corp', 'total': '\$289.50'},
        );
      case 4:
        billingLogger.warning(
          'Rate limit threshold approaching 85%',
          context: {'currentRps': 850, 'maxRps': 1000},
        );
      case 5:
        try {
          throw TimeoutException(
            'Read replica replication lag exceeded 5000ms',
          );
        } catch (e, s) {
          dbLogger.error(
            'Database replication alert',
            error: e,
            stackTrace: s,
            context: {'replica': 'us-east-db-2', 'lagMs': 5210},
          );
        }
    }
  });
}
