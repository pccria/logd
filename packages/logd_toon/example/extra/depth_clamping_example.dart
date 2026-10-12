import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';

Future<void> main() async {
  // Create a formatter that clamps object traversal at depth 3.
  final handler = ConsoleHandler(
    formatter: const ToonFormatter(
      dialect: ToonDialect.compact,
      maxDepth: 3,
    ),
  );

  Logger.configure('app.depth', handlers: [handler]);
  final logger = Logger.get('app.depth');

  final deepObject = {
    'level_1': {
      'level_2': {
        'level_3': {
          'level_4': 'This should be clamped as ...',
          'level_4_sibling': ['a', 'b'],
        }
      }
    }
  };

  print('--- Testing maxDepth = 3 ---');
  logger.info(
    'Deeply nested object',
    context: deepObject,
  );

  await handler.dispose();
}
