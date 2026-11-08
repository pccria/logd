import 'dart:convert';
import 'package:dio/dio.dart';

/// Utilities for sanitizing sensitive HTTP headers, query parameters, and payloads.
abstract final class LogdSanitizer {
  static final RegExp _urlRegex = RegExp(r'https?://[^\s",<>]+');

  static String _normalizeKey(final String key) =>
      key.replaceAll(RegExp(r'[-_]'), '').toLowerCase();

  static bool _matchesSensitiveKey(
    final String key,
    final Set<String> lowerSensitive,
    final Set<String> normalizedSensitive,
  ) {
    final lower = key.toLowerCase();
    if (lowerSensitive.contains(lower)) return true;
    final normalized = _normalizeKey(lower);
    return normalizedSensitive.contains(normalized);
  }

  /// Redacts sensitive keys from a map of HTTP headers.
  static Map<String, dynamic> sanitizeHeaders(
    final Map<String, dynamic> headers,
    final Set<String> sensitiveHeaders,
    final String placeholder,
  ) {
    if (headers.isEmpty || sensitiveHeaders.isEmpty) return headers;

    final lowerSensitive =
        sensitiveHeaders.map((final k) => k.toLowerCase()).toSet();
    final normalizedSensitive = sensitiveHeaders.map(_normalizeKey).toSet();

    return headers.map((final key, final value) {
      if (_matchesSensitiveKey(key, lowerSensitive, normalizedSensitive)) {
        return MapEntry(key, placeholder);
      }
      return MapEntry(key, value);
    });
  }

  /// Redacts sensitive keys from a map of query parameters.
  static Map<String, dynamic> sanitizeQueryParams(
    final Map<String, dynamic> queryParams,
    final Set<String> sensitiveKeys,
    final String placeholder,
  ) {
    if (queryParams.isEmpty || sensitiveKeys.isEmpty) return queryParams;

    final lowerSensitive =
        sensitiveKeys.map((final k) => k.toLowerCase()).toSet();
    final normalizedSensitive = sensitiveKeys.map(_normalizeKey).toSet();

    return queryParams.map((final key, final value) {
      if (_matchesSensitiveKey(key, lowerSensitive, normalizedSensitive)) {
        return MapEntry(key, placeholder);
      }
      return MapEntry(key, value);
    });
  }

  /// Returns a copy of [uri] with credentials in userInfo and sensitive query parameters redacted.
  static Uri sanitizeUri(
    final Uri uri,
    final Set<String> sensitiveKeys,
    final String placeholder,
  ) {
    var modified = false;
    String? newUserInfo;

    if (uri.userInfo.isNotEmpty) {
      modified = true;
      if (uri.userInfo.contains(':')) {
        final colonIdx = uri.userInfo.indexOf(':');
        final user = uri.userInfo.substring(0, colonIdx);
        newUserInfo = '$user:$placeholder';
      } else {
        newUserInfo = placeholder;
      }
    }

    Map<String, dynamic>? newQueryParams;
    if (uri.hasQuery && sensitiveKeys.isNotEmpty) {
      final lowerSensitive =
          sensitiveKeys.map((final k) => k.toLowerCase()).toSet();
      final normalizedSensitive = sensitiveKeys.map(_normalizeKey).toSet();

      final params = <String, dynamic>{};
      for (final entry in uri.queryParametersAll.entries) {
        if (_matchesSensitiveKey(
            entry.key, lowerSensitive, normalizedSensitive)) {
          modified = true;
          params[entry.key] =
              entry.value.map((final _) => placeholder).toList();
        } else {
          params[entry.key] = entry.value;
        }
      }
      newQueryParams = params;
    }

    if (!modified) return uri;

    return uri.replace(
      userInfo: newUserInfo,
      queryParameters: newQueryParams,
    );
  }

