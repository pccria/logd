import 'dart:convert';
import 'package:dio/dio.dart';
import 'sanitizer.dart';

/// Formats a Dio [RequestOptions] into an executable cURL command string.
abstract final class LogdCurlGenerator {
  /// Converts [options] into a cURL string representation.
  static String generate(
    final RequestOptions options, {
    required final Set<String> sensitiveHeaders,
    required final String placeholder,
    final Set<String> sensitiveQueryParams = const {},
    final Set<String> sensitiveBodyKeys = const {},
  }) {
    final buffer = StringBuffer('curl');

    // Method
    final rawMethod = options.method.trim().toUpperCase();
    final method =
        RegExp(r'^[A-Z0-9_-]+$').hasMatch(rawMethod) ? rawMethod : 'GET';
    buffer.write(' -X $method');

    // Headers
    final sanitizedHeaders = LogdSanitizer.sanitizeHeaders(
      options.headers,
      sensitiveHeaders,
      placeholder,
    );

    for (final entry in sanitizedHeaders.entries) {
      final key =
          entry.key.replaceAll("'", r"'\''").replaceAll(RegExp(r'[\r\n]'), '');
      final value = entry.value;
      if (value != null) {
        final escaped = value
            .toString()
            .replaceAll("'", r"'\''")
            .replaceAll(RegExp(r'[\r\n]'), '');
        buffer.write(" -H '$key: $escaped'");
      }
    }

    // Body
    final data = options.data;
    if (data != null && method != 'GET' && method != 'HEAD') {
      if (data is FormData) {
        buffer.write(" --data '[FormData]'");
      } else if (data is List<int>) {
        buffer.write(" --data '[Binary data]'");
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
        buffer.write(" --data-raw '$escapedBody'");
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
    buffer.write(" '$escapedUri'");

    return buffer.toString();
  }
}
