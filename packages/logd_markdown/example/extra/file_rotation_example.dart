import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';

void main() async {
  registerLogdMarkdownSerializers();

  final handler = MarkdownFileHandler.async(
    path: 'logs/rotating_logs.md',
    fileRotation: SizeRotation(
      maxSize: '10 KB',
      backupCount: 3,
      compress: true,
    ),
  );

  Logger.configure('md_rotation', handlers: [handler]);
  final logger = Logger.get('md_rotation');

  for (var i = 0; i < 50; i++) {
    logger.info('Heavy markdown entry #${i + 1}');
  }

  await handler.dispose();
  print('Rotating Markdown logs generated at logs/rotating_logs.md');
}
