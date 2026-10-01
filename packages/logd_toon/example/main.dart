import 'dart:async';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';

Future<void> main() async {
  // 1. Strict Dialect (Machine Ingestion)
  // This handler writes to a file in strict mode with an explicit schema header.
  final fileHandler = ToonFileHandler(
    path: 'logs/strict_example.toon',
    formatter: const ToonFormatter(
      dialect: ToonDialect.strict,
      explicitSchema: true,
      arrayName: 'production_logs',
    ),
  );

  // 2. Compact Dialect (Terminal/Human Readability)
  // This handler writes to the console in compact mode without explicit nulls.
  final consoleHandler = ConsoleHandler(
    formatter: const ToonFormatter(
      dialect: ToonDialect.compact,
      arrayName: 'debug_logs',
    ),
  );

  // Configure the global logger instance
  Logger.configure(
    'app',
    handlers: [consoleHandler, fileHandler],
  );

  final logger = Logger.get('app.billing');

  // Example A: Basic primitive logging
  logger.info('Billing service initialized successfully.');

  // Example B: Logging complex types natively (DateTime, Duration)
  logger.debug(
    'Processing transaction batch',
    context: {
      'batch_id': 'TXN-9942',
      'started_at': DateTime.now(),
      'timeout': const Duration(seconds: 30),
      'retry_count': 0,
    },
  );

  // Example C: Deeply nested objects and lists
  logger.info(
    'User profile updated',
    context: {
      'user_id': 8472,
      'changes': {
        'preferences': {
          'notifications': ['email', 'push'],
          'theme': 'dark',
        },
        'metadata': {
          'last_login': DateTime.now().toIso8601String(),
          'ip': '192.168.1.1',
        },
      },
    },
  );

  // Example D: Multi-line strings and errors (Escaping demonstration)
  try {
    throw TimeoutException('Upstream payment gateway did not respond');
  } catch (e, stack) {
    logger.error(
      'Payment processing failed',
      error: e,
      stackTrace: stack,
      context: {
        'gateway': 'stripe',
        'amount': 49.99,
      },
    );
  }

  // Ensure resources are flushed and closed properly
  await fileHandler.dispose();
  await consoleHandler.dispose();
}
