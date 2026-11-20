// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteSink FTS5 Full-Text Search Suite', () {
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

    test('probes and initializes FTS5 virtual table and triggers', () {
      final sink = SqliteSink(database: memoryDb, enableFts: true);

      expect(sink.isFts5Available, isTrue);

      final tables = memoryDb.select(
        "SELECT name FROM sqlite_master WHERE type='table';",
      );
      final names = tables.map((final r) => r['name'] as String).toList();
      expect(names, contains('logs_fts'));

      final triggers = memoryDb.select(
        "SELECT name FROM sqlite_master WHERE type='trigger';",
      );
      final triggerNames = triggers
          .map((final r) => r['name'] as String)
          .toList();
      expect(triggerNames, containsAll(['logs_ai', 'logs_ad', 'logs_au']));
    });

    test(
      'performs BM25 ranked search and snippet extraction via FTS5',
      () async {
        final sink = SqliteSink(
          database: memoryDb,
          batchSize: 1,
          enableFts: true,
        );
        final doc = StandardDocument();

        await sink.output(
          doc,
          LogEntry(
            message: 'User authenticated successfully with OAuth2 bearer token',
            loggerName: 'auth.oauth',
            origin: 'OAuthService.verify',
            level: LogLevel.info,
            timestamp: '2026-11-20 10:00:00',
            context: {'userId': 'USR-100', 'provider': 'google'},
          ),
          LogLevel.info,
          factory,
        );

        await sink.output(
          doc,
          LogEntry(
            message: 'Stripe checkout failed with network timeout exception',
            loggerName: 'payment.checkout',
            origin: 'CheckoutService.process',
            level: LogLevel.error,
            timestamp: '2026-11-20 10:01:00',
            error: 'SocketException: Connection timed out',
            context: {'orderId': 'ORD-999', 'gateway': 'stripe'},
          ),
          LogLevel.error,
          factory,
        );

        // 1. Search for keyword 'OAuth2'
        final oauthResults = sink.query().search('OAuth2').execute();
        expect(oauthResults.length, equals(1));
        final oauthRecord = oauthResults.first;
        expect(oauthRecord.loggerName, equals('auth.oauth'));
        expect(oauthRecord.snippet, contains('<b>OAuth2</b>'));
        expect(oauthRecord.rank, isNotNull);
        expect(oauthRecord.rank!, isNegative);

        // 2. Search for keyword in error payload
        final errorResults = sink.query().search('SocketException').execute();
        expect(errorResults.length, equals(1));
        expect(errorResults.first.loggerName, equals('payment.checkout'));

        // 3. Search case-folding (unicode61 case-insensitive)
        final caseInsensitive = sink.query().search('stripe').execute();
        expect(caseInsensitive.length, equals(1));
        expect(caseInsensitive.first.loggerName, equals('payment.checkout'));

        // 4. Raw FTS5 match expression with boolean logic
        final rawMatchResults = sink
            .query()
            .match('OAuth2 OR Stripe')
            .orderBy(SqliteSortField.rank)
            .execute();
        expect(rawMatchResults.length, equals(2));
      },
    );

    test(
      'safely escapes user search queries with punctuation and quotes',
      () async {
        final sink = SqliteSink(
          database: memoryDb,
          batchSize: 1,
          enableFts: true,
        );
        final doc = StandardDocument();

        await sink.output(
          doc,
          LogEntry(
            message: 'Malformed input: "invalid_payload_404" encountered!',
            loggerName: 'api.validator',
            origin: 'Validator.check',
            level: LogLevel.warning,
            timestamp: '2026-11-20 10:00:00',
          ),
          LogLevel.warning,
          factory,
        );

        // Should not throw SQLite syntax errors even with quotes and colons
        final searchWithQuotes = sink
            .query()
            .search('"invalid_payload_404"')
            .execute();
        expect(searchWithQuotes.length, equals(1));

        final searchWithColons = sink
            .query()
            .search('input: "invalid')
            .execute();
        expect(() => searchWithColons, returnsNormally);
      },
    );

    test('synchronizes index during delete and clear operations', () async {
      final sink = SqliteSink(
        database: memoryDb,
        batchSize: 1,
        enableFts: true,
      );
      final doc = StandardDocument();

      await sink.output(
        doc,
        LogEntry(
          message: 'Temporary session token created',
          loggerName: 'session',
          origin: 'Session.start',
          level: LogLevel.debug,
          timestamp: '2026-11-20 10:00:00',
        ),
        LogLevel.debug,
        factory,
      );

      expect(sink.query().search('Temporary').count(), equals(1));

      // Clear table
      sink.clear();
      expect(sink.count(), equals(0));
      expect(sink.query().search('Temporary').count(), equals(0));
    });

    test('falls back gracefully to LIKE when enableFts is false', () async {
      final sink = SqliteSink(
        database: memoryDb,
        batchSize: 1,
        enableFts: false,
      );
      final doc = StandardDocument();

      await sink.output(
        doc,
        LogEntry(
          message: 'Non-FTS fallback search verification',
          loggerName: 'fallback.test',
          origin: 'main',
          level: LogLevel.info,
          timestamp: '2026-11-20 10:00:00',
        ),
        LogLevel.info,
        factory,
      );

      expect(sink.isFts5Available, isFalse);

      final results = sink.query().search('fallback').execute();
      expect(results.length, equals(1));
      expect(results.first.loggerName, equals('fallback.test'));
      expect(results.first.snippet, isNull);
      expect(results.first.rank, isNull);
    });
  });
}
