// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteLogRecord Entity Suite', () {
    test('SqliteLogRecord.fromRow parses row map faithfully', () {
      final row = <String, dynamic>{
        'id': 42,
        'timestamp': '2026-11-20T00:00:00.000Z',
        'level': 3,
        'level_name': 'warning',
        'logger_name': 'payment.gateway',
        'origin': 'PaymentService.charge',
        'message': 'Transient network latency encountered',
        'created_at': 1770000000000,
        'error': 'SocketTimeoutException',
        'stack_trace': 'at PaymentService.charge (payment.dart:42)',
        'context_json': '{"orderId":"ORD-101","retryCount":2}',
        'snippet': 'Transient <b>network</b> latency',
        'rank': -0.75,
      };

      final record = SqliteLogRecord.fromRow(row);

      expect(record.id, equals(42));
      expect(record.timestamp, equals('2026-11-20T00:00:00.000Z'));
      expect(record.levelIndex, equals(3));
      expect(record.levelName, equals('warning'));
      expect(record.level, equals(LogLevel.warning));
      expect(record.loggerName, equals('payment.gateway'));
      expect(record.origin, equals('PaymentService.charge'));
      expect(record.message, equals('Transient network latency encountered'));
      expect(record.createdAt, equals(1770000000000));
      expect(
        record.createdAtDateTime,
        equals(DateTime.fromMillisecondsSinceEpoch(1770000000000)),
      );
      expect(record.error, equals('SocketTimeoutException'));
      expect(
        record.stackTrace,
        equals('at PaymentService.charge (payment.dart:42)'),
      );
      expect(record.snippet, equals('Transient <b>network</b> latency'));
      expect(record.rank, equals(-0.75));

      final context = record.context;
      expect(context, isNotNull);
      expect(context!['orderId'], equals('ORD-101'));
      expect(context['retryCount'], equals(2));
    });

    test(
      'backward-compatible operator [] mirrors SQLite raw column values',
      () {
        final record = SqliteLogRecord(
          id: 7,
          timestamp: '2026-11-20T01:00:00.000Z',
          levelIndex: 4,
          levelName: 'error',
          loggerName: 'auth.service',
          origin: 'Auth.login',
          message: 'Invalid credentials',
          createdAt: 1770000010000,
        );

        // ['level'] must return int, NOT LogLevel, preserving exact DB
        // column contract
        expect(record['id'], equals(7));
      expect(record['level'], equals(4));
      expect(record['level'], isA<int>());
      expect(record['level_name'], equals('error'));
      expect(record['logger_name'], equals('auth.service'));
      expect(record['origin'], equals('Auth.login'));
      expect(record['message'], equals('Invalid credentials'));
      expect(record['created_at'], equals(1770000010000));
      expect(record['non_existent_key'], isNull);
    });

    test('toMap and fromRow round-trip preserving equality', () {
      const record = SqliteLogRecord(
        id: 10,
        timestamp: '2026-11-20T02:00:00.000Z',
        levelIndex: 2,
        levelName: 'info',
        loggerName: 'app.service',
        origin: 'main',
        message: 'System healthy',
        createdAt: 1770000020000,
        contextJson: '{"healthy":true}',
        snippet: 'System <b>healthy</b>',
        rank: -1.2,
      );

      final map = record.toMap();
      final reconstructed = SqliteLogRecord.fromRow(map);

      expect(reconstructed, equals(record));
      expect(reconstructed.hashCode, equals(record.hashCode));
      expect(reconstructed.toString(), contains('System healthy'));
    });

    test('handles null context and corrupted JSON gracefully', () {
      const recordNullContext = SqliteLogRecord(
        id: 1,
        timestamp: '2026-11-20T00:00:00Z',
        levelIndex: 2,
        levelName: 'info',
        loggerName: 'test',
        origin: 'test',
        message: 'test',
        createdAt: 1000,
      );
      expect(recordNullContext.context, isNull);

      const recordCorrupted = SqliteLogRecord(
        id: 2,
        timestamp: '2026-11-20T00:00:00Z',
        levelIndex: 2,
        levelName: 'info',
        loggerName: 'test',
        origin: 'test',
        message: 'test',
        createdAt: 1000,
        contextJson: '{unclosed-json',
      );
      expect(recordCorrupted.context, isNull);
    });
  });
}
