// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';

void main() async {
  const dbPath = 'interactive_logs.db';

  final sqliteSink = SqliteSink(
    dbPath: dbPath,
    maxEntries: 500,
    batchSize: 20,
    flushInterval: const Duration(seconds: 1),
    walMode: true,
  );

  Logger.configure(
    'global',
    handlers: [Handler(formatter: const PlainFormatter(), sink: sqliteSink)],
  );

  final isInteractive = stdioType(stdin) == StdioType.terminal;

  if (isInteractive) {
    await _runInteractiveRepl(sqliteSink, dbPath);
    await _cleanup(sqliteSink, dbPath);
  } else {
    print(
      'ℹ Non-interactive environment detected. Running automated tour...\n',
    );
    await _runAutomatedTour(sqliteSink);
    await _cleanup(sqliteSink, dbPath);
  }
}

Future<void> _runInteractiveRepl(
  final SqliteSink sink,
  final String dbPath,
) async {
  bool running = true;

  while (running) {
    _printHeader('LOGD_SQLITE INTERACTIVE TERMINAL DASHBOARD & EXPLORER');
    print(
      '  DB: $dbPath | Stored: ${sink.count()} entries | WAL: ON |'
      ' Max Entries: 500',
    );
    print(
      '==================================================='
      '=============================\n',
    );

    print('  [1] 🚀 Emit Telemetry Burst (Generate 25 simulated logs)');
    print('  [2] 🔍 Query Logs by Level (TRACE, DEBUG, INFO, WARNING, ERROR)');
    print('  [3] 📂 Query Logs by Logger Namespace (e.g. "app.payment")');
    print('  [4] 🔎 Full-Text Search Across Messages, Errors & Context');
    print('  [5] 🔍 Inspect Single Record Details by ID');
    print('  [6] 📊 DB Health & Statistics');
    print('  [7] ⚡ Benchmark Write Throughput (1,000 batched writes)');
    print('  [8] 🧹 Database Maintenance (Flush, Vacuum, Clear)');
    print('  [9] 🚀 Run Automated Tour');
    print('  [0] ❌ Exit Dashboard\n');

    stdout.write('Select an option [0-9]: ');
    final rawInput = stdin.readLineSync();
    if (rawInput == null) {
      break;
    }
    final input = rawInput.trim();
    print('');

    switch (input) {
      case '1':
        await _emitTelemetryBurst(sink, 25);
        _pause();
      case '2':
        _queryByLevel(sink);
        _pause();
      case '3':
        _queryByNamespace(sink);
        _pause();
      case '4':
        _queryBySearch(sink);
        _pause();
      case '5':
        _inspectRecord(sink);
        _pause();
      case '6':
        _printStatistics(sink, dbPath);
        _pause();
      case '7':
        await _runThroughputBenchmark(sink);
        _pause();
      case '8':
        await _runMaintenanceMenu(sink, dbPath);
        _pause();
      case '9':
        await _runAutomatedTour(sink);
        _pause();
      case '0':
        running = false;
        print('👋 Exiting dashboard...');
        await _cleanup(sink, dbPath);
      default:
        print('⚠️ Invalid option. Please enter a number between 0 and 9.');
        _pause();
    }
  }
}

