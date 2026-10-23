import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd/testing.dart';
import 'package:logd_dio/logd_dio.dart';
import 'package:test/test.dart';

void main() {
  group('Wire Integrity & Invariant Preservation (Real HttpServer)', () {
    late HttpServer server;
    late String serverUrl;
    late Dio dio;
    late TestLogger testLogger;

    setUp(() async {
      // Bind local test HTTP server on an ephemeral loopback port
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.host}:${server.port}';

      testLogger = TestLogger('http');
      dio = Dio(
        BaseOptions(
          baseUrl: serverUrl,
          connectTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
        ),
      );

      dio.interceptors.add(
        LogdDioInterceptor(
          LogdDioOptions(
            logger: testLogger.logger,
            logCurl: true,
            logResponseHeaders: true,
          ),
        ),
      );
    });

    tearDown(() async {
      dio.close();
      await server.close(force: true);
      testLogger.dispose();
    });

    test(
        'Server receives original unredacted credentials while logs are redacted',
        () async {
      String? receivedAuthHeader;
      String? receivedTokenParam;
      Map<String, dynamic>? receivedBody;

      server.listen((final request) async {
        receivedAuthHeader = request.headers.value('authorization');
        receivedTokenParam = request.uri.queryParameters['token'];

        final bodyBytes = await request.fold<List<int>>(
          <int>[],
          (final acc, final chunk) => acc..addAll(chunk),
        );
        final bodyStr = utf8.decode(bodyBytes);
        receivedBody = jsonDecode(bodyStr) as Map<String, dynamic>?;

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..headers.set('set-cookie', 'session=secret-session-cookie')
          ..write(
            jsonEncode({
              'status': 'authenticated',
              'token': 'jwt-super-secret-token',
              'public_id': 991,
            }),
          );
        await request.response.close();
      });

      final response = await dio.post<Map<String, dynamic>>(
        '/auth/login?token=sensitive-query-token&client_id=my-app',
        data: {
          'email': 'user@example.com',
          'password': 'my-plaintext-password',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer original-secret-bearer-token',
          },
        ),
      );

      // 1. Verify that server received the raw unredacted credentials over the wire
      expect(
        receivedAuthHeader,
        equals('Bearer original-secret-bearer-token'),
      );
      expect(receivedTokenParam, equals('sensitive-query-token'));
      expect(receivedBody?['password'], equals('my-plaintext-password'));
      expect(receivedBody?['email'], equals('user@example.com'));

      // 2. Verify that client application received the full unredacted server response
      expect(response.statusCode, equals(200));
      expect(response.data?['token'], equals('jwt-super-secret-token'));
      expect(response.data?['public_id'], equals(991));

      await Future<void>.value();

      // 3. Verify that logs & cURL never contain the secrets
      for (final log in testLogger.logs) {
        expect(
          log.message.contains('original-secret-bearer-token'),
          isFalse,
          reason: 'Bearer token must not leak in log message',
        );
        expect(
          log.message.contains('sensitive-query-token'),
          isFalse,
          reason: 'Query token must not leak in log message',
        );

        final curl = log.context?['curl'] as String?;
        if (curl != null) {
          expect(curl.contains('original-secret-bearer-token'), isFalse);
          expect(curl.contains('sensitive-query-token'), isFalse);
          expect(curl.contains('my-plaintext-password'), isFalse);
          expect(curl, contains('token='));
          expect(curl, contains('REDACTED'));
          expect(curl, contains('"password":"***REDACTED***"'));
        }

        final bodyContext = log.context?['body'] as String?;
        if (bodyContext != null) {
          expect(bodyContext.contains('my-plaintext-password'), isFalse);
          expect(bodyContext.contains('jwt-super-secret-token'), isFalse);
          expect(bodyContext, contains('***REDACTED***'));
        }

        final headersContext = log.context?['headers'] as Map<String, dynamic>?;
        if (headersContext != null) {
          if (headersContext.containsKey('Authorization')) {
            expect(
              headersContext['Authorization'],
              equals('***REDACTED***'),
            );
          }
          if (headersContext.containsKey('set-cookie')) {
            expect(headersContext['set-cookie'], equals('***REDACTED***'));
          }
        }
      }
    });

    test('Streams and chunked responses work transparently without blocking',
        () async {
      server.listen((final request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.binary;
        request.response.bufferOutput = false;

        for (var i = 1; i <= 5; i++) {
          request.response.write('chunk-$i;');
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await request.response.close();
      });

      final response = await dio.get<ResponseBody>(
        '/stream',
        options: Options(responseType: ResponseType.stream),
      );

      final chunks = <String>[];
      await for (final chunk in response.data!.stream) {
        chunks.add(utf8.decode(chunk));
      }

      final completeString = chunks.join();
      expect(
          completeString, equals('chunk-1;chunk-2;chunk-3;chunk-4;chunk-5;'));

      await Future<void>.value();
      expect(
        testLogger,
        hasLog(
          level: LogLevel.info,
          message: contains('<-- 200 GET $serverUrl/stream'),
        ),
      );
    });

    test('Preserves user custom options.extra across the pipeline', () async {
      server.listen((final request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('ok');
        await request.response.close();
      });

      final customExtra = <String, dynamic>{
        'userMetadataKey': 12345,
        'customTracingToken': 'token-abc',
      };

      final response = await dio.get<String>(
        '/meta',
        options: Options(extra: customExtra),
      );

      expect(response.requestOptions.extra['userMetadataKey'], equals(12345));
      expect(
        response.requestOptions.extra['customTracingToken'],
        equals('token-abc'),
      );
      expect(
        response.requestOptions.extra.containsKey('_logd_dio_sw'),
        isTrue,
      );
    });

    test(
        'Preserves interceptor chain order before and after LogdDioInterceptor',
        () async {
      server.listen((final request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('ok');
        await request.response.close();
      });

      final events = <String>[];

      final beforeInterceptor = InterceptorsWrapper(
        onRequest: (final options, final handler) {
          events.add('before_request');
          handler.next(options);
        },
        onResponse: (final response, final handler) {
          events.add('before_response');
          handler.next(response);
        },
      );

      final afterInterceptor = InterceptorsWrapper(
        onRequest: (final options, final handler) {
          events.add('after_request');
          handler.next(options);
        },
        onResponse: (final response, final handler) {
          events.add('after_response');
          handler.next(response);
        },
      );

      dio.interceptors.insert(0, beforeInterceptor);
      dio.interceptors.add(afterInterceptor);

      await dio.get<String>('/order-test');

      expect(
        events,
        equals([
          'before_request',
          'after_request',
          'before_response',
          'after_response',
        ]),
      );
    });

    test('Handles 204 No Content, 404 Not Found, and 500 Server Error cleanly',
        () async {
      server.listen((final request) async {
        if (request.uri.path == '/empty-204') {
          request.response
            ..statusCode = HttpStatus.noContent
            ..contentLength = 0;
          await request.response.close();
        } else if (request.uri.path == '/err-500') {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'error': 'database_offline'}));
          await request.response.close();
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Route not found');
          await request.response.close();
        }
      });

      // 204 No Content
      final res204 = await dio.get<void>('/empty-204');
      expect(res204.statusCode, equals(204));

      // 404 Not Found
      await expectLater(
        dio.get<String>('/missing-path'),
        throwsA(
          isA<DioException>().having(
            (final e) => e.response?.statusCode,
            'statusCode',
            equals(404),
          ),
        ),
      );

      // 500 Server Error
      await expectLater(
        dio.get<Map<String, dynamic>>('/err-500'),
        throwsA(
          isA<DioException>().having(
            (final e) => e.response?.statusCode,
            'statusCode',
            equals(500),
          ),
        ),
      );
    });
  });

  group('POSIX Shell Syntax & Command Injection Immunity (bash -n)', () {
    const maliciousTestVectors = <String, Map<String, dynamic>>{
      'Single Quote Escape Breakout': {
        'url': "https://api.example.com/search?q=test'; rm -rf /; echo 'pwned",
        'headers': <String, dynamic>{
          "X-Hdr'; evil_cmd;": "val'; id; '",
        },
        'method': "GET'; rm -rf /; '",
        'data': {'nested': "val'; cat /etc/passwd; '"},
      },
      'Backtick Command Execution': {
        'url': 'https://api.example.com/exec?token=`touch /tmp/pwned`',
        'headers': <String, dynamic>{
          '`whoami`': '`id`',
        },
        'method': '`ls -la`',
        'data': {'key': '`uname -a`'},
      },
      'Shell Subshell Substitution': {
        'url': 'https://api.example.com/data?q=\$(cat /etc/shadow)',
        'headers': <String, dynamic>{
          'X-User': '\$(whoami)',
        },
        'method': '\$(rm -rf /)',
        'data': {'cmd': '\$(reboot)'},
      },
      'Shell Variable Expansion & Pipeline': {
        'url': 'https://api.example.com/test?env=\$PATH&home=\$HOME',
        'headers': <String, dynamic>{
          'X-Env': '\$USER | grep root && false || true',
        },
        'method': 'POST',
        'data': {'field': '\$SHELL && cat /dev/urandom | head -n 10'},
      },
      'Carriage Return & Newline Breakout': {
        'url': "https://api.example.com/v1\r\nmalicious_cmd\necho done",
        'headers': <String, dynamic>{
          "X-Multi\r\nLine": "value\nwith\r\nbreaks",
        },
        'method': "POST\nmalicious",
        'data': {'multi': "line1\nline2\r\nline3"},
      },
      'Double Quotes and Dollar Braces': {
        'url': 'https://api.example.com/endpoint?foo="\${PWD}"',
        'headers': <String, dynamic>{
          'X-Test': '"{TEST_KEY}"',
        },
        'method': 'PATCH',
        'data': {'nested': '{"inner": "\${SECRET}"}'},
      },
    };

    for (final entry in maliciousTestVectors.entries) {
      final scenario = entry.key;
      final payload = entry.value;

      test('cURL string generated for $scenario is strictly valid POSIX shell',
          () {
        final options = RequestOptions(
          path: payload['url'] as String,
          method: payload['method'] as String,
          headers: payload['headers'] as Map<String, dynamic>,
          data: payload['data'],
        );

        final curl = LogdCurlGenerator.generate(
          options,
          sensitiveHeaders: {'authorization', 'token', 'x-env'},
          placeholder: '***REDACTED***',
          sensitiveQueryParams: {'token', 'q'},
          sensitiveBodyKeys: {'key', 'cmd', 'nested'},
        );

        // Verify with bash syntax checker (bash -n -c "<command>")
        final result = Process.runSync('/usr/bin/bash', ['-n', '-c', curl]);

        expect(
          result.exitCode,
          equals(0),
          reason:
              'Generated cURL must be valid shell syntax with zero syntax or breakout errors: ${result.stderr}\nCommand: $curl',
        );

        // Verify that command substitution and backticks are strictly enclosed in single quotes
        // In POSIX shell, inside single quotes ('...'), no variable or subshell expansion occurs.
        expect(curl.startsWith('curl '), isTrue);
      });
    }
  });

  group('Edge-Case & Malformed Input Degradation', () {
    test(
        'Handles deeply nested maps and lists (50 levels) without recursion overflow',
        () {
      // Build a 50-level deep nested structure
      Object current = {
        'password': 'deep-password',
        'target': 'found',
      };
      for (var i = 0; i < 50; i++) {
        current = {
          'level_$i': [current],
        };
      }

      final sanitized = LogdSanitizer.sanitizeBody(
        current,
        {'password'},
        '***REDACTED***',
      );

      final jsonStr = jsonEncode(sanitized);
      expect(jsonStr.contains('deep-password'), isFalse);
      expect(jsonStr.contains('***REDACTED***'), isTrue);
      expect(jsonStr.contains('found'), isTrue);
    });

    test('Degrades gracefully on malformed or non-JSON strings', () {
      const xmlString =
          '<root><password>cleartext-secret</password><user>john</user></root>';
      final sanitizedXml = LogdSanitizer.sanitizeBody(
        xmlString,
        {'password'},
        '***REDACTED***',
      );
      // Non-JSON strings are preserved safely without throwing
      expect(sanitizedXml, equals(xmlString));

      const malformedJson = '{"unclosed": "string, "key": 123';
      final sanitizedMalformed = LogdSanitizer.sanitizeBody(
        malformedJson,
        {'unclosed'},
        '***REDACTED***',
      );
      expect(sanitizedMalformed, equals(malformedJson));
    });

    test('Handles non-string Map keys without throwing', () {
      final nonStringKeys = <dynamic, dynamic>{
        123: 'numeric_key_val',
        true: 'boolean_key_val',
        'password': 'sensitive_val',
      };

      final sanitized = LogdSanitizer.sanitizeBody(
        nonStringKeys,
        {'password'},
        '***REDACTED***',
      ) as Map<String, Object?>;

      expect(sanitized['123'], equals('numeric_key_val'));
      expect(sanitized['true'], equals('boolean_key_val'));
      expect(sanitized['password'], equals('***REDACTED***'));
    });

    test('Preserves multiple query parameters with same key', () {
      final uri = Uri.parse(
        'https://api.example.com/items?tag=dart&tag=flutter&token=secret1&token=secret2',
      );

      final sanitized = LogdSanitizer.sanitizeUri(
        uri,
        {'token'},
        '***REDACTED***',
      );

      expect(sanitized.queryParametersAll['tag'], equals(['dart', 'flutter']));
      expect(
        sanitized.queryParametersAll['token'],
        equals(['***REDACTED***', '***REDACTED***']),
      );
    });

    test('safeBodyPreview boundary tests at exact maxBodyLength thresholds',
        () {
      const text = '0123456789'; // length 10

      // maxBodyLength == text.length
      expect(
        LogdSanitizer.safeBodyPreview(text, maxBodyLength: 10),
        equals(text),
      );

      // maxBodyLength == text.length + 1
      expect(
        LogdSanitizer.safeBodyPreview(text, maxBodyLength: 11),
        equals(text),
      );

      // maxBodyLength == text.length - 1
      final truncated =
          LogdSanitizer.safeBodyPreview(text, maxBodyLength: 9) as String;
      expect(truncated.startsWith('012345678...'), isTrue);
      expect(truncated.contains('[truncated 1 chars]'), isTrue);

      // maxBodyLength <= 0 (unlimited)
      expect(
        LogdSanitizer.safeBodyPreview(text, maxBodyLength: 0),
        equals(text),
      );
    });
  });
}
