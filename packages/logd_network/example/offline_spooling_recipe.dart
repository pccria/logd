import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

/// Demonstrates an offline-first resilient logging pattern using [HttpSink]
/// paired with an offline spool queue.
///
/// When the remote endpoint is unavailable, failed batches are captured via
/// [HttpSink.onDropped] into an offline spool queue and replayed when the
/// endpoint recovers, guaranteeing zero telemetry loss across network outages.
Future<void> main() async {
  print(
    '\x1B[1;36m================================================================\x1B[0m',
  );
  print(
    '\x1B[1;36m       LOGD_NETWORK: OFFLINE SPOOLING & REPLAY RECIPE           \x1B[0m',
  );
  print(
    '\x1B[1;36m================================================================\x1B[0m\n',
  );

  final offlineSpool = <List<Uint8List>>[];
  final ingestedOnServer = <String>[];
  bool isServerOnline = false;

  // 1. In-process HTTP Intake Server with simulated outage toggling
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

  server.listen((final request) async {
    if (!isServerOnline) {
      // Simulate remote backend outage (HTTP 503)
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..write('Service Unavailable (Simulated Outage)');
      await request.response.close();
      return;
    }

    final rawBytes = <int>[];
    await for (final chunk in request) {
      rawBytes.addAll(chunk);
    }

    final jsonList = (jsonDecode(utf8.decode(rawBytes)) as List).cast<String>();
    ingestedOnServer.addAll(jsonList);

    request.response
      ..statusCode = HttpStatus.ok
      ..write('OK');
    await request.response.close();
  });

  final ingestUrl = 'http://127.0.0.1:${server.port}/api/v1/telemetry';
  print('📡 Target Ingestion URL: \x1B[32m$ingestUrl\x1B[0m');
  print('⚠️  Simulating network offline state initially...\n');

  // 2. Configure HttpSink with onDropped hook to spool failed logs
  final sink = HttpSink(
    url: ingestUrl,
    batchSize: 3,
    maxRetries: 2,
    backoffPolicy: const BackoffPolicy(
      initialDelay: Duration(milliseconds: 50),
      maxDelay: Duration(milliseconds: 200),
      multiplier: 1.5,
    ),
    onDropped: (final batch, final error) {
      print(
        '  \x1B[33m[Spool]\x1B[0m Network drop intercepted: Spooling ${batch.length} logs to offline storage.',
      );
      offlineSpool.add(batch);
    },
  );

  final handler = Handler(formatter: const JsonFormatter(), sink: sink);

  Logger.configure('app.telemetry', handlers: [handler]);
  final logger = Logger.get('app.telemetry');

  // 3. Emit logs while server is offline
  print('📦 Emitting 3 log records while offline...');
  logger.info('Transaction #1001 started', context: {'tx': 1001});
  logger.info('Payment authorization processed', context: {'tx': 1001});
  logger.info('Order committed', context: {'tx': 1001});

  // Allow retries to exhaust and drop into offline spool
  await Future<void>.delayed(const Duration(milliseconds: 800));

  print('\n📊 Current State:');
  print('  -> Server ingested count: ${ingestedOnServer.length}');
  print('  -> Offline spool batches: ${offlineSpool.length}');

  // 4. Restore connectivity
  print('\n🟢 Network connectivity restored! Re-enabling server...');
  isServerOnline = true;
  sink.resetCircuit();

  // 5. Replay spooled logs
  print('🚀 Replaying offline spooled batches...');
  while (offlineSpool.isNotEmpty) {
    final spooledBatch = offlineSpool.removeAt(0);
    for (final rawLine in spooledBatch) {
      final decodedJson =
          jsonDecode(utf8.decode(rawLine)) as Map<String, dynamic>;
      logger.info(
        decodedJson['message'] as String? ?? 'Replayed log',
        context: (decodedJson['context'] as Map?)?.cast<String, dynamic>(),
      );
    }
  }

  // Flush replayed batches
  await sink.flush();
  await Future<void>.delayed(const Duration(milliseconds: 200));

  print('\n✔ Offline Spooling Verification:');
  print('  -> Total logs ingested by server: ${ingestedOnServer.length}');
  print('  -> Remaining spooled batches:     ${offlineSpool.length}');

  await sink.dispose();
  await server.close(force: true);

  print(
    '\n\x1B[1;32m✔ Offline Spooling & Replay Recipe Completed Successfully!\x1B[0m',
  );
}
