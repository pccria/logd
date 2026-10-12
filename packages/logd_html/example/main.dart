import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';

void main() async {
  // Required when using logd_html in an asynchronous isolate environment
  registerLogdHtmlSerializers();

  // Configure a logger to write beautiful HTML logs in the background
  Logger.configure(
    'html_demo',
    handlers: [
      HtmlFileHandler.async(
        path: 'logs/app_logs.html',
        title: 'My Application Logs',
      ),
    ],
  );

  final logger = Logger.get('html_demo')
    ..info(
      'Application started successfully.',
      context: {'version': '1.0.0', 'environment': 'production'},
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
  await Future.delayed(const Duration(milliseconds: 100));
  print('HTML logs generated at: logs/app_logs.html');
}
