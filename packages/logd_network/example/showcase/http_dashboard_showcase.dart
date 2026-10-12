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

  // Single-line pre-wired setup
  final dashboard = HttpDashboardHandler(
    port: 8088,
    title: 'Production Observability Dashboard',
    bufferCapacity: 500,
  );

  Logger.configure('app.services', handlers: [dashboard]);
  final authLogger = Logger.get('app.services.auth');
  final billingLogger = Logger.get('app.services.billing');

  print('\x1B[1m\x1B[92m[Dashboard Started via HttpDashboardHandler]\x1B[0m');
  print('👉 Open browser: \x1B[4mhttp://localhost:8088\x1B[24m');
  print('Press Ctrl+C to terminate.');
  print(
    '\x1B[2m─────────────────────────────────────────────────────────────\x1B[0m',
  );

  authLogger.info('User admin logged in from 192.168.1.5');
  await Future<void>.delayed(const Duration(milliseconds: 500));
  billingLogger.info(
    'Subscription renewed',
    context: {'plan': 'Pro Enterprise'},
  );
  await Future<void>.delayed(const Duration(milliseconds: 500));
  billingLogger.warning('Stripe webhook processing delayed (>1200ms)');

  int step = 0;
  Timer.periodic(const Duration(seconds: 2), (final _) {
    step++;
    if (step % 3 == 0) {
      billingLogger.info(
        'Invoice generated',
        context: {'invoiceId': 'INV-$step'},
      );
    } else {
      authLogger.info(
        'Session refresh heartbeat',
        context: {'activeUsers': 42 + step},
      );
    }
  });
}
