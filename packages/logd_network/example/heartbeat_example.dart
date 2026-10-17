import 'dart:async';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

Future<void> main() async {
  print(
      '\x1B[1;36m================================================================\x1B[0m');
  print(
      '\x1B[1;36m       LOGD_NETWORK: WEBSOCKET HEARTBEAT & SELF-HEALING DEMO    \x1B[0m');
  print(
      '\x1B[1;36m================================================================\x1B[0m\n');

  final receivedLogs = <String>[];
  int pingsReceived = 0;
  bool shouldRespondToPing = true;

  // 1. In-process WebSocket Mock Server
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final wsUrl = 'ws://127.0.0.1:${server.port}/ws/logs';
  print('📡 WebSocket Server listening on: \x1B[32m$wsUrl\x1B[0m\n');

  server.listen((final request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      print('🔌 Server: Client connected');

      socket.listen(
        (final message) {
          final str = message.toString();
          if (str == '{"type":"ping"}') {
            pingsReceived++;
            print('💓 Server: Received heartbeat ping #$pingsReceived');
            if (shouldRespondToPing) {
              print('   -> Replying with heartbeat pong');
              socket.add('{"type":"pong"}');
            } else {
              print(
                  '   \x1B[33m-> [Simulating dropped link] Suppressing pong response!\x1B[0m');
            }
          } else {
            print('📝 Server received log: $str');
            receivedLogs.add(str);
          }
        },
        onDone: () {
          print('🔌 Server: Connection closed');
        },
        onError: (final e) {
          print('🔌 Server: Connection error: $e');
        },
      );
    }
  });

  // 2. Configure SocketSink with fast heartbeat interval & timeout for demo
  final sink = SocketSink(
    url: wsUrl,
    heartbeatInterval: const Duration(milliseconds: 300),
    heartbeatTimeout: const Duration(milliseconds: 400),
    reconnectInterval: const Duration(milliseconds: 200),
    pingMessage: '{"type":"ping"}',
    pongMessage: '{"type":"pong"}',
  );

  final handler = Handler(
    formatter: const JsonFormatter(),
    sink: sink,
  );

  Logger.configure('heartbeat.demo', handlers: [handler]);
  final logger = Logger.get('heartbeat.demo');

  print('--- Phase 1: Healthy connection with active heartbeats ---');
  logger.info('Log 1: Service online');
  await Future<void>.delayed(const Duration(milliseconds: 700));

  print(
      '\n--- Phase 2: Unresponsive link (Server stops responding to pings) ---');
  shouldRespondToPing = false;
  logger.info('Log 2: In-flight event during degradation');
  logger.info('Log 3: Another event during degradation');

  // Wait for heartbeat timeout to detect dead link and trigger reconnect
  print('⏳ Waiting for SocketSink heartbeat timeout detection...');
  await Future<void>.delayed(const Duration(milliseconds: 800));

  print('\n--- Phase 3: Server recovers and resumes responding to pings ---');
  shouldRespondToPing = true;
  logger.info('Log 4: System recovered');

  // Wait for reconnect and buffer drain
  await Future<void>.delayed(const Duration(milliseconds: 600));

  print('\n================================================================');
  print('                     VERIFICATION RESULTS                       ');
  print('================================================================');
  print('Total Pings Received by Server: $pingsReceived');
  print('Total Logs Successfully Received: ${receivedLogs.length}');
  for (var i = 0; i < receivedLogs.length; i++) {
    print('  ${i + 1}. ${receivedLogs[i]}');
  }

  await sink.dispose();
  await server.close(force: true);
  print('\n✅ WebSocket Heartbeat demo completed successfully!\n');
}
