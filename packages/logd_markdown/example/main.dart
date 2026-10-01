import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';

void main() async {
  // Always register serializers when using isolates or async handlers
  registerLogdMarkdownSerializers();

  // Configure a logger to write GitHub-Flavored Markdown logs in the background
  final handler = MarkdownFileHandler.async(
    path: 'logs/app_logs.md',
  );

  Logger.configure('md_demo', handlers: [handler]);

  final logger = Logger.get('md_demo')
    ..info(
      'Application started successfully',
      context: const {'version': '1.0.0', 'environment': 'production'},
    );

  try {
    throw StateError('Simulated database connection failure');
  } catch (e, stackTrace) {
    logger.error(
      'Failed to connect to database',
      error: e,
      stackTrace: stackTrace,
    );
  }

  // Dispose the handler to flush the isolate cleanly
  await handler.dispose();
  print('Markdown logs generated cleanly at logs/app_logs.md');
}
