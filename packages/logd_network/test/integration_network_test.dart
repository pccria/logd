import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';
import 'package:test/test.dart';
import '../../../scripts/servers/network_test_utils.dart';

void main() {
  group('Network Sinks Integration', () {
    Process? socketProcess;
    Process? httpProcess;

    Stream<String>? socketStdout;
    Stream<String>? socketStderr;
    Stream<String>? httpStdout;
    Stream<String>? httpStderr;

    int? socketPort;
    int? httpPort;

    bool hasPython = false;
    String? socketPython;
    String? httpPython;

    // Helper to wait for a specific string in process output
    Future<void> waitForOutput(
      final Stream<String> stdout,
      final Stream<String> stderr,
      final String pattern, {
      final Duration timeout = const Duration(seconds: 15),
    }) async {
      final completer = Completer<void>();

      void check(final String line, final String type) {
        if (line.contains(pattern)) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      }

      final subStdout = stdout.listen((final line) => check(line, 'STDOUT'));
      final subStderr = stderr.listen((final line) => check(line, 'STDERR'));

      try {
        await completer.future.timeout(timeout);
      } finally {
        await subStdout.cancel();
        await subStderr.cancel();
      }
    }

    setUpAll(() async {
      final serversDir = Directory('scripts/servers').existsSync()
          ? Directory('scripts/servers').absolute.path
          : Directory('../../scripts/servers').absolute.path;
      final socketDir = '$serversDir/socket';
      final httpDir = '$serversDir/http';

      final socketPythonExe = Platform.isWindows
          ? '$socketDir/.venv/Scripts/python.exe'
          : '$socketDir/.venv/bin/python';

      final httpPythonExe = Platform.isWindows
          ? '$httpDir/.venv/Scripts/python.exe'
          : '$httpDir/.venv/bin/python';

      if (File(socketPythonExe).existsSync() &&
          File(httpPythonExe).existsSync()) {
        hasPython = true;
        socketPython = File(socketPythonExe).absolute.path;
        httpPython = File(httpPythonExe).absolute.path;
      } else {
        // Fallback: check system python has required packages
        try {
          final res = await Process.run('python', [
            '-c',
            'import flask, websockets',
          ]);
          if (res.exitCode == 0) {
            hasPython = true;
            socketPython = 'python';
            httpPython = 'python';
          }
        } catch (_) {}
      }

      if (!hasPython) {
        return;
      }

      // 1. Dynamic Port Discovery
      socketPort = await NetworkTestUtils.findAvailablePort(12347);
      httpPort = await NetworkTestUtils.findAvailablePort(8081);

      // 2. Start WebSocket server
      socketProcess = await Process.start(
        socketPython!,
        ['main.py', '--port', socketPort.toString()],
        workingDirectory: socketDir,
        environment: {'HOST': '127.0.0.1', 'PYTHONUNBUFFERED': '1'},
      );
      socketStdout = socketProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      socketStderr = socketProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();

      // 3. Start HTTP server
      httpProcess = await Process.start(
        httpPython!,
        ['main.py', '--port', httpPort.toString()],
        workingDirectory: httpDir,
        environment: {'HOST': '127.0.0.1', 'PYTHONUNBUFFERED': '1'},
      );
      httpStdout = httpProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      httpStderr = httpProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();

      // 4. Wait for both servers to be ready
      await Future.wait([
        waitForOutput(socketStdout!, socketStderr!, 'SocketSink'),
        waitForOutput(httpStdout!, httpStderr!, 'HttpSink'),
      ]);
    });

    tearDownAll(() async {
      if (!hasPython) {
        return;
      }
      socketProcess?.kill();
      httpProcess?.kill();
      await Future.wait([
        socketProcess!.exitCode,
        httpProcess!.exitCode,
      ]).catchError((final _) => [0, 0]);
    });

    test('SocketSink streams logs in real-time', () async {
      if (!hasPython) {
        markTestSkipped('Python environment with requirements not found');
        return;
      }
      final sink = SocketSink(url: 'ws://127.0.0.1:$socketPort');

      final handler = Handler(
        formatter: const PlainFormatter(metadata: {}),
        sink: sink,
      );

      final logger = Logger.get('test.socket');
      Logger.configure('test.socket', handlers: [handler]);

      // Verify connection on server side
      final serverReady = waitForOutput(
        socketStdout!,
        socketStderr!,
        'Connection established',
      );
      logger.info('handshake');
      await serverReady;

      final messageReceived = waitForOutput(
        socketStdout!,
        socketStderr!,
        'INTEGRATION_TEST_SOCKET',
      );
      logger.info('INTEGRATION_TEST_SOCKET');
      await messageReceived;

      await sink.dispose();
    });

    test('HttpSink ships logs in batches', () async {
      if (!hasPython) {
        markTestSkipped('Python environment with requirements not found');
        return;
      }
      final sink = HttpSink(
        url: 'http://127.0.0.1:$httpPort/logs',
        batchSize: 2,
      );

      final handler = Handler(
        formatter: const PlainFormatter(metadata: {}),
        sink: sink,
      );

      final logger = Logger.get('test.http');
      Logger.configure('test.http', handlers: [handler]);

      // Send first - should NOT be received yet
      logger.info('log_1');
      await Future.delayed(const Duration(milliseconds: 100));

      // Send second - should trigger batch flush
      final batchReceived = waitForOutput(httpStdout!, httpStderr!, 'BATCH');
      logger.info('INTEGRATION_TEST_HTTP_BATCH');
      await batchReceived;

      await sink.dispose();
    });
  });
}
