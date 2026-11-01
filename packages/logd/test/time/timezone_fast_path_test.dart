import 'dart:async';

import 'package:logd/logd.dart';
import 'package:logd/src/core/context/clock/clock.dart';
import 'package:logd/src/core/context/context.dart';
import 'package:logd/src/time/timezone.dart';
import 'package:test/test.dart';

class FastPathClock implements Clock {
  const FastPathClock(this._now, [this._timezoneName]);

  final DateTime _now;
  final String? _timezoneName;

  @override
  DateTime get now => _now;

  @override
  String? get timezoneName => _timezoneName;
}

void main() {
  group('Timezone Fast-Path & Mobile Abbreviation Fallback', () {
    final fixedTime = DateTime.utc(2025, 6, 1, 12, 0);

    setUp(() {
      Timezone.resetLocalCache();
    });

    tearDown(() {
      Context.reset();
      Timezone.resetLocalCache();
    });

    test('Numeric offset (+0330) uses fast path without database errors', () {
      final printed = <String>[];
      runZoned(
        () {
          Context.setClock(FastPathClock(fixedTime, '+0330'));
          final tz = Timezone.local();

          expect(tz.name, equals('+0330'));
          expect(tz.offset, equals(Duration.zero));
        },
        zoneSpecification: ZoneSpecification(
          print: (
            final self,
            final parent,
            final zone,
            final line,
          ) =>
              printed.add(line),
        ),
      );

      expect(printed.any((final l) => l.contains('[ERROR]')), isFalse);
    });

    test('UTC timezone name uses fast path without database errors', () {
      final printed = <String>[];
      runZoned(
        () {
          Context.setClock(FastPathClock(fixedTime, 'UTC'));
          final tz = Timezone.local();

          expect(tz.name, anyOf('UTC', 'Etc/UTC'));
          expect(tz.offset, equals(Duration.zero));
        },
        zoneSpecification: ZoneSpecification(
          print: (
            final self,
            final parent,
            final zone,
            final line,
          ) =>
              printed.add(line),
        ),
      );

      expect(printed.any((final l) => l.contains('[ERROR]')), isFalse);
    });

    test('Platform abbreviation (EDT) falls back cleanly without error logs',
        () {
      final printed = <String>[];
      runZoned(
        () {
          Context.setClock(FastPathClock(fixedTime, 'EDT'));
          final tz = Timezone.local();

          expect(tz.name, equals('EDT'));
          expect(tz.offset, equals(Duration.zero));
        },
        zoneSpecification: ZoneSpecification(
          print: (
            final self,
            final parent,
            final zone,
            final line,
          ) =>
              printed.add(line),
        ),
      );

      expect(printed.any((final l) => l.contains('[ERROR]')), isFalse);
    });

    test('Standard IANA timezone name still resolves full DST location', () {
      Context.setClock(FastPathClock(fixedTime, 'Europe/London'));
      final tz = Timezone.local();

      expect(tz.name, equals('Europe/London'));
      // In June, London is in BST (UTC+1)
      expect(tz.offset.inHours, equals(1));
    });
  });
}
