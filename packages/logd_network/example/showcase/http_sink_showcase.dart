import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

/// Demonstrates batching, retrying, dynamic auth hooks, and transmitting logs
/// via HTTP POST using [HttpSink] against an in-process Dart HTTP server.
Future<void> main() async {
  print('\x1B[1m\x1B[96mlogd_network\x1B[0m | HttpSink Showcase');
  print(
    '\x1B[2m─────────────────────────────────────────────────────────────\x1B[0m',
  );

  // 1. Start a self-contained in-process HTTP log collector in pure Dart
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final serverPort = server.port;

  print(
    '\x1B[2m[Collector] Ingestion server listening on http://127.0.0.1:$serverPort/logs\x1B[0m',
  );

  var batchCount = 0;
  final serverSub = server.listen((final request) async {
    if (request.method == 'POST' && request.uri.path == '/logs') {
      batchCount++;
      final authHeader = request.headers.value('authorization') ?? '(none)';
      final clientHeader = request.headers.value('x-service') ?? '(none)';
      final body = await utf8.decoder.bind(request).join();
      final List<dynamic> entries = jsonDecode(body) as List<dynamic>;

      print(
        '\n\x1B[35m[Collector] Received Batch #$batchCount (${entries.length} logs)\x1B[0m',
      );
      print(
        '\x1B[2m  Headers: Authorization="$authHeader", X-Service="$clientHeader"\x1B[0m',
      );
      for (final entry in entries) {
        if (entry is Map) {
          final level = entry['level'] ?? 'info';
          final msg = entry['message'] ?? '';
          final ctx = entry['context'] != null ? ' ${entry['context']}' : '';
          print('  \x1B[36m•\x1B[0m [\x1B[33m$level\x1B[0m] $msg$ctx');
        } else {
          print('  \x1B[36m•\x1B[0m $entry');
        }
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'ok', 'processed': entries.length}));
      await request.response.close();
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found');
      await request.response.close();
    }
  });

  try {
    // 2. Configure HttpSink with batching, dynamic auth hooks, and retry policy
    var tokenSequence = 0;
    final httpHandler = Handler(
      formatter: const JsonFormatter(),
      sink: HttpSink(
        url: 'http://127.0.0.1:$serverPort/logs',
        headers: const {'X-Service': 'checkout-api'},
        // Dynamic Auth Hook: evaluated before each HTTP batch POST
        headersProvider: () async {
          tokenSequence++;
          return {
            'Authorization': 'Bearer dynamic-oauth2-token-$tokenSequence'
          };
        },
        batchSize: 3, // Ships immediately when 3 logs accumulate
        flushInterval: const Duration(seconds: 2), // Or every 2 seconds
        maxRetries: 3,
        dropPolicy: DropPolicy.discardOldest,
      ),
      timeout: const Duration(seconds: 5),
    );

    Logger.configure('network.http', handlers: [httpHandler]);
    final logger = Logger.get('network.http');

    print(
        '\n\x1B[32m[Client] Emitting Batch 1 (3 entries — triggers immediate batch flush)...\x1B[0m');
    logger.info('User checkout initiated', context: {'userId': 'u-102'});
    logger.info('Cart items validated', context: {'itemsCount': 4});
    logger.info(
      'Payment processed successfully',
      context: {'amount': 99.50, 'currency': 'USD'},
    );

    // Wait a brief moment for the event loop to transmit Batch 1
    await Future<void>.delayed(const Duration(milliseconds: 200));

    print(
        '\n\x1B[32m[Client] Emitting Batch 2 (2 entries — will flush on scheduled interval or dispose)...\x1B[0m');
    logger.warning('Inventory stock low', context: {'sku': 'SKU-882'});
    logger.info('Receipt sent to customer email');

    // Wait for periodic flush interval to demonstrate timer flushing
    print('\x1B[2m[Client] Waiting for timer flush...\x1B[0m');
    await Future<void>.delayed(const Duration(seconds: 2));

    // Clean teardown: flushes remaining buffer and shuts down client
    await httpHandler.sink.dispose();
    print(
        '\n\x1B[1m\x1B[32m[Done] All HTTP batches delivered successfully.\x1B[0m');
  } finally {
    await serverSub.cancel();
    await server.close(force: true);
  }
}
