import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

Future<void> main() async {
  print(
    '\x1B[1;36m================================================================\x1B[0m',
  );
  print(
    '\x1B[1;36m     LOGD_NETWORK: NDJSON STREAMING & BACKOFF POLICY DEMO       \x1B[0m',
  );
  print(
    '\x1B[1;36m================================================================\x1B[0m\n',
  );

  final receivedBatches = <String>[];
  String? detectedContentType;

  // 1. In-process HTTP Intake Server supporting NDJSON (Newline-Delimited JSON)
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final serverCompleter = Completer<void>();

  server.listen((final request) async {
    detectedContentType = request.headers.value('content-type');

    final rawBytes = <int>[];
    await for (final chunk in request) {
      rawBytes.addAll(chunk);
    }

    final payloadString = utf8.decode(rawBytes);
    receivedBatches.add(payloadString);

    request.response
      ..statusCode = HttpStatus.ok
      ..write('OK');
    await request.response.close();

    if (!serverCompleter.isCompleted) {
      serverCompleter.complete();
    }
  });

  final ingestUrl = 'http://127.0.0.1:${server.port}/api/v1/stream';
  print('📡 Ingest Endpoint: \x1B[32m$ingestUrl\x1B[0m\n');

  // 2. Configure HttpSink with:
  //    - NDJSON delivery format (application/x-ndjson)
  //    - Decorrelated jitter backoff policy
  //    - Strict memory budgeting (maxBufferBytes) with priority eviction
  final backoff = const BackoffPolicy(
    initialDelay: Duration(milliseconds: 100),
    maxDelay: Duration(seconds: 5),
    multiplier: 2.0,
    jitter: true,
  );

  final sink = HttpSink(
    url: ingestUrl,
    batchSize: 5,
    deliveryFormat: HttpDeliveryFormat.ndjson,
    backoffPolicy: backoff,
    maxBufferBytes: 50 * 1024, // 50 KB buffer ceiling
    dropPolicy: DropPolicy.discardByPriority,
    flushInterval: const Duration(milliseconds: 500),
  );

  final handler = Handler(formatter: const JsonFormatter(), sink: sink);

  Logger.configure('stream.telemetry', handlers: [handler]);
  final logger = Logger.get('stream.telemetry');

  print('📦 Emitting 5 structured log events with JSON metadata...');
  for (int i = 1; i <= 5; i++) {
    logger.info(
      'Streaming telemetry record $i',
      context: {
        'batch': 1,
        'index': i,
        'service': 'order-processor',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Wait for the server to ingest the NDJSON stream batch
  await serverCompleter.future.timeout(const Duration(seconds: 5));

  print('\n\x1B[1;32m✔ Stream Ingestion Summary:\x1B[0m');
  print('  -> Content-Type:         \x1B[1m$detectedContentType\x1B[0m');
  print('  -> Delivery Format:      HttpDeliveryFormat.ndjson');
  print(
    '  -> Backoff Policy:       ${backoff.initialDelay.inMilliseconds}ms -> ${backoff.maxDelay.inSeconds}s (jitter: ${backoff.jitter})',
  );
  print('  -> Memory Ceiling:       ${sink.maxBufferBytes} bytes');
  print('  -> Drop Policy:          DropPolicy.discardByPriority');

  if (receivedBatches.isNotEmpty) {
    print(
      '\n\x1B[1;33m📝 Received Raw NDJSON Body (one JSON object per line):\x1B[0m',
    );
    final lines = receivedBatches.first.trim().split('\n');
    for (int idx = 0; idx < lines.length; idx++) {
      print('  Line ${idx + 1}: ${lines[idx]}');
    }
  }

  await sink.dispose();
  await server.close(force: true);

  print(
    '\n\x1B[1;32m✔ NDJSON Delivery & Backoff Demonstration Completed Successfully!\x1B[0m',
  );
}
