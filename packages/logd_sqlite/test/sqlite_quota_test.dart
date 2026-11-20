// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteSink Disk Quota (maxDiskBytes) Retention Suite', () {
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

    test('validates positive maxDiskBytes at construction', () {
      expect(
        () => SqliteSink(database: memoryDb, maxDiskBytes: 0),
        throwsArgumentError,
      );
      expect(
        () => SqliteSink(database: memoryDb, maxDiskBytes: -1024),
        throwsArgumentError,
      );
    });

    test(
      'prunes oldest records to keep database within maxDiskBytes ceiling',
      () async {
        // In SQLite, base schema structures and FTS5 shadow tables
        // require ~48 KB. Setting a budget of 96 KB.
        final sink = SqliteSink(
          database: memoryDb,
          batchSize: 10,
          maxDiskBytes: 96 * 1024,
        );
        final doc = StandardDocument();

        // Emit 300 large log entries to trigger multiple disk-pruning cycles
        final largePayload = 'A' * 500;
        for (int i = 1; i <= 300; i++) {
          await sink.output(
            doc,
            LogEntry(
              message: 'Quota test entry #$i with payload: $largePayload',
              loggerName: 'quota.test',
              origin: 'main',
              level: LogLevel.info,
              timestamp: '2026-11-20 12:00:00',
              context: {'iteration': i, 'blob': largePayload},
            ),
            LogLevel.info,
            factory,
          );
        }

        await sink.flush();

        // Verify that live bytes are within budget
        final row = memoryDb.select('''
        SELECT (page_count - freelist_count) * page_size AS live_bytes
        FROM pragma_page_count(), pragma_freelist_count(), pragma_page_size();
      ''').first;
        final liveBytes = row['live_bytes'] as int;

        expect(liveBytes, lessThanOrEqualTo(96 * 1024));

        // Verify that oldest entries were purged and newest entries are
        // preserved
        final remainingLogs = sink.query().execute();
        expect(remainingLogs.isNotEmpty, isTrue);

        final highestId = remainingLogs.first.id;
        final lowestId = remainingLogs.last.id;
        expect(highestId, equals(300));
        expect(lowestId, greaterThan(1));
      },
    );
  });
}
