// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:logd_network/logd_network.dart';

Future<void> main(final List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/shutdown_exit_check.dart <scenario>');
    exit(1);
  }

  final scenario = args[0];
  final tempDir = Directory.systemTemp.createTempSync('logd_shutdown_test_');

  try {
    switch (scenario) {
      case 'console_async':
        final handler = ConsoleHandler.async();
        Logger.configure('test', handlers: [handler]);
        break;
      case 'file_plain':
        final file = File('${tempDir.path}/plain.log');
        final handler = PlainFileHandler(path: file.path);
        Logger.configure('test', handlers: [handler]);
        break;
      case 'html_async':
        final file = File('${tempDir.path}/output.html');
        final handler = HtmlFileHandler.async(path: file.path);
        Logger.configure('test', handlers: [handler]);
        break;
      case 'http_sink':
        const handler = Handler(
          formatter: PlainFormatter(),
          sink: HttpSink(
            url: 'http://127.0.0.1:9',
            flushInterval: Duration(milliseconds: 100),
          ),
        );
        Logger.configure('test', handlers: [handler]);
        break;
      default:
        stderr.writeln('Unknown scenario: $scenario');
        exit(1);
    }

    Logger.get('test').info('Test log message');

    await Logger.shutdown();
  } finally {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }
}
