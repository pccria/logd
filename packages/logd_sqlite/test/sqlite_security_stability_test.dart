// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

class _CustomNonEncodable {
  @override
  String toString() => 'CustomObject(name: test_payload)';
}

void main() {
  group('SqliteSink Security & Memory Safety Suite', () {
    late Database memoryDb;
    late LogPipelineFactory factory;

    setUp(() {
      memoryDb = sqlite3.openInMemory();
      factory = const StandardPipelineFactory();
    });

    tearDown(() {
      try {
        memoryDb.close();
      } catch (_) {}
    });

    test('validates and rejects malicious or invalid table names', () {
      expect(
        () => SqliteSink(
          database: memoryDb,
          tableName: 'logs; DROP TABLE users; --',
        ),
        throwsArgumentError,
      );

      expect(
        () => SqliteSink(
          database: memoryDb,
          tableName: 'invalid-table-hyphen',
        ),
        throwsArgumentError,
      );

      expect(
        () => SqliteSink(
          database: memoryDb,
          tableName: '123_starts_with_number',
        ),
        throwsArgumentError,
      );

      expect(
        () => SqliteSink(
          database: memoryDb,
          tableName: "logs' OR '1'='1",
        ),
        throwsArgumentError,
      );

      // Valid identifiers should not throw
      final validSink = SqliteSink(
        database: memoryDb,
        tableName: 'valid_app_logs_2026',
      );
      expect(validSink.tableName, equals('valid_app_logs_2026'));
      validSink.dispose();
    });

    test('validates positive limits for maxEntries and maxBufferSize', () {
      expect(
        () => SqliteSink(database: memoryDb, maxEntries: 0),
        throwsArgumentError,
      );
      expect(
        () => SqliteSink(database: memoryDb, maxEntries: -10),
        throwsArgumentError,
      );
      expect(
        () => SqliteSink(database: memoryDb, maxBufferSize: 0),
        throwsArgumentError,
      );
      expect(
        () => SqliteSink(database: memoryDb, maxBufferSize: -5),
        throwsArgumentError,
      );
    });

    test('safely handles non-JSON-encodable context objects without crashing',
        () async {
      final sink = SqliteSink(
        database: memoryDb,
        batchSize: 1,
      );
      final doc = StandardDocument();
      final entry = LogEntry(
        message: 'Log with complex context',
        loggerName: 'security.test',
        origin: 'sqlite_security_stability_test.dart',
        level: LogLevel.info,
        timestamp: '2026-10-23 12:00:00',
        context: {
          'date': DateTime(2026, 10, 23),
          'custom': _CustomNonEncodable(),
        },
      );

      await expectLater(
        sink.output(doc, entry, LogLevel.info, factory),
        completes,
      );

      final logs = sink.queryLogs();
      expect(logs.length, equals(1));
      expect(logs.first['context_json'], contains('CustomObject'));
      expect(logs.first['context_json'], contains('2026-10-23'));

      await sink.dispose();
    });

    test('enforces maxBufferSize memory backpressure by evicting oldest logs',
        () async {
      final sink = SqliteSink(
        database: memoryDb,
        batchSize: 100, // Never auto-flush by batch
        flushInterval: null, // No timer flush
        maxBufferSize: 3, // Only hold up to 3 items in memory
      );
      final doc = StandardDocument();

      for (int i = 1; i <= 5; i++) {
        await sink.output(
          doc,
          LogEntry(
            message: 'Log #$i',
            loggerName: 'pressure',
            origin: 'test',
            level: LogLevel.info,
            timestamp: '2026-10-23 12:00:00',
          ),
          LogLevel.info,
          factory,
        );
      }

      // QueryLogs forces flushSync: only items #3, #4, #5 should be present
      final logs = sink.queryLogs();
      expect(logs.length, equals(3));
      final messages = logs.map((final row) => row['message']).toList();
      expect(messages, contains('Log #3'));
      expect(messages, contains('Log #4'));
      expect(messages, contains('Log #5'));
      expect(messages.contains('Log #1'), isFalse);
      expect(messages.contains('Log #2'), isFalse);

      await sink.dispose();
    });

    test('concurrent flush calls do not cause transaction collision', () async {
      final sink = SqliteSink(
        database: memoryDb,
        batchSize: 100,
        flushInterval: null,
      );
      final doc = StandardDocument();

      for (int i = 1; i <= 10; i++) {
        await sink.output(
          doc,
          LogEntry(
            message: 'Concurrency test #$i',
            loggerName: 'concurrency',
            origin: 'test',
            level: LogLevel.info,
            timestamp: '2026-10-23 12:00:00',
          ),
          LogLevel.info,
          factory,
        );
      }

      // Parallel flushes should execute safely without collision
      await expectLater(
        Future.wait([sink.flush(), sink.flush(), sink.flush()]),
        completes,
      );

      expect(sink.count(), equals(10));
      await sink.dispose();
    });

    test('queryLogs reflects uncommitted buffered entries synchronously',
        () async {
      final sink = SqliteSink(
        database: memoryDb,
        batchSize: 50,
        flushInterval: null,
      );
      final doc = StandardDocument();

      await sink.output(
        doc,
        LogEntry(
          message: 'Immediate buffered check',
          loggerName: 'sync.test',
          origin: 'test',
          level: LogLevel.info,
          timestamp: '2026-10-23 12:00:00',
        ),
        LogLevel.info,
        factory,
      );

      // Query without explicit flush should return the entry immediately
      final logs = sink.queryLogs(loggerName: 'sync.test');
      expect(logs.length, equals(1));
      expect(logs.first['message'], equals('Immediate buffered check'));

      await sink.dispose();
    });

    test('worker isolate initialization failure propagates to ready future',
        () async {
      final handler = SqliteHandler.async(
        path: ':memory:',
        tableName: 'bad table name with spaces;',
      );

      await expectLater(
        (handler as dynamic).ready as Future<void>,
        throwsA(isA<StateError>()),
      );

      await expectLater(
        handler.dispose(),
        completes,
      );
    });
  });
}
