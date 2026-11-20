// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('LoggerSerializationRegistry for logd_sqlite', () {
    setUp(() {
      registerLogdSqliteSerializers();
    });

    test('round-trips SqliteSink with properties intact', () async {
      final original = SqliteSink(
        dbPath: 'test_db.db',
        tableName: 'custom_logs',
        maxEntries: 5000,
        maxAge: const Duration(days: 7),
        batchSize: 20,
        flushInterval: const Duration(seconds: 5),
        walMode: true,
        enableFts: true,
        maxDiskBytes: 50 * 1024 * 1024,
      );

      final json = LoggerSerializationRegistry.serializeSink(original);

      expect(json['type'], 'SqliteSink');
      final config = json['config'] as Map<String, dynamic>;
      expect(config['dbPath'], 'test_db.db');
      expect(config['tableName'], 'custom_logs');
      expect(config['maxEntries'], 5000);
      expect(config['maxAge'], const Duration(days: 7).inMilliseconds);
      expect(
        config['flushInterval'],
        const Duration(seconds: 5).inMilliseconds,
      );
      expect(config['walMode'], isTrue);
      expect(config['maxBufferSize'], 10000);
      expect(config['enableFts'], isTrue);
      expect(config['maxDiskBytes'], 50 * 1024 * 1024);

      final deserialized = LoggerSerializationRegistry.deserializeSink(json);
      expect(deserialized, isA<SqliteSink>());
      final sink = deserialized as SqliteSink;
      expect(sink.dbPath, 'test_db.db');
      expect(sink.tableName, 'custom_logs');
      expect(sink.maxEntries, 5000);
      expect(sink.maxAge, const Duration(days: 7));
      expect(sink.batchSize, 20);
      expect(sink.flushInterval, const Duration(seconds: 5));
      expect(sink.walMode, isTrue);
      expect(sink.maxBufferSize, 10000);
      expect(sink.enableFts, isTrue);
      expect(sink.maxDiskBytes, 50 * 1024 * 1024);

      await sink.dispose();
      await original.dispose();
    });
  });
}
