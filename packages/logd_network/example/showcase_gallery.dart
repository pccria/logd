import 'dart:async';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

import 'showcase/http_dashboard_showcase.dart' as http_dashboard_showcase;
import 'showcase/http_server_sink_showcase.dart' as http_server_sink_showcase;
import 'showcase/http_sink_showcase.dart' as http_sink_showcase;
import 'showcase/socket_sink_showcase.dart' as socket_sink_showcase;

void main(final List<String> args) async {
  if (args.isNotEmpty) {
    switch (args.first.toLowerCase()) {
      case '1':
      case 'http':
        await http_sink_showcase.main();
        return;
      case '2':
      case 'socket':
      case 'ws':
        await socket_sink_showcase.main();
        return;
      case '3':
      case 'server':
        await http_server_sink_showcase.main();
        return;
      case '4':
      case 'dashboard':
        await http_dashboard_showcase.main();
        return;
      case '5':
      case 'all':
        await _runAutomatedSummary();
        return;
    }
  }

  print('================================================');
  print('       LOGD_NETWORK: INTERACTIVE SHOWCASE       ');
  print('================================================');
  print('Select a network observability demo to run:');
  print('');
  print('  [1] HttpSink Showcase (Batching & Retry)');
  print('  [2] SocketSink Showcase (Live WebSocket Streaming)');
  print('  [3] HttpServerSink Showcase (Embedded Browser Viewer)');
  print('  [4] HttpDashboardHandler Showcase (Pre-wired DX Preset)');
  print('  [5] Run All Non-Blocking Demos Sequentially');
  print('  [0] Exit');
  print('');
  stdout.write('Enter choice [1-5, 0]: ');

  final input = stdin.readLineSync()?.trim();
  print('');

  switch (input) {
    case '1':
      await http_sink_showcase.main();
      break;
    case '2':
      await socket_sink_showcase.main();
      break;
    case '3':
      await http_server_sink_showcase.main();
      break;
    case '4':
      await http_dashboard_showcase.main();
      break;
    case '5':
      await _runAutomatedSummary();
      break;
    case '0':
    case null:
      print('Exiting.');
      break;
    default:
      print('Invalid choice "$input". Exiting.');
  }
}

Future<void> _runAutomatedSummary() async {
  print('\x1B[1mRunning quick automated network demonstration...\x1B[0m\n');

  final handler = HttpDashboardHandler(
    port: 0,
    title: 'Automated Test Dashboard',
  );

  Logger.configure('automated.network', handlers: [handler]);
  final logger = Logger.get('automated.network');

  logger.info('Initialized automated network pipeline');
  logger.warning('Simulated non-critical warning event');
  logger.info('Network validation successful');

  await Future<void>.delayed(const Duration(milliseconds: 500));
  await handler.dispose();

  print(
    '\n\x1B[32m✔ Automated network demonstration completed cleanly.\x1B[0m',
  );
}
