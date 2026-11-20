// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:logd_sqlite/src/sqlite_isolate_handler.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    registerLogdSqliteSerializers();
  });

  group('SqliteHandler (ADR-006)', () {
    late Directory tempDir;
    late String testDbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_sqlite_test_');
      testDbPath = '${tempDir.path}/handler_test.db';
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('SqliteHandler.inMemory creates a valid Handler pipeline', () async {
      final handler = SqliteHandler.inMemory(
        batchSize: 1, // Flush immediately
      );

      expect(handler, isA<Handler>());
      expect(handler.formatter, isA<StructuredFormatter>());
      expect(handler.sink, isA<SqliteSink>());

      final entry = LogEntry(
        loggerName: 'test.sqlite_handler',
        origin: 'sqlite_handler_test.dart',
        level: LogLevel.info,
        message: 'Pre-wired SqliteHandler test',
        timestamp: '2026-08-16 12:00:00.000',
      );

      await handler.log(entry);

      final records = handler.sqliteSink.queryLogs();
      expect(records.length, equals(1));
      expect(records.first['message'], equals('Pre-wired SqliteHandler test'));

      await handler.dispose();
    });

    test('SqliteHandler.database wraps existing Database instance', () async {
      final db = sqlite3.openInMemory();
      final handler = SqliteHandler.database(database: db, batchSize: 1);

      final entry = LogEntry(
        loggerName: 'test.db_wrapper',
        origin: 'sqlite_handler_test.dart',
        level: LogLevel.warning,
        message: 'Wrapped DB event',
        timestamp: '2026-08-16 12:00:00.000',
      );

      await handler.log(entry);

      expect(handler.sqliteSink.count(), equals(1));
      await handler.dispose();
    });

    test('SqliteHandler.async creates a background isolate handler', () async {
      final handler = SqliteHandler.async(path: testDbPath, batchSize: 1);

      expect(handler, isA<Handler>());

      Logger.configure('test.sqlite_async', handlers: [handler]);
      final logger = Logger.get('test.sqlite_async');

      await (handler as SqliteIsolateHandler).ready;

      logger.info('Async SQLite log entry');

      await handler.dispose();
      await Future.delayed(const Duration(milliseconds: 100));

      final file = File(testDbPath);
      expect(file.existsSync(), isTrue);

      final db = sqlite3.open(testDbPath);
      final results = db.select('SELECT * FROM logs;');
      expect(results.length, equals(1));
      expect(results.first['message'], equals('Async SQLite log entry'));
      db.close();
    });
  });

  // ---------------------------------------------------------------------------
  // Regression: isolate boundary (ADR-006 / fix for "object is unsendable")
  // ---------------------------------------------------------------------------
  // These tests validate the invariant: SqliteSink must NOT be transferred
  // across isolate boundaries (it holds a native FFI handle and active Timer),
  // and SqliteIsolateHandler must correctly deliver logs end-to-end by
  // constructing its SqliteSink fresh inside the background isolate.
  // ---------------------------------------------------------------------------
  group('Regression: SqliteHandler.async isolate boundary', () {
    late Directory tempDir;
    late String testDbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_sqlite_regress_');
      testDbPath = '${tempDir.path}/regress.db';
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test(
      'SqliteSink directly passed to AsyncHandler throws unsendable error',
      () async {
        // This documents the OLD broken behavior. The eager-initialized
        // SqliteSink holds a native sqlite3.Database handle and an active
        // Timer, both of which are non-transferable across isolate boundaries.
        //
        // AsyncHandler spawns the isolate asynchronously in _start(). The
        // error ("Illegal argument in isolate message: object is unsendable")
        // surfaces on the _worker.ready Completer AND leaks as an unhandled
        // async error from the _start() fire-and-forget. We capture both
        // with runZonedGuarded to prevent the leak from failing the test frame.
        final sink = SqliteSink(
          dbPath: testDbPath,
          batchSize: 50,
          flushInterval: null, // Disable timer to isolate the DB-handle issue
          walMode: false,
        );

        late AsyncHandler handler;
        Object? capturedZoneError;

        await runZonedGuarded(() async {
          handler = AsyncHandler(
            formatter: const StructuredFormatter(),
            sink: sink,
            decorators: const [],
          );

          // ready completes with the isolate transfer error.
          await expectLater(
            handler.ready,
            throwsA(
              predicate<dynamic>((final e) {
                final msg = e.toString().toLowerCase();
                return msg.contains('unsendable') ||
                    msg.contains('illegal argument') ||
                    msg.contains('isolate');
              }),
            ),
          );
        }, (final e, final _) => capturedZoneError = e);

        // The zone error (the leaked async error) should also be about isolate
        // sendability — confirming the same root cause surfaced on both paths.
        if (capturedZoneError != null) {
          final msg = capturedZoneError.toString().toLowerCase();
          expect(
            msg.contains('unsendable') ||
                msg.contains('illegal argument') ||
                msg.contains('isolate'),
            isTrue,
            reason: 'Zone error should be the isolate transfer error',
          );
        }

        await sink.dispose();
      },
    );

    test(
      'SqliteHandler.async writes multiple entries end-to-end across isolate',
      () async {
        // This validates the FIXED behavior. SqliteIsolateHandler passes only
        // plain-data config across the boundary and constructs SqliteSink
        // fresh inside the worker isolate — no native handles are transferred.
        const entryCount = 5;

        final handler = SqliteHandler.async(
          path: testDbPath,
          batchSize: 1, // flush immediately on each log
        );

        await (handler as SqliteIsolateHandler).ready;

        Logger.configure('test.regress.async', handlers: [handler]);
        final logger = Logger.get('test.regress.async');

        for (var i = 0; i < entryCount; i++) {
          logger.info('Regression entry $i');
        }

        // dispose() flushes the sink and closes the DB inside the worker.
        await handler.dispose();

        // Verify all entries landed in the database file.
        expect(File(testDbPath).existsSync(), isTrue);

        final db = sqlite3.open(testDbPath);
        final rows = db.select('SELECT message FROM logs ORDER BY id;');
        db.close();

        expect(rows.length, equals(entryCount));
        for (var i = 0; i < entryCount; i++) {
          expect(rows[i]['message'], equals('Regression entry $i'));
        }
      },
    );

    test(
      'SqliteHandler.async persists correct log level and logger name',
      () async {
        final handler = SqliteHandler.async(path: testDbPath, batchSize: 1);

        await (handler as SqliteIsolateHandler).ready;

        Logger.configure('test.regress.meta', handlers: [handler]);
        Logger.get('test.regress.meta').warning('Level fidelity check');
        await handler.dispose();

        final db = sqlite3.open(testDbPath);
        final rows = db.select('SELECT * FROM logs;');
        db.close();

        expect(rows.length, equals(1));
        final row = rows.first;
        expect(row['level_name'], equals('warning'));
        expect(row['logger_name'], equals('test.regress.meta'));
        expect(row['message'], equals('Level fidelity check'));
      },
    );
  });
}
