import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';

void main() async {
  // Required for async isolate setup
  registerLogdHtmlSerializers();

  Logger.configure(
    'rotation_logger',
    handlers: [
      HtmlFileHandler.async(
        path: 'logs/rotating_logs.html',
        title: 'Rotating HTML Logs',
        // Rotate when the HTML file reaches 10 KB, keeping up to 3 backups
        fileRotation: SizeRotation(
          maxSize: '10 KB',
          backupCount: 3,
          compress: true, // .gz backups
        ),
      ),
    ],
  );

  final logger = Logger.get('rotation_logger');

  // Spam logs to quickly exceed 10 KB and trigger rotation
  for (int i = 0; i < 500; i++) {
    logger.info('Simulating heavy HTML log entry #${i + 1}');
  }

  await Future.delayed(const Duration(milliseconds: 100));
  print('Logs rotated successfully in logs/');
}
