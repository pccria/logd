import 'dart:async';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

/// Demonstrates real-time WebSocket log streaming and frame delivery using [SocketSink]
/// against an in-process pure-Dart WebSocket server.
Future<void> main() async {
  print('\x1B[1m\x1B[96mlogd_network\x1B[0m | SocketSink Showcase');
  print(
    '\x1B[2m─────────────────────────────────────────────────────────────\x1B[0m',
  );

  // 1. Start a self-contained in-process WebSocket server in pure Dart
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final serverPort = server.port;

  print(
    '\x1B[2m[Server] WebSocket log server listening on ws://127.0.0.1:$serverPort\x1B[0m',
  );

  var frameCount = 0;
  final serverSub = server.transform(WebSocketTransformer()).listen(
    (final webSocket) {
      print(
          '\n\x1B[35m[Server] WebSocket client connected from 127.0.0.1\x1B[0m');
      webSocket.listen(
        (final data) {
          frameCount++;
          print(
              '\n\x1B[33m[Server] Frame #$frameCount received in real time:\x1B[0m');
          print(data);
        },
        onDone: () {
          print('\x1B[2m[Server] Client disconnected cleanly.\x1B[0m');
        },
      );
    },
  );

  try {
    // 2. Configure SocketSink with styled terminal output
    final wsHandler = Handler(
      formatter: const PlainFormatter(
        metadata: {LogMetadata.timestamp, LogMetadata.logger},
      ),
      decorators: const [
        StyleDecorator(),
        BoxDecorator(borderStyle: BorderStyle.rounded),
      ],
      sink: SocketSink(
        url: 'ws://127.0.0.1:$serverPort',
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
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await wsHandler.sink.dispose();
    print(
        '\n\x1B[1m\x1B[32m[Done] Socket streaming demonstration complete.\x1B[0m');
  } finally {
    await serverSub.cancel();
    await server.close(force: true);
  }
}
