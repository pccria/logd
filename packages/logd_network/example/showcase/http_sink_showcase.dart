import 'dart:async';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

import '../../../../scripts/servers/network_test_utils.dart';

/// Finds the root repository directory containing `scripts/servers`.
Directory _findProjectRoot() {
  var dir = Directory.current.absolute;
  while (dir.path != dir.parent.path) {
    if (Directory('${dir.path}/scripts/servers').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  try {
    var scriptDir = File(Platform.script.toFilePath()).parent;
    while (scriptDir.path != scriptDir.parent.path) {
      if (Directory('${scriptDir.path}/scripts/servers').existsSync()) {
        return scriptDir;
      }
      scriptDir = scriptDir.parent;
    }
  } catch (_) {}
  return Directory.current;
}

/// Demonstrates batching, retrying, and transmitting logs via HTTP POST using [HttpSink].
Future<void> main() async {
  print('\x1B[1m\x1B[96mlogd_network\x1B[0m | HttpSink Showcase');
  print(
    '\x1B[2m─────────────────────────────────────────────────────────────\x1B[0m',
  );

  Process? httpServer;

  try {
    final projectRoot = _findProjectRoot().path;
    final httpDir = '$projectRoot/scripts/servers/http';

    final httpPort = await NetworkTestUtils.findAvailablePort(8081);
    print(
      '\x1B[2m[System] Starting mock HTTP log collector on port $httpPort...\x1B[0m',
    );

    final venvPython = Platform.isWindows
        ? '$httpDir/.venv/Scripts/python.exe'
        : '$httpDir/.venv/bin/python';
    final pythonExe = File(venvPython).existsSync()
        ? File(venvPython).absolute.path
        : (Platform.isWindows ? 'python' : 'python3');

    httpServer = await Process.start(
      pythonExe,
      ['main.py', '--port', httpPort.toString()],
      workingDirectory: httpDir,
      environment: {'PYTHONUNBUFFERED': '1'},
    );

    httpServer.stdout.listen((final data) => stdout.add(data));
    httpServer.stderr.listen((final data) => stderr.add(data));

    // Wait for server initialization
    await Future<void>.delayed(const Duration(seconds: 1));

    // Configure HttpSink with batching and retry policy
    final httpHandler = Handler(
      formatter: const JsonFormatter(),
      sink: HttpSink(
        url: 'http://127.0.0.1:$httpPort/logs',
        batchSize: 3, // Ships in batches of 3
        flushInterval: const Duration(seconds: 2),
        maxRetries: 3,
        dropPolicy: DropPolicy.discardOldest,
      ),
      timeout: const Duration(seconds: 5),
    );

    Logger.configure('network.http', handlers: [httpHandler]);
    final logger = Logger.get('network.http');

    print('\n\x1B[32m[Client] Emitting 5 log entries...\x1B[0m');
    logger.info('User checkout initiated', context: {'userId': 'u-102'});
    logger.info('Cart validated', context: {'itemsCount': 4});
    logger.info(
      'Payment processed',
      context: {'amount': 99.50, 'currency': 'USD'},
    );
    // Batch 1 (3 entries) flushes immediately!

    logger.warning('Inventory stock low', context: {'sku': 'SKU-882'});
    logger.info('Receipt sent to user');

    // Wait for periodic flush interval
    print('\x1B[2m[Client] Waiting for periodic flush...\x1B[0m');
    await Future<void>.delayed(const Duration(seconds: 3));

    await httpHandler.sink.dispose();
    print('\n\x1B[1m[Done] All HTTP batches delivered successfully.\x1B[0m');
  } catch (e) {
    print(
      '\x1B[31mShowcase failed (is Python virtual environment initialized?): $e\x1B[0m',
    );
  } finally {
    httpServer?.kill();
  }
}
