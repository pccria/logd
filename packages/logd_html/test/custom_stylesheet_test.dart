import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:test/test.dart';

class CustomStylesheet extends DefaultHtmlStylesheet {
  const CustomStylesheet();

  @override
  String buildCss(final LogTheme theme) => '''
${super.buildCss(theme)}
body {
  font-family: 'Fira Code', monospace;
}
''';
}

void main() {
  group('CustomStylesheet', () {
    final tempDir =
        Directory.systemTemp.createTempSync('logd_html_custom_css_');
    final logFile = File('${tempDir.path}/custom.html');

    tearDownAll(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'generates HTML page with custom stylesheet override in rendered output',
      () async {
        final handler = HtmlFileHandler(
          path: logFile.path,
          title: 'Custom Styled Logs',
          stylesheet: const CustomStylesheet(),
        );

        final logger = Logger.get('test.custom_css');
        Logger.configure('test.custom_css', handlers: [handler]);

        logger.info('Test message for custom stylesheet');

        await handler.flush();
        await handler.dispose();

        expect(logFile.existsSync(), isTrue);
        final content = logFile.readAsStringSync();

        expect(
          content,
          contains("body {\n  font-family: 'Fira Code', monospace;\n}"),
        );
        expect(content, contains('Test message for custom stylesheet'));
      },
    );
  });
}
