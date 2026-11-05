import 'dart:io' as io;

import 'package:meta/meta.dart';

/// Fetches timezone name for native platforms (non-web).
///
/// Uses platform-specific methods (e.g., getprop for Android).
/// Throws Exception on fail; caller handles default/logging.
String fetchNativeTimezoneName() {
  final platform = io.Platform.operatingSystem.toLowerCase();
  switch (platform) {
    case 'android':
      // Fast path: DateTime.now().timeZoneName without spawning getprop
      return DateTime.now().timeZoneName;
    case 'ios':
    case 'macos':
      // Resolve /etc/localtime symlink without spawning systemsetup
      for (final path in [
        '/etc/localtime',
        '/var/db/timezone/localtime',
      ]) {
        try {
          final name = resolveTimezonePath(path);
          if (name != null) {
            return name;
          }
        } on io.FileSystemException catch (_) {
        } catch (_) {}
      }
      return DateTime.now().timeZoneName;
    case 'linux':
      final timezoneFile = io.File('/etc/timezone');
      if (timezoneFile.existsSync()) {
        return timezoneFile.readAsStringSync().trim();
      }
      final localtimeLink = io.Link('/etc/localtime');
      if (localtimeLink.existsSync()) {
        try {
          final realPath = localtimeLink.resolveSymbolicLinksSync();
          const zoneInfoPrefix = '/usr/share/zoneinfo/';
          if (realPath.startsWith(zoneInfoPrefix)) {
            return realPath.substring(zoneInfoPrefix.length);
          }
          final parts = realPath.split('/');
          return parts.sublist(parts.length - 2).join('/');
        } on Exception catch (_) {}
      }
      return DateTime.now().timeZoneName;
    case 'windows':
      // Fast path: DateTime.now().timeZoneName without spawning powershell
      return DateTime.now().timeZoneName;
    default:
      return DateTime.now().timeZoneName;
  }
}

/// Resolves a timezone name from a symlink path.
///
/// Returns null if the path is not a symlink to a valid zoneinfo file.
@visibleForTesting
String? resolveTimezonePath(final String path) {
  final link = io.Link(path);
  if (!link.existsSync()) {
    return null;
  }
  final realPath = link.resolveSymbolicLinksSync();
  const zoneInfoPrefix = '/usr/share/zoneinfo/';
  if (realPath.contains(zoneInfoPrefix)) {
    return realPath
        .substring(realPath.indexOf(zoneInfoPrefix) + zoneInfoPrefix.length);
  }
  return null;
}
