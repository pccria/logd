import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

Future<void> main() async {
  print(
      '\x1B[1;36m================================================================\x1B[0m');
  print(
      '\x1B[1;36m       LOGD_NETWORK: CIRCUIT BREAKER & FAILOVER DEMO            \x1B[0m');
  print(
      '\x1B[1;36m================================================================\x1B[0m\n');

  // 1. Start simulated in-process HTTP intake servers
  bool primaryHealthy = true;
  bool backupHealthy = true;
  final primaryReceived = <String>[];
  final backupReceived = <String>[];

  final primaryServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  primaryServer.listen((final request) async {
    final body = await utf8.decoder.bind(request).join();
    if (!primaryHealthy) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..write('Primary Cluster Down (503)');
      await request.response.close();
      return;
    }
    final logs = (jsonDecode(body) as List).cast<String>();
    primaryReceived.addAll(logs);
    request.response
      ..statusCode = HttpStatus.ok
      ..write('OK');
    await request.response.close();
  });

  final backupServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  backupServer.listen((final request) async {
    final body = await utf8.decoder.bind(request).join();
    if (!backupHealthy) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..write('Backup Cluster Down (503)');
      await request.response.close();
      return;
    }
    final logs = (jsonDecode(body) as List).cast<String>();
    backupReceived.addAll(logs);
    request.response
      ..statusCode = HttpStatus.ok
      ..write('OK');
    await request.response.close();
  });

  final primaryUrl = 'http://127.0.0.1:${primaryServer.port}/primary/logs';
  final backupUrl = 'http://127.0.0.1:${backupServer.port}/backup/logs';

  print('📡 Primary Server: \x1B[32m$primaryUrl\x1B[0m');
  print('📡 Backup Server:  \x1B[32m$backupUrl\x1B[0m\n');

  // 2. Configure HttpSink with circuit breaker and failover endpoint
  final sink = HttpSink(
    url: primaryUrl,
    failoverUrls: [backupUrl],
    batchSize: 1,
    maxRetries: 1,
    failureThreshold: 2,
    recoveryTimeout: const Duration(seconds: 2),
  );

  final handler = Handler(
    formatter: const PlainFormatter(metadata: {}),
    sink: sink,
  );

  Logger.configure('resilience.demo', handlers: [handler]);
  final logger = Logger.get('resilience.demo');

  // Step 1: Normal operation
  print('\x1B[1;33m[Phase 1] Normal Operation (Primary Healthy)\x1B[0m');
  logger.info('Log #1: System boot completed successfully');
  await Future<void>.delayed(const Duration(milliseconds: 100));
  print('  -> Current Active Endpoint: ${sink.currentUrl}');
  print('  -> Circuit State:           ${sink.circuitState.name}');
  print('  -> Primary received:        ${primaryReceived.length} logs\n');

  // Step 2: Primary fails -> Automatic Failover
  print(
      '\x1B[1;33m[Phase 2] Simulating Primary Cluster Outage -> Failover\x1B[0m');
  primaryHealthy = false;
  print('  ⚠️  Primary cluster set to UNHEALTHY (503)');
  logger.info('Log #2: Transaction 98402 processed');
  await Future<void>.delayed(const Duration(milliseconds: 200));
  print(
      '  -> Current Active Endpoint: \x1B[32m${sink.currentUrl}\x1B[0m (Switched to Backup!)');
  print('  -> Circuit State:           ${sink.circuitState.name}');
  print('  -> Backup received:         ${backupReceived.length} logs\n');

  // Step 3: Backup also fails -> Circuit Tripping (Fast Fail)
  print(
      '\x1B[1;33m[Phase 3] Simulating Total Outage (Primary + Backup Down) -> Circuit Breaker\x1B[0m');
  backupHealthy = false;
  print('  ⚠️  Backup cluster set to UNHEALTHY (503)');
  logger.info('Log #3: Critical alert triggered during network disruption');
  await Future<void>.delayed(const Duration(milliseconds: 200));

  logger.info('Log #4: Buffered event while circuit is tripping');
  await Future<void>.delayed(const Duration(milliseconds: 200));

  print(
      '  -> Circuit State: \x1B[31m${sink.circuitState.name.toUpperCase()}\x1B[0m (Failing fast, saving network I/O)');
  print('  -> Consecutive Failures: ${sink.consecutiveFailures}');

  // Send another log while open: it will be buffered, NOT dropped by failing I/O
  logger.info('Log #5: Safely retained in memory buffer');
  await Future<void>.delayed(const Duration(milliseconds: 100));
  print(
      '  -> Fast-fail check: No HTTP requests dispatched while circuit is OPEN\n');

  // Step 4: Recovery
  print(
      '\x1B[1;33m[Phase 4] Restoring Primary Cluster & Recovery Probe\x1B[0m');
  primaryHealthy = true;
  print('  ✔ Primary cluster restored to HEALTHY (200)');
  print('  ⏳ Waiting for recovery window (2.2 seconds)...');
  await Future<void>.delayed(const Duration(milliseconds: 2200));

  // Sending next log triggers halfOpen probe and drain
  logger.info('Log #6: Post-recovery health probe');
  await Future<void>.delayed(const Duration(milliseconds: 300));

  print(
      '  -> Circuit State: \x1B[32m${sink.circuitState.name.toUpperCase()}\x1B[0m (Probe succeeded!)');
  print('  -> Consecutive Failures: ${sink.consecutiveFailures}');
  print('  -> Total Primary Logs:   ${primaryReceived.length}');
  print('  -> Total Backup Logs:    ${backupReceived.length}\n');

  // Clean shutdown
  await sink.dispose();
  await primaryServer.close(force: true);
  await backupServer.close(force: true);

  print(
      '\x1B[1;32m✔ Circuit Breaker & Failover Demonstration Completed Successfully!\x1B[0m');
}
