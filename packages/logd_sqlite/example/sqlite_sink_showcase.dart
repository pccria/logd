// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';

void main() async {
  _printHeader('LOGD_SQLITE SHOWCASE & PROOF-OF-CONCEPT');

  // Phase 1: Initialize SqliteSink & Logging Pipeline
  print('┌─ [Phase 1] Configuring Logging Pipeline');
  const dbPath = 'showcase_logs.db';

  final sqliteSink = SqliteSink(
    dbPath: dbPath,
    maxEntries: 100, // Capped retention limit
    batchSize: 10, // Buffer 10 logs before disk transaction
    flushInterval: const Duration(seconds: 1),
    walMode: true,
  );

  Logger.configure(
    'global',
    handlers: [Handler(formatter: const PlainFormatter(), sink: sqliteSink)],
  );

  print('│  ✓ SqliteSink initialized (WAL mode: true, maxEntries: 100)');
  print('│  ✓ Handler attached to global logger hierarchy');
  print('└─────────────────────────────────────────────────────────────\n');

  // Phase 2: Simulate High-Throughput Service Telemetry
  print('┌─ [Phase 2] Simulating Multi-Service Enterprise Telemetry');
  print(
    '│  ➜ Emitting 120 log entries across auth, payment, and db modules...',
  );

  final authLogger = Logger.get('app.auth');
  final paymentLogger = Logger.get('app.payment');
  final dbLogger = Logger.get('app.db');

  for (int i = 1; i <= 40; i++) {
    authLogger.info(
      'User auth session initialized #$i',
      context: {'userId': 'USR-${1000 + i}', 'ip': '192.168.1.$i'},
    );

    if (i % 5 == 0) {
      authLogger.warning(
        'Failed password verification attempt #$i',
        context: {'userId': 'USR-${1000 + i}', 'attempts': 3},
      );
    }

    paymentLogger.info(
      'Payment transaction processed #$i',
      context: {
        'transactionId': 'TX-${9000 + i}',
        'amount': (i * 12.50).toStringAsFixed(2),
      },
    );

    if (i % 8 == 0) {
      paymentLogger.error(
        'Payment gateway timeout on transaction #$i',
        error: TimeoutException('Gateway took > 5000ms to respond'),
        stackTrace: StackTrace.current,
        context: {'transactionId': 'TX-${9000 + i}', 'gateway': 'StripeAPI'},
      );
    }

    dbLogger.debug(
      'Query executed on pool connection #$i',
      context: {'poolId': 'pool-primary', 'latencyMs': i * 2},
    );
  }

  // Force immediate flush of remaining buffered entries
  await sqliteSink.flush();

  final totalStored = sqliteSink.count();
  print('│  ✓ Telemetry generation complete!');
  print(
    '│  ✓ Auto-retention active: 120 logs produced -> $totalStored retained'
    ' (maxEntries: 100)',
  );
  print('└─────────────────────────────────────────────────────────────\n');

  // Phase 3: Demonstrate Query Engine Capabilities
  print('┌─ [Phase 3] Live Query Engine Demonstration');

  // Query 1: Filter by minLevel WARNING/ERROR via type-safe builder
  final criticalLogs = sqliteSink
      .query()
      .minLevel(LogLevel.warning)
      .limit(5)
      .execute();
  print(
    '│  🔍 [Query 1] Filter minLevel = WARNING/ERROR (showing top 3 of '
    '${criticalLogs.length}):',
  );
  for (final log in criticalLogs.take(3)) {
    final lvl = log.levelName.toUpperCase();
    print('│     - [$lvl] ${log.loggerName}: ${log.message}');
  }

  // Query 2: Filter by Logger Namespace & JSON Context Key
  final paymentLogs = sqliteSink
      .query()
      .logger('app.payment')
      .whereContext('transactionId', 'TX-9035')
      .limit(5)
      .execute();
  print(
    '│  🔍 [Query 2] Filter loggerName = "app.payment" & context (found '
    '${paymentLogs.length}):',
  );
  for (final log in paymentLogs.take(2)) {
    print(
      '│     - ID #${log.id}: ${log.message} | Context: '
      '${log.contextJson}',
    );
  }

  // Query 3: FTS5 Full-Text Search with snippets & ranking
  final searchLogs = sqliteSink.query().search('timeout').limit(5).execute();
  print('│  🔍 [Query 3] FTS5 Search "timeout" (found ${searchLogs.length}):');
  for (final log in searchLogs) {
    print('│     - Match snippet: ${log.snippet ?? log.message}');
    print('│       Error Detail: ${log.error}');
  }

  print('└─────────────────────────────────────────────────────────────\n');

  // Phase 4: Maintenance & Teardown
  print('┌─ [Phase 4] Database Maintenance & Teardown');
  print('│  ➜ Running sqliteSink.vacuum()...');
  sqliteSink.vacuum();
  print('│  ✓ Vacuum completed successfully.');

  print('│  ➜ Purging table via sqliteSink.clear()...');
  sqliteSink.clear();
  print('│  ✓ Table cleared. Record count: ${sqliteSink.count()}');

  await sqliteSink.dispose();
  print('│  ✓ SqliteSink handle disposed cleanly.');
  print('└─────────────────────────────────────────────────────────────\n');

  // Cleanup file created for showcase
  final dbFile = File(dbPath);
  if (dbFile.existsSync()) {
    dbFile.deleteSync();
  }
  final shmFile = File('$dbPath-shm');
  if (shmFile.existsSync()) {
    shmFile.deleteSync();
  }
  final walFile = File('$dbPath-wal');
  if (walFile.existsSync()) {
    walFile.deleteSync();
  }

  _printHeader('SHOWCASE COMPLETED SUCCESSFULLY');
}

void _printHeader(final String title) {
  const line =
      '==================================================='
      '=============================';
  print(line);
  print('  $title');
  print(line);
}
