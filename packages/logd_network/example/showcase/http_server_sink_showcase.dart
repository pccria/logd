import 'dart:async';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

/// Demonstrates hosting a local HTTP & WebSocket real-time log viewer dashboard using [HttpServerSink].
Future<void> main() async {
  print('\x1B[1m\x1B[96mlogd_network\x1B[0m | HttpServerSink Viewer Showcase');
  print(
    '\x1B[2m─────────────────────────────────────────────────────────────\x1B[0m',
  );

  // Find a free port starting at 8080
  int port;
  try {
    final testSocket = await ServerSocket.bind('localhost', 8080);
    port = testSocket.port;
    await testSocket.close();
  } catch (_) {
    final testSocket = await ServerSocket.bind('localhost', 0);
    port = testSocket.port;
    await testSocket.close();
  }

  final sink = HttpServerSink(
    address: 'localhost',
    port: port,
    encoder: const AutoTextEncoder(),
    bufferCapacity: 200,
  );

  await sink.ready;

  final handler = Handler(
    formatter: const StructuredFormatter(
      metadata: {LogMetadata.timestamp, LogMetadata.logger, LogMetadata.origin},
    ),
    sink: sink,
  );

  Logger.configure('sys.server', handlers: [handler]);
  final logger = Logger.get('sys.server');

  print('\x1B[1m\x1B[92m[Dashboard Server Started]\x1B[0m');
  print('👉 Open your browser at: \x1B[4mhttp://localhost:$port\x1B[24m');
  print('Press Ctrl+C to terminate the demo.');
  print(
    '\x1B[2m─────────────────────────────────────────────────────────────\x1B[0m',
  );

  logger.info('Starting backend dashboard demo application...');
  await Future<void>.delayed(const Duration(milliseconds: 300));
  logger.info('Initializing memory caches and connection pools.');
  await Future<void>.delayed(const Duration(milliseconds: 300));
  logger.warning('CPU usage is elevated (84%) during cold-start compilation.');
  await Future<void>.delayed(const Duration(milliseconds: 300));
  logger.error(
    'Failed to resolve API gateway configuration.',
    error: const HttpException('Connection timed out after 5000ms'),
  );

  int count = 0;
  Timer.periodic(const Duration(seconds: 2), (final timer) {
    count++;
    final context = {
      'iteration': count,
      'memory_mb': 120 + (count % 4) * 15,
      'latency_ms': 4 + (count % 8) * 3,
    };

    if (count % 5 == 0) {
      logger.warning('Periodic system load alert', context: context);
    } else {
      logger.info('Health check operational tick', context: context);
    }
  });
}
