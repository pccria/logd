import 'package:meta/meta.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/context/context.dart';
import '../logger/logger.dart';
import 'windows_zones.dart';

/// Timezone configuration using IANA Time Zone Database.
///
/// Wraps [tz.Location] to provide timezone calculations.
@immutable
class Timezone {
  /// System time zone.
  ///
  /// Tries to resolve to a DST-aware timezone based on the platform.
  /// If failed or when the platform returns an abbreviation or numeric offset,
  /// falls back to a fixed offset matching the system clock.
  factory Timezone.local() {
    if (_localCache != null) {
      return _localCache!;
    }

    final systemTime = Context.clock.now;
    String? systemTimezoneName;
    try {
      systemTimezoneName =
          Context.clock.timezoneName ?? systemTime.timeZoneName;
    } catch (e, s) {
      InternalLogger.log(
        LogLevel.warning,
        'Platform timezone fetch failed',
        error: e,
        stackTrace: s,
      );
    }

    // 1. Fast Path: UTC or empty timezone name
    if (systemTimezoneName == null || systemTimezoneName.isEmpty) {
      return _localCache = Timezone._fixed(
        systemTime.timeZoneOffset,
        name: 'UTC',
      );
    }

    final upper = systemTimezoneName.toUpperCase();
    if (upper == 'UTC' || upper == 'ETC/UTC' || upper == 'Z') {
      return _localCache = Timezone.utc();
    }

    // 2. Fast Path: Numeric offset format (e.g. "+0330", "+03:30", "-0500")
    if (_offsetPattern.hasMatch(systemTimezoneName)) {
      return _localCache = Timezone._fixed(
        systemTime.timeZoneOffset,
        name: systemTimezoneName,
      );
    }

    // 3. Resolve Windows or candidate IANA timezone
    final ianaName = windowsToIana[systemTimezoneName] ?? systemTimezoneName;
    final isCandidateIana =
        ianaName.contains('/') || _ianaNonSlashZones.contains(ianaName);

    if (isCandidateIana) {
      _ensureInitializedImplicitly();
      try {
        final location = tz.getLocation(ianaName);
        return _localCache = Timezone._(location);
      } on tz.LocationNotFoundException {
        final systemTimezoneOffset = systemTime.timeZoneOffset;
        InternalLogger.log(
          LogLevel.warning,
          'Timezone "$systemTimezoneName" (resolved to "$ianaName") '
          'not found in database. Using fixed offset '
          '${systemTimezoneOffset.formatOffset}. '
          'DST transitions will not be handled automatically.',
        );
      } catch (e, s) {
        InternalLogger.log(
          LogLevel.warning,
          'Timezone "$systemTimezoneName" resolution error',
          error: e,
          stackTrace: s,
        );
      }
    }

    // 4. Fallback for abbreviations (e.g. "EDT", "EST", "PST") and unmapped
    // names
    final systemTimezoneOffset = systemTime.timeZoneOffset;
    return _localCache = Timezone._fixed(
      systemTimezoneOffset,
      name: systemTimezoneName,
    );
  }

  /// UTC time zone (fixed).
  factory Timezone.utc() => Timezone._(tz.UTC);