Future<void> _emitTelemetryBurst(final SqliteSink sink, final int count) async {
  print('🚀 Emitting $count telemetry events across app modules...');

  final authLogger = Logger.get('app.auth');
  final paymentLogger = Logger.get('app.payment');
  final dbLogger = Logger.get('app.db');

  for (int i = 1; i <= count; i++) {
    authLogger.info(
      'User auth session initialized #$i',
      context: {'userId': 'USR-${1000 + i}', 'ip': '192.168.1.$i'},
    );

    if (i % 4 == 0) {
      authLogger.warning(
        'Failed password verification attempt #$i',
        context: {'userId': 'USR-${1000 + i}', 'attempts': 3},
      );
    }

    paymentLogger.info(
      'Payment transaction processed #$i',
      context: {
        'transactionId': 'TX-${9000 + i}',
        'amount': (i * 15.75).toStringAsFixed(2),
      },
    );

    if (i % 6 == 0) {
      paymentLogger.error(
        'Payment gateway timeout on transaction #$i',
        error: TimeoutException('Gateway took > 5000ms to respond'),
        stackTrace: StackTrace.current,
        context: {'transactionId': 'TX-${9000 + i}', 'gateway': 'StripeAPI'},
      );
    }

    dbLogger.debug(
      'Query executed on pool connection #$i',
      context: {'poolId': 'pool-primary', 'latencyMs': i * 3},
    );
  }

  await sink.flush();
  print('✓ Burst complete! Total records now in DB: ${sink.count()}');
}

void _queryByLevel(final SqliteSink sink) {
  final counts = sink.fetchLevelCounts();

  print('┌─ [Option 2] Query Logs by Level');
  print('│  Live Database Summary:');
  print('│    [1] TRACE   (${counts[LogLevel.trace] ?? 0} records)');
  print('│    [2] DEBUG   (${counts[LogLevel.debug] ?? 0} records)');
  print('│    [3] INFO    (${counts[LogLevel.info] ?? 0} records)');
  final warnCount = counts[LogLevel.warning] ?? 0;
  print('│    [4] WARNING ($warnCount records) ★ Default');
  print('│    [5] ERROR   (${counts[LogLevel.error] ?? 0} records)');
  print('└─────────────────────────────────────────────────────────────');

  stdout.write(
    'Select Level [1-5 or TRACE/DEBUG/INFO/WARNING/ERROR] (default: 4): ',
  );
  final input = stdin.readLineSync()?.trim().toUpperCase() ?? '';

  LogLevel level = LogLevel.warning;
  if (input == '1' || input == 'TRACE') {
    level = LogLevel.trace;
  } else if (input == '2' || input == 'DEBUG') {
    level = LogLevel.debug;
  } else if (input == '3' || input == 'INFO') {
    level = LogLevel.info;
  } else if (input == '5' || input == 'ERROR') {
    level = LogLevel.error;
  }

  final results = sink.query().minLevel(level).limit(15).execute();
  final name = level.name.toUpperCase();
  print('\n🔍 Found ${results.length} log records with minLevel >= $name:');
  _renderLogTable(results);
}

void _queryByNamespace(final SqliteSink sink) {
  final namespaces = sink.fetchDistinctLoggerNames();

  print('┌─ [Option 3] Query Logs by Logger Namespace');
  if (namespaces.isEmpty) {
    print('│  (No logger namespaces discovered in DB yet)');
    print('└─────────────────────────────────────────────────────────────');
    return;
  }

  print('│  Discovered Namespaces in DB:');
  for (int i = 0; i < namespaces.length; i++) {
    final ns = namespaces[i]['logger_name'] as String;
    final cnt = namespaces[i]['record_count'];
    final defaultTag = i == 0 ? ' ★ Default' : '';
    print('│    [${i + 1}] $ns ($cnt records)$defaultTag');
  }
  print('└─────────────────────────────────────────────────────────────');

  final defaultNs = namespaces.first['logger_name'] as String;
  final maxNs = namespaces.length;
  stdout.write(
    'Select by number [1-$maxNs] or type pattern (default: 1 - $defaultNs): ',
  );
  final input = stdin.readLineSync()?.trim() ?? '';

  String targetNs = defaultNs;
  final numChoice = int.tryParse(input);
  if (numChoice != null && numChoice >= 1 && numChoice <= namespaces.length) {
    targetNs = namespaces[numChoice - 1]['logger_name'] as String;
  } else if (input.isNotEmpty) {
    targetNs = input;
  }

  final results = sink
      .query()
      .logger(targetNs, hierarchy: true)
      .limit(15)
      .execute();
  print(
    '\n🔍 Found ${results.length} log records under namespace "$targetNs":',
  );
  _renderLogTable(results);
}

