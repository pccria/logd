import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

/// In-depth example demonstrating Security, Compliance (SOC2 / GDPR),
/// and Payload Safety features in `logd_dio`.
///
/// Features highlighted:
/// 1. Case-insensitive sensitive header redaction (Authorization, Cookies, API keys).
/// 2. Query parameter redaction (api_key, token, secrets) in logs and cURL.
/// 3. Sensitive JSON body key redaction (passwords, tokens, credit cards).
/// 4. Custom redacted placeholders (e.g. `[CONFIDENTIAL]`).
/// 5. Payload truncation (`maxBodyLength`) preventing log memory exhaustion.
/// 6. Safe previewing of multipart [FormData] and binary buffers ([List<int>]).
Future<void> main() async {
  // 1. Configure logd console output
  Logger.configure('global', handlers: [
    ConsoleHandler(theme: const DarkTheme()),
  ]);

  final logger = Logger.get('security_demo');
  logger.info('Starting Security & Sanitization Demo');

  // 2. Configure Dio with custom security & sanitization policies
  final dio = Dio();
  dio.httpClientAdapter = _SimulatedHttpAdapter();

  dio.interceptors.add(
    LogdDioInterceptor(
      const LogdDioOptions(
        // Custom replacement placeholder
        redactedPlaceholder: '[CONFIDENTIAL]',

        // Redact custom company auth headers in addition to defaults
        sensitiveHeaders: {
          ...LogdDioOptions.defaultSensitiveHeaders,
          'x-internal-secret',
          'x-tenant-token',
        },

        // Redact custom query parameters
        sensitiveQueryParams: {
          ...LogdDioOptions.defaultSensitiveQueryParams,
          'session_key',
          'signature',
        },

        // Truncate payloads longer than 60 characters
        maxBodyLength: 60,

        // Generate sanitized cURL
        logCurl: true,
      ),
    ),
  );

  // Scenario A: Sensitive Headers and Query Parameters
  logger.info('--- Scenario A: Redacting Sensitive Headers & Query Params ---');
  await dio.get<void>(
    'https://api.example.com/v1/user/profile',
    queryParameters: {
      'user_id': '42',
      'api_key': 'super-secret-production-key-12345',
      'session_key': 'active-sess-xyz',
    },
    options: Options(
      headers: {
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret',
        'X-Internal-Secret': 'vault-secret-999',
        'Accept': 'application/json',
      },
    ),
  );

  // Scenario B: Large Payload Body Truncation (prevents log memory exhaustion)
  logger.info('--- Scenario B: Large Payload Body Truncation ---');
  final massiveJsonPayload = {
    'audit_id': 1001,
    'description':
        'A very detailed system report with lots of verbose data ' * 5,
  };
  await dio.post<void>(
    'https://api.example.com/v1/reports',
    data: massiveJsonPayload,
  );

  // Scenario C: Safe Multipart FormData and Binary Stream Handling
  logger.info('--- Scenario C: Multipart FormData & Binary Stream Safety ---');
  final formData = FormData.fromMap({
    'username': 'johndoe',
    'avatar': MultipartFile.fromBytes(
      Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]),
      filename: 'avatar.png',
    ),
  });

  await dio.post<void>(
    'https://api.example.com/v1/upload',
    data: formData,
  );

  // Scenario D: Sensitive Body Key Redaction (passwords, tokens, cards)
  logger.info('--- Scenario D: Sensitive Body Key Redaction ---');
  await dio.post<void>(
    'https://api.example.com/v1/auth/login',
    data: {
      'email': 'alice@example.com',
      'password': 'super-secret-user-password',
      'auth_token': 'jwt-raw-session-token',
    },
  );

  logger.info('Security & Sanitization Demo completed successfully.');
}

/// A simulated HTTP client adapter that returns canned responses without
/// making external network requests.
class _SimulatedHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    final RequestOptions options,
    final Stream<Uint8List>? requestStream,
    final Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"status": "success", "message": "Simulated response with sensitive data protected"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({final bool force = false}) {}
}
