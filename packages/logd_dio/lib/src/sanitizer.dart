import 'dart:convert';
import 'package:dio/dio.dart';

/// Utilities for sanitizing sensitive HTTP headers, query parameters, and payloads.
abstract final class LogdSanitizer {
  /// Redacts sensitive keys from a map of HTTP headers.
  static Map<String, dynamic> sanitizeHeaders(
    final Map<String, dynamic> headers,
    final Set<String> sensitiveHeaders,
    final String placeholder,
  ) {
    if (headers.isEmpty) return const {};

    final normalizedSensitive =
        sensitiveHeaders.map((final k) => k.toLowerCase()).toSet();

    return headers.map((final key, final value) {
      if (normalizedSensitive.contains(key.toLowerCase())) {
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
    if (queryParams.isEmpty) return const {};

    final normalizedSensitive =
        sensitiveKeys.map((final k) => k.toLowerCase()).toSet();

    return queryParams.map((final key, final value) {
      if (normalizedSensitive.contains(key.toLowerCase())) {
        return MapEntry(key, placeholder);
      }
      return MapEntry(key, value);
    });
  }

  /// Returns a copy of [uri] with sensitive query parameter values replaced with [placeholder].
  static Uri sanitizeUri(
    final Uri uri,
    final Set<String> sensitiveKeys,
    final String placeholder,
  ) {
    if (!uri.hasQuery || sensitiveKeys.isEmpty) return uri;

    final normalizedSensitive =
        sensitiveKeys.map((final k) => k.toLowerCase()).toSet();

    final newQueryParameters = <String, dynamic>{};
    for (final entry in uri.queryParametersAll.entries) {
      if (normalizedSensitive.contains(entry.key.toLowerCase())) {
        newQueryParameters[entry.key] =
            entry.value.map((final _) => placeholder).toList();
      } else {
        newQueryParameters[entry.key] = entry.value;
      }
    }

    return uri.replace(queryParameters: newQueryParameters);
  }

  /// Recursively redacts sensitive keys from a JSON-like object (Map, List, or JSON String).
  static Object? sanitizeBody(
    final Object? data,
    final Set<String> sensitiveKeys,
    final String placeholder,
  ) {
    if (data == null || sensitiveKeys.isEmpty) return data;

    final normalizedSensitive =
        sensitiveKeys.map((final k) => k.toLowerCase()).toSet();

    Object? sanitizeRecursive(final Object? node) {
      if (node is Map) {
        final result = <String, Object?>{};
        for (final entry in node.entries) {
          final keyStr = entry.key.toString();
          if (normalizedSensitive.contains(keyStr.toLowerCase())) {
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
      }
    }

    return data;
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
