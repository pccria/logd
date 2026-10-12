import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';

Future<void> main() async {
  // 1. Generate some structured log data
  final handler = ToonFileHandler(
    path: 'logs/llm_context.toon',
    formatter: const ToonFormatter(
      dialect: ToonDialect.strict,
      explicitSchema: true,
      arrayName: 'context_logs',
    ),
  );

  Logger.configure('app.llm', handlers: [handler]);
  final logger = Logger.get('app.llm');

  logger.info(
    'User initiated search query',
    context: {'query': 'best restaurants near me'},
  );
  logger.info(
    'Database returned 3 results',
    context: {
      'results': ['r1', 'r2', 'r3']
    },
  );

  await handler.dispose();

  // Ensure file writes complete before reading
  await Future.delayed(const Duration(milliseconds: 100));

  // 2. Read the file back and extract the schema preamble
  final bytes = await File('logs/llm_context.toon').readAsBytes();

  // Extracting the preamble allows us to inject the schema definition to an LLM
  // so it understands the structure of the data it is about to read without needing
  // to feed it thousands of lines of repeating object keys.
  final schema = ToonEncoder.extractPreamble(bytes);

  print('--- Extracted LLM Schema Context ---');
  print(schema);
  print('------------------------------------');
}
