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
  }) {
    final buffer = StringBuffer('curl');

    // Method
    final method = options.method.toUpperCase();
    buffer.write(' -X $method');

    // Headers
    final sanitizedHeaders = LogdSanitizer.sanitizeHeaders(
      options.headers,
      sensitiveHeaders,
      placeholder,
    );

    for (final entry in sanitizedHeaders.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value != null) {
        final escaped = value.toString().replaceAll("'", r"'\''");
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
        String bodyString;
        try {
          bodyString = data is String ? data : jsonEncode(data);
        } catch (_) {
          bodyString = data.toString();
        }
        final escapedBody = bodyString.replaceAll("'", r"'\''");
        buffer.write(" --data-raw '$escapedBody'");
      }
    }

    // URL
    buffer.write(" '${options.uri}'");

    return buffer.toString();
  }
}
