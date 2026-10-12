import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';

/// A custom stylesheet implementation to rebrand the HTML output.
class CustomBrandStylesheet implements HtmlStylesheet {
  const CustomBrandStylesheet();

  @override
  String buildCss(final LogTheme theme) => '''
    body {
      font-family: 'Courier New', Courier, monospace;
      background-color: #f4f4f9;
      color: #333;
      margin: 20px;
    }
    table {
      border-collapse: collapse;
      width: 100%;
    }
    th, td {
      border: 1px solid #ddd;
      padding: 8px;
    }
    th {
      background-color: #007bff;
      color: white;
    }
  ''';

  @override
  String buildJs() => ''; // No custom JS needed
}

void main() async {
  // Use synchronous rendering to easily inject custom un-serialized stylesheets
  Logger.configure(
    'branded_logger',
    handlers: [
      HtmlFileHandler(
        path: 'logs/branded_logs.html',
        title: 'Company X Logs',
        stylesheet: const CustomBrandStylesheet(),
      ),
    ],
  );

  Logger.get('branded_logger').info('Custom branded HTML logs active.');

  await Future.delayed(const Duration(milliseconds: 100));
  print('HTML logs generated at: logs/branded_logs.html');
}
