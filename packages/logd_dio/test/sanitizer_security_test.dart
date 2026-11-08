import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd/testing.dart';
import 'package:logd_dio/logd_dio.dart';
import 'package:test/test.dart';

void main() {
  group('LogdSanitizer Security & Normalization Hardening', () {
    const placeholder = '***REDACTED***';

    test('redacts camelCase and kebab-case body keys matching snake_case defaults', () {
      final body = {
        'accessToken': 'secret-jwt',
        'refreshToken': 'refresh-xyz',
        'apiKey': 'api-123',
        'clientSecret': 'client-sec',
        'creditCard': '4111222233334444',
        'publicField': 'public-info',
      };

      final sanitized = LogdSanitizer.sanitizeBody(
        body,
        LogdDioOptions.defaultSensitiveBodyKeys,
        placeholder,
      ) as Map<String, dynamic>;

      expect(sanitized['accessToken'], equals(placeholder));
      expect(sanitized['refreshToken'], equals(placeholder));
      expect(sanitized['apiKey'], equals(placeholder));
      expect(sanitized['clientSecret'], equals(placeholder));
      expect(sanitized['creditCard'], equals(placeholder));
      expect(sanitized['publicField'], equals('public-info'));
    });

    test('redacts sensitive keys in form-urlencoded body strings', () {
      const formBody = 'username=john&password=mysecretpassword&grant_type=password&client_secret=topsecret';

      final sanitized = LogdSanitizer.sanitizeBody(
        formBody,
        LogdDioOptions.defaultSensitiveBodyKeys,
        placeholder,
      );

      expect(sanitized, isA<String>());
      final sanitizedStr = sanitized! as String;
      expect(sanitizedStr, contains('password=***REDACTED***'));
      expect(sanitizedStr, contains('client_secret=***REDACTED***'));
      expect(sanitizedStr, contains('username=john'));
      expect(sanitizedStr, isNot(contains('mysecretpassword')));
      expect(sanitizedStr, isNot(contains('topsecret')));
    });

    test('redacts credentials in Uri.userInfo', () {
      final uriWithAuth = Uri.parse('https://appuser:secretpassword123@api.example.com/v1/resource?token=abc');

      final sanitized = LogdSanitizer.sanitizeUri(
        uriWithAuth,
        LogdDioOptions.defaultSensitiveQueryParams,
        placeholder,
      );

      expect(sanitized.userInfo, equals('appuser:$placeholder'));
      expect(sanitized.toString(), isNot(contains('secretpassword123')));
      expect(sanitized.queryParameters['token'], equals(placeholder));
      expect(sanitized.toString(), contains('REDACTED'));
    });

    test('redacts expanded security headers (x-auth-token, x-csrf-token, api-key)', () {
      final headers = {
        'x-auth-token': 'token-123',
        'X-Csrf-Token': 'csrf-xyz',
        'api-key': 'key-999',
        'x-access-token': 'access-456',
        'content-type': 'application/json',
      };

      final sanitized = LogdSanitizer.sanitizeHeaders(
        headers,
        LogdDioOptions.defaultSensitiveHeaders,
        placeholder,
      );

      expect(sanitized['x-auth-token'], equals(placeholder));
      expect(sanitized['X-Csrf-Token'], equals(placeholder));
      expect(sanitized['api-key'], equals(placeholder));
      expect(sanitized['x-access-token'], equals(placeholder));
      expect(sanitized['content-type'], equals('application/json'));
    });

    test('scrubs sensitive URLs and parameters from error messages in interceptor', () async {
      final testLogger = TestLogger('http');
      addTearDown(testLogger.dispose);

      final dio = Dio();
      dio.interceptors.add(
        LogdDioInterceptor(
          LogdDioOptions(
            logger: testLogger.logger,
            sensitiveQueryParams: {'token', 'api_key'},
          ),
        ),
      );

      // Trigger an error where the error message embeds a sensitive query parameter
      try {
        await dio.get(
          'http://127.0.0.1:1/nonexistent?token=supersecret123&api_key=privkey999',
        );
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(testLogger.logs, isNotEmpty);
      final errorLog = testLogger.logs.firstWhere((final l) => l.level == LogLevel.error);

      // Verify that neither the log message, nor the error object string leaks the token
      expect(errorLog.message, isNot(contains('supersecret123')));
      expect(errorLog.message, isNot(contains('privkey999')));
      if (errorLog.error != null) {
        expect(errorLog.error.toString(), isNot(contains('supersecret123')));
        expect(errorLog.error.toString(), isNot(contains('privkey999')));
      }
    });
  });
}
