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

  /// Produces a safe, bounded preview of request or response bodies.
  static Object? safeBodyPreview(
    final Object? data, {
    required final int maxBodyLength,
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

    String text;
    try {
      if (data is String) {
        text = data;
      } else {
        text = jsonEncode(data);
      }
    } catch (_) {
      text = data.toString();
    }

    if (maxBodyLength > 0 && text.length > maxBodyLength) {
      final truncatedCount = text.length - maxBodyLength;
      return '${text.substring(0, maxBodyLength)}... [truncated $truncatedCount chars]';
    }

    return text;
  }
}
