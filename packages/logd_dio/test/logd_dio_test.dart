import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd/testing.dart';
import 'package:logd_dio/logd_dio.dart';
import 'package:test/test.dart';

void main() {
  group('LogdSanitizer', () {
    test('redacts sensitive headers case-insensitively', () {
      final headers = {
        'Authorization': 'Bearer 123456',
        'COOKIE': 'session=abc',
        'X-Custom-Header': 'public-value',
      };

      final sanitized = LogdSanitizer.sanitizeHeaders(
        headers,
        LogdDioOptions.defaultSensitiveHeaders,
        '***REDACTED***',
      );

      expect(sanitized['Authorization'], equals('***REDACTED***'));
      expect(sanitized['COOKIE'], equals('***REDACTED***'));
      expect(sanitized['X-Custom-Header'], equals('public-value'));
    });

    test('redacts sensitive query parameters', () {
      final query = {
        'api_key': 'secret-123',
        'TOKEN': 'bearer-abc',
        'page': '1',
      };

      final sanitized = LogdSanitizer.sanitizeQueryParams(
        query,
        LogdDioOptions.defaultSensitiveQueryParams,
        '***REDACTED***',
      );

      expect(sanitized['api_key'], equals('***REDACTED***'));
      expect(sanitized['TOKEN'], equals('***REDACTED***'));
      expect(sanitized['page'], equals('1'));
    });

    test('safely truncates long body strings', () {
      final longString = 'a' * 200;
      final preview =
          LogdSanitizer.safeBodyPreview(longString, maxBodyLength: 50);

      expect(preview, isA<String>());
      expect((preview! as String).startsWith('a' * 50), isTrue);
      expect((preview as String).contains('[truncated 150 chars]'), isTrue);
    });

    test('formats FormData and binary list safely without error', () {
      final formData = FormData.fromMap({
        'user': 'alice',
      });
      final binary = [0, 1, 2, 3, 4];

      expect(
        LogdSanitizer.safeBodyPreview(formData, maxBodyLength: 100),
        contains('FormData with 1 fields'),
      );
      expect(
        LogdSanitizer.safeBodyPreview(binary, maxBodyLength: 100),
        equals('[Binary data: 5 bytes]'),
      );
    });
  });

  group('LogdCurlGenerator', () {
    test('generates valid curl command for GET request', () {
      final options = RequestOptions(
        path: 'https://api.example.com/users',
        method: 'GET',
        headers: {'Accept': 'application/json'},
      );

      final curl = LogdCurlGenerator.generate(
        options,
        sensitiveHeaders: LogdDioOptions.defaultSensitiveHeaders,
        placeholder: '***REDACTED***',
      );

      expect(curl, contains('curl -X GET'));
      expect(curl, contains("-H 'Accept: application/json'"));
      expect(curl, contains("'https://api.example.com/users'"));
    });

    test('generates curl with sanitized sensitive headers and payload', () {
      final options = RequestOptions(
        path: 'https://api.example.com/login',
        method: 'POST',
        headers: {'Authorization': 'Bearer token123'},
        data: {'username': 'test'},
      );

      final curl = LogdCurlGenerator.generate(
        options,
        sensitiveHeaders: LogdDioOptions.defaultSensitiveHeaders,
        placeholder: '***REDACTED***',
      );

      expect(curl, contains('curl -X POST'));
      expect(curl, contains("-H 'Authorization: ***REDACTED***'"));
      expect(curl, contains('--data-raw \'{"username":"test"}\''));
    });
  });

  group('LogdDioInterceptor', () {
    late TestLogger testLogger;
    late LogdDioInterceptor interceptor;

    setUp(() {
      testLogger = TestLogger('http');
      interceptor = LogdDioInterceptor(
        LogdDioOptions(
          logger: testLogger.logger,
          logCurl: true,
        ),
      );
    });

    tearDown(() {
      testLogger.dispose();
    });

    test('logs outgoing request with headers and cURL', () async {
      final options = RequestOptions(
        path: 'https://api.example.com/data',
        method: 'GET',
        headers: {'Authorization': 'Bearer secret'},
      );

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      await Future<void>.value();

      expect(
        testLogger,
        hasLog(
          level: LogLevel.debug,
          message: '--> GET https://api.example.com/data',
        ),
      );
    });

    test('propagates ambient LogContext requestId into request headers',
        () async {
      final options = RequestOptions(
        path: 'https://api.example.com/data',
        method: 'GET',
      );

      LogContext.run({'requestId': 'req-xyz-999'}, () {
        final handler = RequestInterceptorHandler();
        interceptor.onRequest(options, handler);
      });

      expect(options.headers['x-request-id'], equals('req-xyz-999'));
    });

    test('logs successful response with status and latency', () async {
      final req =
          RequestOptions(path: 'https://api.example.com/data', method: 'GET');
      interceptor.onRequest(req, RequestInterceptorHandler());

      final response = Response(
        requestOptions: req,
        statusCode: 200,
        data: {'success': true},
      );

      interceptor.onResponse(response, ResponseInterceptorHandler());
      await Future<void>.value();

      expect(
        testLogger,
        hasLog(
          level: LogLevel.info,
          message: contains('<-- 200 GET https://api.example.com/data'),
        ),
      );
    });

    test('logs cancellation as debug rather than error', () async {
      final req =
          RequestOptions(path: 'https://api.example.com/data', method: 'GET');
      interceptor.onRequest(req, RequestInterceptorHandler());

      final cancelErr = DioException(
        requestOptions: req,
        type: DioExceptionType.cancel,
        message: 'Request was aborted',
      );

      final handler = _TestErrorHandler();
      interceptor.onError(cancelErr, handler);
      expect(handler.forwardedError, equals(cancelErr));

      expect(
        testLogger,
        hasLog(
          level: LogLevel.debug,
          message: contains('<-- CANCELLED GET https://api.example.com/data'),
        ),
      );
    });

    test('logs server failure as error with diagnostic context', () async {
      final req =
          RequestOptions(path: 'https://api.example.com/fail', method: 'POST');
      interceptor.onRequest(req, RequestInterceptorHandler());

      final serverErr = DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: req,
          statusCode: 500,
          data: {'error': 'Internal server failure'},
        ),
      );

      final handler = _TestErrorHandler();
      interceptor.onError(serverErr, handler);
      expect(handler.forwardedError, equals(serverErr));

      expect(
        testLogger,
        hasLog(
          level: LogLevel.error,
          message: contains('<-- FAILED 500 POST https://api.example.com/fail'),
        ),
      );
    });

    test('propagates traceId when requestId is absent', () async {
      final options = RequestOptions(
        path: 'https://api.example.com/data',
        method: 'GET',
      );

      LogContext.run({'traceId': 'trace-abc-123'}, () {
        final handler = RequestInterceptorHandler();
        interceptor.onRequest(options, handler);
      });

      expect(options.headers['x-request-id'], equals('trace-abc-123'));
    });

    test('does not overwrite existing trace header even if case differs',
        () async {
      final options = RequestOptions(
        path: 'https://api.example.com/data',
        method: 'GET',
        headers: {'X-Request-Id': 'custom-id-999'},
      );

      LogContext.run({'requestId': 'ambient-id-111'}, () {
        final handler = RequestInterceptorHandler();
        interceptor.onRequest(options, handler);
      });

      expect(options.headers['X-Request-Id'], equals('custom-id-999'));
      expect(options.headers['x-request-id'], equals('custom-id-999'));
    });

    test('ignores LogContext when attachAmbientTraceId is disabled', () async {
      final customInterceptor = LogdDioInterceptor(
        LogdDioOptions(
          logger: testLogger.logger,
          attachAmbientTraceId: false,
        ),
      );

      final options = RequestOptions(
        path: 'https://api.example.com/data',
        method: 'GET',
      );

      LogContext.run({'requestId': 'req-999'}, () {
        final handler = RequestInterceptorHandler();
        customInterceptor.onRequest(options, handler);
      });

      expect(options.headers.containsKey('x-request-id'), isFalse);
    });

    test('logs response headers and redacts sensitive response headers',
        () async {
      final customInterceptor = LogdDioInterceptor(
        LogdDioOptions(
          logger: testLogger.logger,
          logResponseHeaders: true,
        ),
      );

      final req =
          RequestOptions(path: 'https://api.example.com/data', method: 'GET');
      customInterceptor.onRequest(req, RequestInterceptorHandler());

      final response = Response(
        requestOptions: req,
        statusCode: 200,
        headers: Headers.fromMap({
          'content-type': ['application/json'],
          'set-cookie': ['session=secret-abc'],
        }),
        data: {'ok': true},
      );

      customInterceptor.onResponse(response, ResponseInterceptorHandler());
      await Future<void>.value();

      expect(
        testLogger,
        hasLog(
          level: LogLevel.info,
          message: contains('<-- 200 GET https://api.example.com/data'),
        ),
      );
    });

    test('handles missing stopwatch in extra gracefully', () async {
      final req =
          RequestOptions(path: 'https://api.example.com/orphan', method: 'GET');
      final response = Response(
        requestOptions: req,
        statusCode: 200,
      );

      // onRequest was never called, so extra does not have the stopwatch
      expect(
        () => interceptor.onResponse(response, ResponseInterceptorHandler()),
        returnsNormally,
      );

      final err = DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
      );
      final handler = _TestErrorHandler();
      expect(
        () => interceptor.onError(err, handler),
        returnsNormally,
      );
      expect(handler.forwardedError, equals(err));
    });
  });

  group('LogdDioInterceptor end-to-end integration with Dio', () {
    late TestLogger testLogger;
    late Dio dio;

    setUp(() {
      testLogger = TestLogger('http');
      dio = Dio();
    });

    tearDown(() {
      dio.close();
      testLogger.dispose();
    });

    test('completes successful request-response lifecycle end-to-end',
        () async {
      dio.httpClientAdapter = _MockHttpClientAdapter((final options) async {
        return ResponseBody.fromString(
          '{"id": 42, "name": "Logd"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      dio.interceptors.add(
        LogdDioInterceptor(
          LogdDioOptions(
            logger: testLogger.logger,
            logCurl: true,
          ),
        ),
      );

      final res = await LogContext.run({'requestId': 'req-e2e-1'}, () async {
        return dio
            .get<Map<String, dynamic>>('https://api.example.com/users/42');
      });

      expect(res.statusCode, equals(200));
      expect(res.data?['name'], equals('Logd'));

      expect(
        testLogger,
        hasLog(
          level: LogLevel.debug,
          message: contains('--> GET https://api.example.com/users/42'),
        ),
      );
      expect(
        testLogger,
        hasLog(
          level: LogLevel.info,
          message: contains('<-- 200 GET https://api.example.com/users/42'),
        ),
      );
    });

    test('handles 404 response end-to-end with error log', () async {
      dio.httpClientAdapter = _MockHttpClientAdapter((final options) async {
        return ResponseBody.fromString(
          '{"error": "Not Found"}',
          404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      dio.interceptors.add(
        LogdDioInterceptor(
          LogdDioOptions(
            logger: testLogger.logger,
          ),
        ),
      );

      await expectLater(
        dio.get<Map<String, dynamic>>('https://api.example.com/missing'),
        throwsA(isA<DioException>()),
      );

      expect(
        testLogger,
        hasLog(
          level: LogLevel.error,
          message:
              contains('<-- FAILED 404 GET https://api.example.com/missing'),
        ),
      );
    });

    test('handles CancelToken cancellation end-to-end', () async {
      final cancelToken = CancelToken();

      dio.httpClientAdapter = _MockHttpClientAdapter((final options) async {
        // Simulate a long-running request that gets interrupted by cancellation
        await Completer<void>().future;
        return ResponseBody.fromString('', 200);
      });

      dio.interceptors.add(
        LogdDioInterceptor(
          LogdDioOptions(
            logger: testLogger.logger,
          ),
        ),
      );

      final requestFuture = dio.get<void>(
        'https://api.example.com/stream',
        cancelToken: cancelToken,
      );

      // Cancel while request is in-flight
      cancelToken.cancel('User cancelled action');

      await expectLater(
        requestFuture,
        throwsA(
          isA<DioException>().having(
            (final e) => e.type,
            'type',
            equals(DioExceptionType.cancel),
          ),
        ),
      );

      expect(
        testLogger,
        hasLog(
          level: LogLevel.debug,
          message: contains('<-- CANCELLED GET https://api.example.com/stream'),
        ),
      );
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    final RequestOptions options,
    final Stream<Uint8List>? requestStream,
    final Future<void>? cancelFuture,
  ) {
    final completer = Completer<ResponseBody>();

    cancelFuture?.then((final _) {
      if (!completer.isCompleted) {
        completer.completeError(
          DioException.requestCancelled(
            requestOptions: options,
            reason: 'cancelled',
          ),
        );
      }
    });

    handler(options).then((final res) {
      if (!completer.isCompleted) {
        completer.complete(res);
      }
    }).catchError((final Object err, final StackTrace st) {
      if (!completer.isCompleted) {
        completer.completeError(err, st);
      }
    });

    return completer.future;
  }

  @override
  void close({final bool force = false}) {}
}

class _TestErrorHandler extends ErrorInterceptorHandler {
  DioException? forwardedError;

  @override
  void next(final DioException err) {
    forwardedError = err;
  }
}