  /// Recursively redacts sensitive keys from JSON-like objects, maps, lists, or form-urlencoded strings.
  static Object? sanitizeBody(
    final Object? data,
    final Set<String> sensitiveKeys,
    final String placeholder,
  ) {
    if (data == null || sensitiveKeys.isEmpty) return data;

    final lowerSensitive =
        sensitiveKeys.map((final k) => k.toLowerCase()).toSet();
    final normalizedSensitive = sensitiveKeys.map(_normalizeKey).toSet();

    Object? sanitizeRecursive(final Object? node) {
      if (node is Map) {
        final result = <String, Object?>{};
        for (final entry in node.entries) {
          final keyStr = entry.key.toString();
          if (_matchesSensitiveKey(
              keyStr, lowerSensitive, normalizedSensitive)) {
            result[keyStr] = placeholder;
          } else {
            result[keyStr] = sanitizeRecursive(entry.value);
          }
        }
        return result;
      } else if (node is List) {
        return node.map(sanitizeRecursive).toList();
      }
      return node;
    }

    if (data is Map || data is List) {
      return sanitizeRecursive(data);
    }

    if (data is String) {
      final trimmed = data.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          final decoded = jsonDecode(data);
          final sanitized = sanitizeRecursive(decoded);
          return jsonEncode(sanitized);
        } catch (_) {
          return data;
        }
      } else if (trimmed.contains('=') && !trimmed.contains('\n')) {
        try {
          final pairs = trimmed.split('&');
          if (pairs.isNotEmpty && pairs.every((final p) => p.contains('='))) {
            final sanitizedPairs = <String>[];
            for (final pair in pairs) {
              final eqIdx = pair.indexOf('=');
              final rawKey = pair.substring(0, eqIdx);
              final decodedKey = Uri.decodeQueryComponent(rawKey);
              if (_matchesSensitiveKey(
                  decodedKey, lowerSensitive, normalizedSensitive)) {
                sanitizedPairs.add('$rawKey=$placeholder');
              } else {
                sanitizedPairs.add(pair);
              }
            }
            return sanitizedPairs.join('&');
          }
        } catch (_) {
          return data;
        }
      }
    }

    return data;
  }

  /// Scrubs sensitive URLs and parameters from error objects or exception messages.
  static Object? sanitizeError(
    final Object? error,
    final Set<String> sensitiveKeys,
    final String placeholder,
  ) {
    if (error == null) return null;
    final text = error.toString();
    if (!_urlRegex.hasMatch(text)) return error;

    final sanitizedText = text.replaceAllMapped(_urlRegex, (final match) {
      final urlStr = match.group(0)!;
      final parsed = Uri.tryParse(urlStr);
      if (parsed != null) {
        return sanitizeUri(parsed, sensitiveKeys, placeholder).toString();
      }
      return urlStr;
    });

    return sanitizedText;
  }

  /// Produces a safe, bounded preview of request or response bodies with sensitive keys redacted.
  static Object? safeBodyPreview(
    final Object? data, {
    required final int maxBodyLength,
    final Set<String> sensitiveKeys = const {},
    final String placeholder = '***REDACTED***',
  }) {
    if (data == null) return null;

    if (data is FormData) {
      final fieldCount = data.fields.length;
      final fileCount = data.files.length;
      return '[FormData with $fieldCount fields, $fileCount files]';
    }

    if (data is List<int>) {
      return '[Binary data: ${data.length} bytes]';
    }

    if (data is Stream) {
      return '[Stream: ${data.runtimeType}]';
    }

    final sanitized = sanitizeBody(data, sensitiveKeys, placeholder);

    String text;
    try {
      if (sanitized is String) {
        text = sanitized;
      } else {
        text = jsonEncode(sanitized);
      }
    } catch (_) {
      text = sanitized.toString();
    }

    if (maxBodyLength > 0 && text.length > maxBodyLength) {
      final truncatedCount = text.length - maxBodyLength;
      return '${text.substring(0, maxBodyLength)}... [truncated $truncatedCount chars]';
    }

    return text;
  }
}