void _queryBySearch(final SqliteSink sink) {
  print('┌─ [Option 4] Full-Text Search');
  print(
    '│  Suggested Keywords in DB: "timeout", "password", "StripeAPI", '
    '"USR-1005"',
  );
  print('└─────────────────────────────────────────────────────────────');

  stdout.write('Enter search keyword (default: timeout): ');
  final input = stdin.readLineSync()?.trim();
  final term = (input == null || input.isEmpty) ? 'timeout' : input;

  final results = sink.query().search(term).limit(15).execute();
  print('\n🔍 Found ${results.length} log records matching "$term":');
  _renderLogTable(results);
}

void _inspectRecord(final SqliteSink sink) {
  final totalCount = sink.count();
  if (totalCount == 0) {
    print('⚠️ Database is empty. Emit telemetry first (Option 1).');
    return;
  }

  final recentLogs = sink.query().limit(5).execute();
  final latestId = recentLogs.first.id;
  final oldestInDb = sink.query().limit(500).execute().last.id;

  print('┌─ [Option 5] Inspect Single Record Details');
  print(
    '│  Available Record IDs: #$oldestInDb to #$latestId (Total: $totalCount)',
  );

  print('│  Recent Records Preview:');
  for (final log in recentLogs) {
    final idStr = '#${log['id']}'.padRight(5);
    final lvl = log['level_name'].toString().toUpperCase().padRight(7);
    final logger = log['logger_name'];
    final msg = _truncate(log['message'].toString(), 30);
    print('│    • ID $idStr | [$lvl] $logger: $msg');
  }
  print('└─────────────────────────────────────────────────────────────');

  stdout.write('Enter Record ID to inspect [default: $latestId]: ');
  final input = stdin.readLineSync()?.trim() ?? '';
  final id = input.isEmpty ? latestId : int.tryParse(input);

  if (id == null) {
    print('⚠️ Invalid Record ID.');
    return;
  }

  final results = sink.query().limit(500).execute();
  final match = results.where((final r) => r.id == id).firstOrNull;

  if (match == null) {
    print('⚠️ Record ID #$id not found in current database window.');
    return;
  }

  const line =
      '==================================================='
      '=============================';
  print('\n$line');
  print('  INSPECT RECORD #$id');
  print(line);
  print('  ID:          ${match['id']}');
  print('  Timestamp:   ${match['timestamp']}');
  print('  Level:       ${match['level_name'].toString().toUpperCase()}');
  print('  Logger:      ${match['logger_name']}');
  print('  Origin:      ${match['origin']}');
  print('  Message:     ${match['message']}');
  print('  Context:     ${match['context_json'] ?? 'None'}');
  print('  Error:       ${match['error'] ?? 'None'}');

  if (match['stack_trace'] != null) {
    print('\n  [Stack Trace]');
    final traceLines = match['stack_trace'].toString().split('\n').take(6);
    for (final traceLine in traceLines) {
      print('    $traceLine');
    }
  }
  print('$line\n');
}

void _printStatistics(final SqliteSink sink, final String dbPath) {
  print('📊 DATABASE HEALTH & STATISTICS');
  print('  - Database Path: $dbPath');
  print('  - Total Log Count: ${sink.count()} records');
  print('  - Max Entries Limit: ${sink.maxEntries}');

  final file = File(dbPath);
  if (file.existsSync()) {
    final kb = (file.lengthSync() / 1024).toStringAsFixed(2);
    print('  - DB File Size: $kb KB');
  }
}

