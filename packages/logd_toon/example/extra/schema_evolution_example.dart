import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';

Future<void> main() async {
  final handler = ConsoleHandler(
    formatter: const ToonFormatter(
      dialect: ToonDialect.strict,
      explicitSchema: true,
      arrayName: 'evolution_logs',
    ),
  );

  Logger.configure('app.evolution', handlers: [handler]);
  final logger = Logger.get('app.evolution');

  print('--- Schema is locked on the first log ---');
  logger.info(
    'Initial log',
    context: {
      'user_id': 123,
      'action': 'login',
    },
  );

  print('\n--- Subsequent log WITH MISSING keys (should print \\N) ---');
  logger.info(
    'Missing action',
    context: {
      'user_id': 124,
      // 'action' is intentionally omitted
    },
  );

  print('\n--- Subsequent log WITH EXTRA keys (should ignore new keys) ---');
  logger.info(
    'Extra keys',
    context: {
      'user_id': 125,
      'action': 'logout',
      'ip_address': '192.168.1.1', // This wasn't in the initial schema!
    },
  );

  await handler.dispose();
}
