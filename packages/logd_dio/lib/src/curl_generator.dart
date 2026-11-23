import 'dart:convert';
import 'package:dio/dio.dart';
import 'sanitizer.dart';
import 'serializer/body_serializer.dart';

/// Formats a Dio [RequestOptions] into an executable cURL command string.
abstract final class LogdCurlGenerator {
  /// Converts [options] into a cURL string representation.
  static String generate(
    final RequestOptions options, {
    required final Set<String> sensitiveHeaders,
    required final String placeholder,
    final Set<String> sensitiveQueryParams = const {},
    final Set<String> sensitiveBodyKeys = const {},
    final bool pretty = false,
    final bool includeCompressed = true,
    final List<LogdBodySerializer> serializers = const [],
  }) {
    final parts = <String>['curl'];

    // Method
    final rawMethod = options.method.trim().toUpperCase();
    final method = RegExp(r'^[A-Z0-9_-]+$').hasMatch(rawMethod)
        ? rawMethod
        : 'GET';
    parts.add('-X $method');

    // Compression
    if (includeCompressed) {
      final hasCompressionHeader = options.headers.entries.any((final e) {
        final k = e.key.toLowerCase();
        final v = e.value?.toString().toLowerCase() ?? '';
        return k == 'accept-encoding' &&
            (v.contains('gzip') || v.contains('deflate') || v.contains('br'));
      });
      if (hasCompressionHeader) {
        parts.add('--compressed');
      }
    }

    // Headers
    final sanitizedHeaders = LogdSanitizer.sanitizeHeaders(
      options.headers,
      sensitiveHeaders,
      placeholder,
    );

    for (final entry in sanitizedHeaders.entries) {
      final key = entry.key
          .replaceAll("'", r"'\''")
          .replaceAll(RegExp(r'[\r\n]'), '');
      final value = entry.value;
      if (value != null) {
        final escaped = value
            .toString()
            .replaceAll("'", r"'\''")
            .replaceAll(RegExp(r'[\r\n]'), '');
        parts.add("-H '$key: $escaped'");
      }
    }

    // Body
    final data = options.data;
    if (data != null && method != 'GET' && method != 'HEAD') {
      // Check pluggable custom serializers first
      String? customSerialized;
      final contentType =
          options.contentType ??
          options.headers[Headers.contentTypeHeader]?.toString();
      for (final s in serializers) {
        if (s.canSerialize(data, contentType)) {
          customSerialized = s.serialize(data, contentType);
          break;
        }
      }

      if (customSerialized != null) {
        final sanitizedCustom = LogdSanitizer.sanitizeBody(
          customSerialized,
          sensitiveBodyKeys,
          placeholder,
        );
        final escapedBody = sanitizedCustom.toString().replaceAll("'", r"'\''");
        parts.add("--data-raw '$escapedBody'");
      } else if (data is FormData) {
        parts.add("--data '[FormData]'");
      } else if (data is List<int>) {
        parts.add("--data '[Binary data]'");
      } else {
        final sanitizedData = LogdSanitizer.sanitizeBody(
          data,
          sensitiveBodyKeys,
          placeholder,
        );
        String bodyString;
        try {
          bodyString = sanitizedData is String
              ? sanitizedData
              : jsonEncode(sanitizedData);
        } catch (_) {
          bodyString = sanitizedData.toString();
        }
        final escapedBody = bodyString.replaceAll("'", r"'\''");
        parts.add("--data-raw '$escapedBody'");
      }
    }

    // URL
    final sanitizedUri = LogdSanitizer.sanitizeUri(
      options.uri,
      sensitiveQueryParams,
      placeholder,
    );
    final escapedUri = sanitizedUri
        .toString()
        .replaceAll("'", r"'\''")
        .replaceAll(RegExp(r'[\r\n]'), '');
    parts.add("'$escapedUri'");

    if (pretty) {
      final sb = StringBuffer(parts.first);
      for (var i = 1; i < parts.length; i++) {
        sb.write(' \\\n  ${parts[i]}');
      }
      return sb.toString();
    }

    return parts.join(' ');
  }
}
