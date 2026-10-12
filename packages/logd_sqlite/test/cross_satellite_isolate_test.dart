// ignore_for_file: invalid_use_of_internal_member

import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:logd_markdown/logd_markdown.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late String dbPath;

  setUp(() {
    final now = DateTime.now().microsecondsSinceEpoch;
    dbPath = '${Directory.systemTemp.path}/test_cross_isolate_$now.db';
  });

  tearDown(() {
    final file = File(dbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  group('Cross-Satellite Isolate Matrix Tests', () {
    test(
      'SqliteHandler.async persists with MarkdownFormatter and PrefixDecorator',
      () async {
        final handler = SqliteHandler.async(
          path: dbPath,
          batchSize: 1,
          flushInterval: const Duration(milliseconds: 50),
          formatter: const MarkdownFormatter(),
          decorators: [
            const PrefixDecorator('[AUDIT] '),
          ],
        );

        final entry = LogEntry(
          level: LogLevel.info,
          message: 'Markdown decorated message',
          loggerName: 'satellite.md',
          timestamp: '2026-09-21T00:00:00.000Z',
          origin: 'matrix_test.dart:45',
        );

        await handler.log(entry);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await handler.dispose();

        final db = sqlite3.open(dbPath);
        try {
          final results = db.select('SELECT * FROM logs');
          expect(results, hasLength(1));
          final row = results.first;
          expect(row['message'], equals('Markdown decorated message'));
          expect(row['logger_name'], equals('satellite.md'));
          expect(row['level_name'], equals('info'));
        } finally {
          db.close();
        }
      },
    );

    test('SqliteHandler.async persists with ToonFormatter', () async {
      final handler = SqliteHandler.async(
        path: dbPath,
        batchSize: 1,
        flushInterval: const Duration(milliseconds: 50),
        formatter: const ToonFormatter(),
      );

      final entry = LogEntry(
        level: LogLevel.warning,
        message: 'Toon formatted log message',
        loggerName: 'satellite.toon',
        timestamp: '2026-09-21T00:00:00.000Z',
        origin: 'matrix_test.dart:78',
      );

      await handler.log(entry);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await handler.dispose();

      final db = sqlite3.open(dbPath);
      try {
        final results = db.select('SELECT * FROM logs');
        expect(results, hasLength(1));
        final row = results.first;
        expect(row['message'], equals('Toon formatted log message'));
        expect(row['logger_name'], equals('satellite.toon'));
        expect(row['level_name'], equals('warning'));
      } finally {
        db.close();
      }
    });

    test('SqliteHandler.async persists with HtmlFormatter', () async {
      final handler = SqliteHandler.async(
        path: dbPath,
        batchSize: 1,
        flushInterval: const Duration(milliseconds: 50),
        formatter: const HtmlFormatter(title: 'Isolate HTML Audit'),
      );

      final entry = LogEntry(
        level: LogLevel.error,
        message: 'Html formatted error',
        loggerName: 'satellite.html',
        timestamp: '2026-09-21T00:00:00.000Z',
        origin: 'matrix_test.dart:110',
      );

      await handler.log(entry);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await handler.dispose();

      final db = sqlite3.open(dbPath);
      try {
        final results = db.select('SELECT * FROM logs');
        expect(results, hasLength(1));
        final row = results.first;
        expect(row['message'], equals('Html formatted error'));
        expect(row['logger_name'], equals('satellite.html'));
        expect(row['level_name'], equals('error'));
      } finally {
        db.close();
      }
    });
  });

  group('Concurrency and Lifecycle Resilience', () {
    test('Burst logging of 100 concurrent entries across isolate', () async {
      final handler = SqliteHandler.async(
        path: dbPath,
        batchSize: 50,
        flushInterval: const Duration(milliseconds: 100),
        formatter: const MarkdownFormatter(),
      );

      const count = 100;
      final futures = <Future<void>>[];
      for (var i = 0; i < count; i++) {
        final entry = LogEntry(
          level: LogLevel.info,
          message: 'Burst item $i',
          loggerName: 'stress.logger',
          timestamp: '2026-09-21T00:00:00.000Z',
          origin: 'burst.dart:$i',
        );
        futures.add(handler.log(entry));
      }

      await Future.wait(futures);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await handler.dispose();

      final db = sqlite3.open(dbPath);
      try {
        final results = db.select('SELECT count(*) as total FROM logs');
        expect(results.first['total'], equals(count));
      } finally {
        db.close();
      }
    });

    test('Pre-ready immediate disposal does not throw or leak isolate',
        () async {
      final handler = SqliteHandler.async(
        path: dbPath,
        formatter: const MarkdownFormatter(),
      );

      final entry = LogEntry(
        level: LogLevel.info,
        message: 'Pre-ready log',
        loggerName: 'preready',
        timestamp: '2026-09-21T00:00:00.000Z',
        origin: 'preready.dart:1',
      );

      // Log immediately and immediately dispose without waiting for ready
      final logFuture = handler.log(entry);
      final disposeFuture = handler.dispose();

      await expectLater(
        Future.wait([logFuture, disposeFuture]),
        completes,
      );
    });
  });
}
