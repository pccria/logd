import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

Future<void> main() async {
  print(
      '\x1B[1;36m================================================================\x1B[0m');
  print(
      '\x1B[1;36m       LOGD_NETWORK: GZIP BATCH COMPRESSION DEMO                \x1B[0m');
  print(
      '\x1B[1;36m================================================================\x1B[0m\n');

  int totalBytesReceived = 0;
  final receivedLogs = <String>[];
  String? detectedEncoding;

  // 1. In-process HTTP Intake Server supporting GZip
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final serverCompleter = Completer<void>();

  server.listen((final request) async {
    detectedEncoding = request.headers.value('content-encoding');

    Stream<List<int>> stream = request;
    final rawBytes = <int>[];

    await for (final chunk in stream) {
      rawBytes.addAll(chunk);
    }
    totalBytesReceived = rawBytes.length;

    // Decompress if gzip encoded
    List<int> decodedBytes = rawBytes;
    if (detectedEncoding == 'gzip') {
      decodedBytes = gzip.decode(rawBytes);
    }

    final jsonText = utf8.decode(decodedBytes);
    final logEntries = (jsonDecode(jsonText) as List).cast<String>();
    receivedLogs.addAll(logEntries);

    request.response
      ..statusCode = HttpStatus.ok
      ..write('OK');
    await request.response.close();

    if (!serverCompleter.isCompleted) {
      serverCompleter.complete();
    }
  });

  final ingestUrl = 'http://127.0.0.1:${server.port}/api/v1/ingest';
  print('📡 Ingest Endpoint: \x1B[32m$ingestUrl\x1B[0m\n');

  // 2. Configure HttpSink with GZip compression enabled
  final sink = HttpSink(
    url: ingestUrl,
    batchSize: 20,
    compress: true, // Enable GZip payload compression
    flushInterval: const Duration(seconds: 1),
  );

  final handler = Handler(
    formatter: const JsonFormatter(),
    sink: sink,
  );

  Logger.configure('app.telemetry', handlers: [handler]);
  final logger = Logger.get('app.telemetry');

  print('📦 Emitting 20 structured log events with JSON metadata...');
  for (int i = 1; i <= 20; i++) {
    logger.info(
      'Transaction processing checkpoint $i',
      context: {
        'txId': 'tx-99482-$i',
        'userId': 'usr-${1000 + i}',
        'latencyMs': 12.4 + (i * 1.5),
        'region': 'us-east-1',
        'status': 'SUCCESS',
      },
    );
  }

  // Wait for server to ingest the batch
  await serverCompleter.future.timeout(const Duration(seconds: 5));

  // Calculate uncompressed JSON size for comparison
  final uncompressedSample = utf8.encode(jsonEncode(receivedLogs));
  final uncompressedBytes = uncompressedSample.length;
  final ratio =
      ((1 - (totalBytesReceived / uncompressedBytes)) * 100).toStringAsFixed(1);

  print('\n\x1B[1;32m✔ Batch Ingestion Summary:\x1B[0m');
  print('  -> HTTP Content-Encoding: \x1B[1m$detectedEncoding\x1B[0m');
  print('  -> Logs Ingested:          ${receivedLogs.length}');
  print('  -> Uncompressed Size:     $uncompressedBytes bytes');
  print('  -> Transmitted GZip Size: \x1B[32m$totalBytesReceived bytes\x1B[0m');
  print(
      '  -> Network Reduction:     \x1B[1;32m$ratio% bandwidth saved\x1B[0m\n');

  await sink.dispose();
  await server.close(force: true);

  print(
      '\x1B[1;32m✔ GZip Compression Demonstration Completed Successfully!\x1B[0m');
}
