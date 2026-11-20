// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteLogQuery Type-Safe Builder Suite', () {
    late Database memoryDb;
    late LogPipelineFactory factory;
    late SqliteSink sink;

    setUp(() async {
      memoryDb = sqlite3.openInMemory();
      factory = const StandardPipelineFactory();
      sink = SqliteSink(database: memoryDb, batchSize: 1);
      final doc = StandardDocument();

      // Seed test records
      for (int i = 1; i <= 10; i++) {
        final level = switch (i % 5) {
          1 => LogLevel.trace,
          2 => LogLevel.debug,
          3 => LogLevel.info,
          4 => LogLevel.warning,
          _ => LogLevel.error,
        };
        final logger = i <= 5 ? 'app.network' : 'app.database';
        await sink.output(
          doc,
          LogEntry(
            message: 'Event #$i payload message',
            loggerName: logger,
            origin: 'Test.run',
            level: level,
            timestamp: '2026-11-20 12:00:0$i',
            context: {'userId': 'USR-$i', 'index': i, 'even': i % 2 == 0},
          ),
          level,
          factory,
        );
      }
    });

    tearDown(() async {
      await sink.dispose();
    });

    test('filters by minimum and maximum severity levels', () {
      final warningsAndErrors = sink
          .query()
          .minLevel(LogLevel.warning)
          .execute();
      expect(warningsAndErrors.length, equals(4)); // indices 4, 5, 9, 10
      for (final r in warningsAndErrors) {
        expect(r.levelIndex, greaterThanOrEqualTo(LogLevel.warning.index));
      }

      final debugAndBelow = sink.query().maxLevel(LogLevel.debug).execute();
      expect(debugAndBelow.length, equals(4)); // indices 1, 2, 6, 7
      for (final r in debugAndBelow) {
        expect(r.levelIndex, lessThanOrEqualTo(LogLevel.debug.index));
      }
    });

    test('filters by exact level set', () {
      final errorsOnly = sink.query().level(LogLevel.error).execute();
      expect(errorsOnly.length, equals(2)); // indices 5, 10

      final traceAndError = sink.query().levelsFilter([
        LogLevel.trace,
        LogLevel.error,
      ]).execute();
      expect(traceAndError.length, equals(4)); // indices 1, 5, 6, 10
    });

    test('filters by exact logger and hierarchical namespace', () {
      final exactNetwork = sink.query().logger('app.network').execute();
      expect(exactNetwork.length, equals(5));

      final prefixApp = sink.query().logger('app', hierarchy: true).execute();
      expect(prefixApp.length, equals(10));

      final nonExistent = sink.query().logger('app.unknown').execute();
      expect(nonExistent.length, equals(0));
    });

    test('extracts structured JSON context fields', () {
      final userRecord = sink
          .query()
          .whereContext('userId', 'USR-3')
          .fetchFirst();
      expect(userRecord, isNotNull);
      expect(userRecord!.message, contains('#3'));

      final evenRecords = sink.query().whereContext('even', true).execute();
      expect(evenRecords.length, equals(5));

      final intMatched = sink.query().whereContext('index', 7).execute();
      expect(intMatched.length, equals(1));
      expect(intMatched.first.message, contains('#7'));
    });

    test(
      'navigates with keyset cursor pagination without OFFSET degradation',
      () {
        // Descending (newest first, IDs 10..1): afterId(6) gives IDs 5..1
        final olderThanSix = sink.query().afterId(6).execute();
        expect(olderThanSix.length, equals(5));
        expect(olderThanSix.first.id, equals(5));
        expect(olderThanSix.last.id, equals(1));

        // Descending: beforeId(6) gives IDs 10..7
        final newerThanSix = sink.query().beforeId(6).execute();
        expect(newerThanSix.length, equals(4));
        expect(newerThanSix.first.id, equals(10));
        expect(newerThanSix.last.id, equals(7));

        // Ascending order: afterId(6) gives IDs 7..10
        final ascendingAfterSix = sink
            .query()
            .orderBy(SqliteSortField.id, SqliteSortOrder.ascending)
            .afterId(6)
            .execute();
        expect(ascendingAfterSix.length, equals(4));
        expect(ascendingAfterSix.first.id, equals(7));
        expect(ascendingAfterSix.last.id, equals(10));
      },
    );

    test('supports limit, count, and delete on query specifications', () {
      expect(sink.query().limit(3).execute().length, equals(3));
      expect(sink.query().logger('app.network').count(), equals(5));

      final deletedCount = sink.query().logger('app.network').delete();
      expect(deletedCount, equals(5));
      expect(sink.count(), equals(5));
      expect(sink.query().logger('app.network').count(), equals(0));
    });

    test('standalone query object executes cleanly against sink', () {
      const query = SqliteLogQuery(loggerName: 'app.database', limitCount: 2);

      final records = query.execute(sink);
      expect(records.length, equals(2));
      expect(records.first.loggerName, equals('app.database'));
    });
  });
}
