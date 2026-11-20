// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteSink Production Suite', () {
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

    test(
      'should persist complete log entry fidelity with batch flush',
      () async {
        final sink = SqliteSink(
          database: memoryDb,
          batchSize: 1, // immediate flush for test
        );
        final doc = StandardDocument();
        final entry = LogEntry(
          message: 'Failed to process payment transaction',
          loggerName: 'payment.gateway',
          origin: 'PaymentGateway.process',
          level: LogLevel.error,
          timestamp: '2026-08-07 16:00:00',
          error: StateError('Network timeout'),
          stackTrace: StackTrace.current,
          context: {'orderId': 'ORD-9982', 'amount': 150.50},
        );

        await sink.output(doc, entry, LogLevel.error, factory);

        final logs = sink.queryLogs();
        expect(logs.length, equals(1));

        final log = logs.first;
        expect(log['message'], equals('Failed to process payment transaction'));
        expect(log['logger_name'], equals('payment.gateway'));
        expect(log['origin'], equals('PaymentGateway.process'));
        expect(log['level_name'], equals('error'));
        expect(log['error'], contains('Network timeout'));
        expect(log['stack_trace'], contains('sqlite_sink_test.dart'));
        expect(log['context_json'], contains('ORD-9982'));
      },
    );

    test('should auto-flush when batchSize capacity is reached', () async {
      final sink = SqliteSink(
        database: memoryDb,
        batchSize: 3,
        flushInterval: null,
      );
      final doc = StandardDocument();

      for (int i = 1; i <= 2; i++) {
        await sink.output(
          doc,
          LogEntry(
            message: 'Message #$i',
            loggerName: 'app',
            origin: 'main',
            level: LogLevel.info,
            timestamp: '2026-08-07 16:00:00',
          ),
          LogLevel.info,
          factory,
        );
      }

      // Batch size is 3, so 2 entries are still buffered in memory
      expect(sink.count(), equals(2));

      // 3rd item triggers batch flush
      await sink.output(
        doc,
        LogEntry(
          message: 'Message #3',
          loggerName: 'app',
          origin: 'main',
          level: LogLevel.info,
          timestamp: '2026-08-07 16:00:00',
        ),
        LogLevel.info,
        factory,
      );

      expect(sink.count(), equals(3));
    });

    test(
      'should query logs by minLevel, loggerName, and search term',
      () async {
        final sink = SqliteSink(database: memoryDb, batchSize: 1);
        final doc = StandardDocument();

        await sink.output(
          doc,
          LogEntry(
            message: 'User logged in successfully',
            loggerName: 'auth.service',
            origin: 'Auth.login',
            level: LogLevel.info,
            timestamp: '2026-08-07 16:00:00',
          ),
          LogLevel.info,
          factory,
        );

        await sink.output(
          doc,
          LogEntry(
            message: 'Invalid password attempt',
            loggerName: 'auth.service',
            origin: 'Auth.login',
            level: LogLevel.warning,
            timestamp: '2026-08-07 16:00:05',
          ),
          LogLevel.warning,
          factory,
        );

        await sink.output(
          doc,
          LogEntry(
            message: 'Database connection failed',
            loggerName: 'db.service',
            origin: 'Db.connect',
            level: LogLevel.error,
            timestamp: '2026-08-07 16:00:10',
          ),
          LogLevel.error,
          factory,
        );

        // Filter by minLevel warning
        final warningsAndErrors = sink.queryLogs(minLevel: LogLevel.warning);
        expect(warningsAndErrors.length, equals(2));

        // Filter by loggerName 'auth.service'
        final authLogs = sink.queryLogs(loggerName: 'auth.service');
        expect(authLogs.length, equals(2));

        // Filter by search keyword 'Database'
        final dbSearch = sink.queryLogs(search: 'Database');
        expect(dbSearch.length, equals(1));
        expect(dbSearch.first['logger_name'], equals('db.service'));

        // Test level breakdown summary helper
        final levelCounts = sink.fetchLevelCounts();
        expect(levelCounts[LogLevel.info], equals(1));
        expect(levelCounts[LogLevel.warning], equals(1));
        expect(levelCounts[LogLevel.error], equals(1));

        // Test distinct logger names helper
        final distinctLoggers = sink.fetchDistinctLoggerNames();
        expect(distinctLoggers.length, equals(2));
        final names = distinctLoggers
            .map((final l) => l['logger_name'])
            .toList();

        expect(names, containsAll(['auth.service', 'db.service']));
      },
    );

    test('should apply maxEntries retention policy on flush', () async {
      final sink = SqliteSink(database: memoryDb, maxEntries: 3, batchSize: 1);
      final doc = StandardDocument();

      for (int i = 1; i <= 5; i++) {
        await sink.output(
          doc,
          LogEntry(
            message: 'Event #$i',
            loggerName: 'app',
            origin: 'main',
            level: LogLevel.debug,
            timestamp: '2026-08-07 16:00:00',
          ),
          LogLevel.debug,
          factory,
        );
      }

      expect(sink.count(), equals(3));
      final logs = sink.queryLogs();
      final messages = logs.map((final l) => l['message']).toList();
      expect(messages, containsAll(['Event #5', 'Event #4', 'Event #3']));
      expect(messages, isNot(contains('Event #1')));
    });

    test('should support clear, count, and vacuum utilities', () async {
      final sink = SqliteSink(database: memoryDb, batchSize: 1);
      final doc = StandardDocument();

      await sink.output(
        doc,
        LogEntry(
          message: 'Test log',
          loggerName: 'test',
          origin: 'test',
          level: LogLevel.info,
          timestamp: '2026-08-07 16:00:00',
        ),
        LogLevel.info,
        factory,
      );

      expect(sink.count(), equals(1));

      sink.clear();
      expect(sink.count(), equals(0));

      expect(() => sink.vacuum(), returnsNormally);
    });

    test(
      'should flush remaining batch and dispose DB handle cleanly',
      () async {
        final sink = SqliteSink(
          database: memoryDb,
          batchSize: 100, // buffered in memory
        );
        final doc = StandardDocument();

        await sink.output(
          doc,
          LogEntry(
            message: 'Buffered log before dispose',
            loggerName: 'test',
            origin: 'test',
            level: LogLevel.info,
            timestamp: '2026-08-07 16:00:00',
          ),
          LogLevel.info,
          factory,
        );

        // Disposing should flush the buffered log to DB before closing handle
        await sink.dispose();
        expect(() => sink.count(), throwsStateError);
      },
    );
  });
}