Future<void> _runThroughputBenchmark(final SqliteSink sink) async {
  print('⚡ Running Write Throughput Benchmark (1,000 log entries)...');

  final benchmarkLogger = Logger.get('benchmark');
  final stopwatch = Stopwatch()..start();

  for (int i = 1; i <= 1000; i++) {
    benchmarkLogger.info(
      'Benchmark payload entry #$i',
      context: {'index': i, 'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
  }

  await sink.flush();
  stopwatch.stop();

  final elapsedMs = stopwatch.elapsedMilliseconds;
  final opsPerSec = (1000 / (elapsedMs / 1000)).toStringAsFixed(0);

  print('✓ Benchmark Complete!');
  print('  - 1,000 Log Entries Written in: ${elapsedMs}ms');
  print('  - Estimated Throughput: $opsPerSec Ops/sec');
}

Future<void> _runMaintenanceMenu(
  final SqliteSink sink,
  final String dbPath,
) async {
  final file = File(dbPath);
  final sizeKb = file.existsSync()
      ? (file.lengthSync() / 1024).toStringAsFixed(2)
      : '0.00';

  print('┌─ [Option 8] Database Maintenance');
  print('│  Status: Stored Records: ${sink.count()} | DB Size: $sizeKb KB');
  print('│  Actions:');
  print('│    [1] Flush Pending Buffer');
  print('│    [2] Run VACUUM (Compacts storage file)');
  print('│    [3] Clear All Log Records');
  print('│    [0] Cancel & Return to Main Menu');
  print('└─────────────────────────────────────────────────────────────');

  stdout.write('Select action [0-3] (default: 0): ');
  final choice = stdin.readLineSync()?.trim() ?? '0';

  switch (choice) {
    case '1':
      await sink.flush();
      print('✓ Flush complete.');
    case '2':
      sink.vacuum();
      print('✓ Vacuum complete.');
    case '3':
      sink.clear();
      print('✓ All log records cleared. Count: ${sink.count()}');
    case '0':
    case '':
      print('ℹ Maintenance cancelled.');
    default:
      print('⚠️ Invalid maintenance action.');
  }
}

Future<void> _runAutomatedTour(final SqliteSink sink) async {
  print('🚀 Running Automated Dashboard Tour...');
  await _emitTelemetryBurst(sink, 20);

  print('\n🔍 Executing Sample Queries:');
  final results = sink.query().limit(5).execute();
  _renderLogTable(results);

  await _runThroughputBenchmark(sink);

  print('\n🧹 Cleaning up test database...');
  sink.clear();
  print('✓ Automated tour completed successfully!\n');
}

void _renderLogTable(final List<SqliteLogRecord> rows) {
  if (rows.isEmpty) {
    print('  (No records match query)');
    return;
  }

  const border =
      '┌─────┬─────────┬──────────────────┬'
      '──────────────────────────────────────────┐';
  const header =
      '│ ID  │ LEVEL   │ LOGGER           │'
      ' MESSAGE                                  │';
  const divider =
      '├─────┼─────────┼──────────────────┼'
      '──────────────────────────────────────────┤';
  const bottom =
      '└─────┴─────────┴──────────────────┴'
      '──────────────────────────────────────────┘';

  print(border);
  print(header);
  print(divider);

  for (final row in rows) {
    final id = row['id'].toString().padRight(4);
    final level = row['level_name'].toString().toUpperCase().padRight(7);
    final logger = _truncate(row['logger_name'].toString(), 16).padRight(16);
    final msg = _truncate(row['message'].toString(), 40).padRight(40);

    print('│ $id│ $level │ $logger │ $msg │');
  }

  print(bottom);
}

String _truncate(final String text, final int maxLength) {
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength - 3)}...';
}

void _pause() {
  if (stdioType(stdin) == StdioType.terminal) {
    stdout.write('\nPress Enter to return to main menu...');
    stdin.readLineSync();
    print('');
  }
}

Future<void> _cleanup(final SqliteSink sink, final String dbPath) async {
  await sink.dispose();

  for (final path in [dbPath, '$dbPath-shm', '$dbPath-wal']) {
    final f = File(path);
    if (f.existsSync()) {
      f.deleteSync();
    }
  }
}

void _printHeader(final String title) {
  const line =
      '==================================================='
      '=============================';
  print(line);
  print('  $title');
  print(line);
}