  /// Named (DST-aware) [Timezone] from IANA database.
  ///
  /// Throws [tz.LocationNotFoundException] if the location is not found.
  /// Throws [ArgumentError] if the name is empty or only whitespace.
  factory Timezone.named(final String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Timezone name cannot be empty or blank.',
      );
    }
    final trimmed = name.trim();
    if (trimmed.toUpperCase() == 'UTC' || trimmed.toUpperCase() == 'ETC/UTC') {
      return Timezone.utc();
    }
    _ensureInitializedImplicitly();
    return Timezone._(tz.getLocation(trimmed));
  }

  /// Creates a fixed offset timezone.
  ///
  /// Does not support DST transitions.
  factory Timezone._fixed(
    final Duration offset, {
    final String name = 'Fixed',
  }) {
    assert(
      name.trim().isNotEmpty,
      'Fixed timezone name cannot be empty or blank.',
    );
    final fixedLocation = tz.Location(name, [
      tz.minTime,
    ], [
      0,
    ], [
      tz.TimeZone(
        offset,
        isDst: false,
        abbreviation: 'FIX',
      ),
    ]);
    return Timezone._(fixedLocation);
  }

  const Timezone._(this._location);

  static final RegExp _offsetPattern = RegExp(r'^[+-]\d{2}(?::?\d{2})?$');

  static const Set<String> _ianaNonSlashZones = {
    'CST6CDT',
    'EST5EDT',
    'Factory',
    'MST7MDT',
    'PST8PDT',
  };

  /// Ensures the timezone database is initialized.
  ///
  /// This must be called at least once before using [Timezone.named] or
  /// [Timezone.local] if they rely on the database.
  ///
  /// Takes an optional [database] bytes if you want to load a custom one.
  /// If null, loads the default 'latest' database bundled with the package.
  static void ensureInitialized([final List<int>? database]) {
    if (!_isInitialized) {
      if (database != null) {
        tz.initializeDatabase(database);
      } else {
        try {
          tz_data.initializeTimeZones();
        } catch (e, s) {
          InternalLogger.log(
            LogLevel.warning,
            'Explicit timezone database initialization failed. Falling back to'
            ' fixed offsets.',
            error: e,
            stackTrace: s,
          );
        }
      }
      _isInitialized = true;
    }
  }

  static void _ensureInitializedImplicitly() {
    if (!_isInitialized) {
      try {
        tz_data.initializeTimeZones();
      } catch (e, s) {
        InternalLogger.log(
          LogLevel.warning,
          'Implicit timezone database initialization failed. Falling back to'
          ' fixed offsets.',
          error: e,
          stackTrace: s,
        );
      }
      _isInitialized = true;
    }
  }

  static bool _isInitialized = false;

  static Timezone? _localCache;

  /// Resets the local timezone cache.
  @visibleForTesting
  static void resetLocalCache() => _localCache = null;

  /// The underlying [tz.Location].
  final tz.Location _location;

  /// The name of the time zone (e.g., 'UTC', 'Asia/Kolkata').
  String get name => _location.name;

  /// Returns the current time in this timezone.
  DateTime get now {
    final utcNow = Context.clock.now.toUtc();
    final tzDateTime = tz.TZDateTime.from(utcNow, _location);
    return tzDateTime;
  }

  static int _cachedMinute = 0;
  static final Map<String, Duration> _cachedOffsets = {};

  /// Timezone offset at the current time.
  Duration get offset {
    final utcNow = Context.clock.now.toUtc();
    final utcNowMs = utcNow.millisecondsSinceEpoch;
    final minuteKey = utcNowMs ~/ 60000;

    if (minuteKey == _cachedMinute) {
      final cached = _cachedOffsets[name];
      if (cached != null) {
        return cached;
      }
    } else {
      _cachedMinute = minuteKey;
      _cachedOffsets.clear();
    }

    final tzDateTime = tz.TZDateTime.from(utcNow, _location);
    final duration = tzDateTime.timeZoneOffset;
    _cachedOffsets[name] = duration;
    return duration;
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is Timezone &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

extension OffsetLiteralExt on Timezone {
  /// Timezone offset literal.
  String get offsetLiteral {
    final current = offset;
    final timezoneOffsetHours = current.inHours.abs();
    final timezoneOffsetMinutes = current.inMinutes.abs() % 60;
    final timezoneOffsetSign = current.isNegative ? '-' : '+';
    return '$timezoneOffsetSign'
        '${timezoneOffsetHours.toString().padLeft(2, '0')}:'
        '${timezoneOffsetMinutes.toString().padLeft(2, '0')}';
  }

  /// ISO8601 offset literal
  String get iso8601OffsetLiteral {
    final currentOffset = offset;
    if (currentOffset.inMinutes == 0) {
      return 'Z';
    }
    final timezoneOffsetHours = currentOffset.inHours.abs();
    final timezoneOffsetMinutes = currentOffset.inMinutes.abs() % 60;
    final timezoneOffsetSign = currentOffset.isNegative ? '-' : '+';
    return '$timezoneOffsetSign'
        '${timezoneOffsetHours.toString().padLeft(2, '0')}'
        ':'
        '${timezoneOffsetMinutes.toString().padLeft(2, '0')}';
  }

  /// RFC2822 offset literal
  String get rfc2822OffsetLiteral {
    final s = offsetLiteral;
    return s.replaceAll(':', '');
  }
}

extension TimezoneOffsetExt on Duration {
  String get formatOffset {
    final hours = inHours.abs();
    final minutes = inMinutes.abs() % 60;
    final sign = isNegative ? '-' : '+';
    return '$sign${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }
}
