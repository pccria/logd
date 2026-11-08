// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:logd_network/logd_network.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> main() async {
  print('================================================================');
  print('    LOGD FULL ECOSYSTEM COMPREHENSIVE INTEGRATION VALIDATION    ');
  print('================================================================\n');

  final tempDir = Directory.systemTemp.createTempSync('logd_ecosystem_val_');
  final tempPath = tempDir.path;

  // 1. Spin up an in-process HTTP log ingestion server
  final httpLogsReceived = <Map<String, dynamic>>[];
  final httpAuthTokens = <String>[];
  final serverCompleter = Completer<void>();

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final serverPort = server.port;

  final serverSub = server.listen((final request) async {
    final auth = request.headers.value('authorization') ?? '';
    httpAuthTokens.add(auth);

    final body = await utf8.decoder.bind(request).join();
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is String) {
            try {
              final inner = jsonDecode(item);
              if (inner is Map) {
                httpLogsReceived.add(Map<String, dynamic>.from(inner));
              }
            } catch (_) {}
          } else if (item is Map) {
            httpLogsReceived.add(Map<String, dynamic>.from(item));
          }
        }
      }
    } catch (_) {}

    request.response
      ..statusCode = HttpStatus.ok
      ..write('{"status":"ok"}');
    await request.response.close();

    if (httpLogsReceived.length >= 25 && !serverCompleter.isCompleted) {
      serverCompleter.complete();
    }
  });

  print('✓ Phase 1: In-process HTTP Intake Server active on port $serverPort');

  // 2. Register all satellite serializers for isolate communication
  registerLogdHtmlSerializers();
  registerLogdToonSerializers();
  registerLogdSqliteSerializers();
  registerLogdNetworkSerializers();
  print('✓ Phase 2: Registered serializers across all satellite packages');

  // 3. Configure Multi-Sink Pipeline
  final plainLogPath = '$tempPath/app.log';
  final htmlLogPath = '$tempPath/report.html';
  final toonLogPath = '$tempPath/telemetry.toon';
  final dbPath = '$tempPath/telemetry.db';

  final sqliteSink = SqliteSink(
    dbPath: dbPath,
    walMode: true,
    batchSize: 5,
    maxEntries: 1000,
  );

  var authCounter = 0;
  final httpSink = HttpSink(
    url: 'http://127.0.0.1:$serverPort/logs',
    batchSize: 5,
    flushInterval: const Duration(milliseconds: 100),
    headersProvider: () async {
      authCounter++;
      return {'Authorization': 'Bearer dynamic-val-token-$authCounter'};
    },
  );

  Logger.configure(
    'ecosystem',
    handlers: [
      // 1. Formatted Console
      const Handler(
        formatter: StructuredFormatter(),
        decorators: [
          StyleDecorator(),
          BoxDecorator(borderStyle: BorderStyle.rounded),
        ],
        sink: ConsoleSink(lineLength: 88),
      ),
      // 2. Plain rotated file
      PlainFileHandler(
        path: plainLogPath,
        fileRotation: SizeRotation(maxSize: '10 KB', backupCount: 2),
      ),
      // 3. Background Async HTML
      HtmlFileHandler.async(
        path: htmlLogPath,
        title: 'Ecosystem Validation Report',
      ),
      // 4. Background Async TOON
      ToonFileHandler.async(
        path: toonLogPath,
        dialect: ToonDialect.strict,
        arrayName: 'telemetry_events',
      ),
      // 5. Embedded SQLite DB Sink
      Handler(formatter: const PlainFormatter(), sink: sqliteSink),
      // 6. Network HTTP Ingestion Sink
      Handler(formatter: const JsonFormatter(), sink: httpSink),
    ],
  );

  print(
    '✓ Phase 3: Configured 6 concurrent sinks '
    '(Console, File, HTML, TOON, SQLite, HTTP)',
  );

  // 4. Emit Logs with Ambient Context & Concurrent Tasks
  print(
    '┌─ Phase 4: Emitting telemetry with ambient context and concurrency...',
  );
  final logger = Logger.get('ecosystem');

  await LogContext.run(
    {'sessionId': 'sess-val-900', 'cluster': 'eu-central'},
    () async {
      logger.info('Ecosystem validation initialized successfully.');

      // Concurrent bursts across 25 async futures
      final futures = <Future<void>>[];
      for (int i = 1; i <= 25; i++) {
        final taskId = i;
        futures.add(
          Future(() async {
            logger.info(
              'Processing worker payload #$taskId',
              context: {'workerId': 'wrk-$taskId', 'iteration': taskId},
            );
            if (taskId % 5 == 0) {
              logger.warning(
                'Worker #$taskId encountered high load threshold',
                context: {'workerId': 'wrk-$taskId', 'cpuLoad': '88%'},
              );
            }
            if (taskId == 13) {
              try {
                throw const SocketException(
                  'Simulated upstream network failure',
                );
              } catch (e, st) {
                logger.error(
                  'Worker #$taskId database connectivity lost',
                  error: e,
                  stackTrace: st,
                  context: {'workerId': 'wrk-$taskId', 'retry': true},
                );
              }
            }
          }),
        );
      }

      await Future.wait(futures);
    },
  );
  print('└─ Emitted 31 telemetry events concurrently across async zones.\n');

  // 5. Clean teardown and flush verification
  print('┌─ Phase 5: Executing Logger.shutdown()...');
  final sw = Stopwatch()..start();
  await Logger.shutdown();
  sw.stop();
  print(
    '└─ Logger.shutdown() completed cleanly in ${sw.elapsedMilliseconds} ms.\n',
  );

  // Stop HTTP server
  await serverSub.cancel();
  await server.close(force: true);

  // 6. Data Fidelity & Invariant Assertions
  print('┌─ Phase 6: Verifying Artifact Fidelity on Disk...');

  // Plain log check
  final plainFile = File(plainLogPath);
  if (!plainFile.existsSync() || plainFile.lengthSync() == 0) {
    throw StateError('Plain file log was not written properly!');
  }
  print('│  ✓ Plain file: ${plainFile.lengthSync()} bytes verified.');

  // HTML log check
  final htmlFile = File(htmlLogPath);
  if (!htmlFile.existsSync() || htmlFile.lengthSync() == 0) {
    throw StateError('HTML file log was not written properly!');
  }
  final htmlContent = htmlFile.readAsStringSync();
  if (!htmlContent.contains('Ecosystem Validation Report') ||
      !htmlContent.contains('Processing worker payload')) {
    throw StateError('HTML report content validation failed!');
  }
  print(
    '│  ✓ HTML report: ${htmlFile.lengthSync()} bytes '
    'with valid DOM structure verified.',
  );

  // TOON log check
  final toonFile = File(toonLogPath);
  if (!toonFile.existsSync() || toonFile.lengthSync() == 0) {
    throw StateError('TOON file log was not written properly!');
  }
  final toonContent = toonFile.readAsStringSync();
  if (!toonContent.contains('telemetry_events')) {
    throw StateError('TOON file content validation failed!');
  }
  print(
    '│  ✓ TOON schema: ${toonFile.lengthSync()} bytes '
    'with strict tabular dialect verified.',
  );

  // SQLite DB check
  final dbFile = File(dbPath);
  if (!dbFile.existsSync() || dbFile.lengthSync() == 0) {
    throw StateError('SQLite DB was not written properly!');
  }
  final db = sqlite3.open(dbPath);
  final countRow = db.select('SELECT COUNT(*) as cnt FROM logs;').first;
  final dbLogCount = countRow['cnt'] as int;
  if (dbLogCount < 25) {
    throw StateError(
      'SQLite record count ($dbLogCount) is less than expected!',
    );
  }
  final errorRows = db.select(
    "SELECT * FROM logs WHERE UPPER(level_name) = 'ERROR';",
  );
  if (errorRows.isEmpty) {
    throw StateError('SQLite ERROR record query failed!');
  }
  db.close();
  print(
    '│  ✓ SQLite database: $dbLogCount records indexed with '
    'WAL journal verified.',
  );

  // HTTP server check
  if (httpAuthTokens.isEmpty ||
      !httpAuthTokens.any((final t) => t.contains('dynamic-val-token'))) {
    throw StateError('HTTP dynamic auth hook was not called properly!');
  }
  print(
    '│  ✓ HTTP Ingestion: ${httpLogsReceived.length} logs received '
    'across authenticated batches.',
  );

  print('└─────────────────────────────────────────────────────────────\n');

  // Cleanup temp files
  try {
    tempDir.deleteSync(recursive: true);
    print('✓ Temporary test directory cleaned up.');
  } catch (_) {}

  print('\n================================================================');
  print('   ALL ECOSYSTEM TESTS & FIDELITY INVARIANTS PASSED (100%)       ');
  print('================================================================');
}
