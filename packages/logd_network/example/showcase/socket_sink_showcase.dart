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

/// Demonstrates real-time WebSocket log streaming and reconnection buffering with [SocketSink].
Future<void> main() async {
  print('\x1B[1m\x1B[96mlogd_network\x1B[0m | SocketSink Showcase');
  print(
    '\x1B[2m─────────────────────────────────────────────────────────────\x1B[0m',
  );

  Process? socketServer;

  try {
    final projectRoot = _findProjectRoot().path;
    final socketDir = '$projectRoot/scripts/servers/socket';

    final socketPort = await NetworkTestUtils.findAvailablePort(12348);
    print(
      '\x1B[2m[System] Starting WebSocket log server on port $socketPort...\x1B[0m',
    );

    final venvPython = Platform.isWindows
        ? '$socketDir/.venv/Scripts/python.exe'
        : '$socketDir/.venv/bin/python';
    final pythonExe = File(venvPython).existsSync()
        ? File(venvPython).absolute.path
        : (Platform.isWindows ? 'python' : 'python3');

    socketServer = await Process.start(
      pythonExe,
      ['main.py', '--port', socketPort.toString()],
      workingDirectory: socketDir,
      environment: {'PYTHONUNBUFFERED': '1'},
    );

    socketServer.stdout.listen((final data) => stdout.add(data));
    socketServer.stderr.listen((final data) => stderr.add(data));

    // Wait for server initialization
    await Future<void>.delayed(const Duration(seconds: 1));

    // Configure SocketSink with styled terminal output
    final wsHandler = Handler(
      formatter: const PlainFormatter(
        metadata: {LogMetadata.timestamp, LogMetadata.logger},
      ),
      decorators: const [
        StyleDecorator(),
        BoxDecorator(borderStyle: BorderStyle.rounded),
      ],
      sink: SocketSink(
        url: 'ws://127.0.0.1:$socketPort',
        reconnectInterval: const Duration(seconds: 3),
      ),
    );

    Logger.configure('network.ws', handlers: [wsHandler]);
    final logger = Logger.get('network.ws');

    print(
      '\n\x1B[32m[Client] Streaming live log frames over WebSocket...\x1B[0m',
    );
    logger.info('WebSocket client connected.');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    logger.warning('High memory pressure detected: 89% allocated');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    logger.error('Circuit breaker tripped for payment-service');
    await Future<void>.delayed(const Duration(seconds: 1));

    await wsHandler.sink.dispose();
    print('\n\x1B[1m[Done] Socket streaming demonstration complete.\x1B[0m');
  } catch (e) {
    print('\x1B[31mShowcase failed: $e\x1B[0m');
  } finally {
    socketServer?.kill();
  }
}
