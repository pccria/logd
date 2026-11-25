import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd/testing.dart';
import 'package:logd_dio/logd_dio.dart';
import 'package:test/test.dart';

class _MockCustomPayload {
  const _MockCustomPayload(this.orderId, this.secretToken);
  final String orderId;
  final String secretToken;
}

void main() {
  group('LogdBodySerializer & Pluggable Serializer Tests', () {
    test('FunctionalBodySerializer formats custom domain models', () {
      final serializer = FunctionalBodySerializer(
        predicate: (final data, final ct) => data is _MockCustomPayload,
        formatter: (final data, final ct) {
          final payload = data as _MockCustomPayload;
          return '{"orderId":"${payload.orderId}","token":"${payload.secretToken}"}';
        },
      );

      final preview = LogdSanitizer.safeBodyPreview(
        const _MockCustomPayload('ord-9921', 'super-secret-token'),
        maxBodyLength: 512,
        sensitiveKeys: {'token'},
        serializers: [serializer],
      );

      expect(preview, isNotNull);
      expect(preview.toString().contains('"orderId":"ord-9921"'), isTrue);
      expect(preview.toString().contains('"token":"***REDACTED***"'), isTrue);
    });

    test('falls back to default preview when no serializer applies', () {
      final serializer = FunctionalBodySerializer(
        predicate: (final data, final ct) => false,
        formatter: (final data, final ct) => 'never-called',
      );

      final preview = LogdSanitizer.safeBodyPreview(
        {'status': 'active'},
        maxBodyLength: 512,
        serializers: [serializer],
      );

      expect(preview, '{"status":"active"}');
    });
  });

  group('cURL Generator Enhancements', () {
    test(
      'appends --compressed when Accept-Encoding contains compression algorithms',
      () {
        final options = RequestOptions(
          path: 'https://api.example.com/items',
          method: 'GET',
          headers: {'Accept-Encoding': 'gzip, deflate, br'},
        );

        final curl = LogdCurlGenerator.generate(
          options,
          sensitiveHeaders: {},
          placeholder: '***REDACTED***',
          includeCompressed: true,
        );

        expect(curl.contains('--compressed'), isTrue);
      },
    );

    test('omits --compressed when includeCompressed is false', () {
      final options = RequestOptions(
        path: 'https://api.example.com/items',
        method: 'GET',
        headers: {'Accept-Encoding': 'gzip'},
      );

      final curl = LogdCurlGenerator.generate(
        options,
        sensitiveHeaders: {},
        placeholder: '***REDACTED***',
        includeCompressed: false,
      );

      expect(curl.contains('--compressed'), isFalse);
    });

    test('formats pretty multiline cURL commands with backslash breaks', () {
      final options = RequestOptions(
        path: 'https://api.example.com/orders',
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer secret-token',
        },
        data: {'item': 'widget'},
      );

      final prettyCurl = LogdCurlGenerator.generate(
        options,
        sensitiveHeaders: {'authorization'},
        placeholder: '***REDACTED***',
        pretty: true,
      );

      expect(prettyCurl.contains(' \\\n  -X POST'), isTrue);
      expect(
        prettyCurl.contains(' \\\n  -H \'Accept: application/json\''),
        isTrue,
      );
      expect(
        prettyCurl.contains(' \\\n  -H \'Authorization: ***REDACTED***\''),
        isTrue,
      );
      expect(
        prettyCurl.contains(' \\\n  --data-raw \'{"item":"widget"}\''),
        isTrue,
      );
    });
  });

  group('HTTP Status Code Error Elevation', () {
    late Dio dio;
    late _CustomStatusAdapter adapter;
    late TestLogger testLogger;

    setUp(() {
      testLogger = TestLogger('test_elevation');
      adapter = _CustomStatusAdapter();
      dio = Dio(
        BaseOptions(
          // Don't throw DioException for 4xx/5xx to test onResponse elevation
          validateStatus: (final _) => true,
        ),
      )..httpClientAdapter = adapter;
    });

    tearDown(() {
      testLogger.dispose();
    });

    test(
      'elevates 404 to warning and 500 to error when elevateHttpErrors is true',
      () async {
        dio.interceptors.add(
          LogdDioInterceptor(
            LogdDioOptions(
              logger: testLogger.logger,
              elevateHttpErrors: true,
              responseLevel: LogLevel.info,
              warningLevel: LogLevel.warning,
              errorLevel: LogLevel.error,
            ),
          ),
        );

        // 1. 200 OK -> info
        adapter.cannedStatus = 200;
        await dio.get<void>('https://api.example.com/ok');
        expect(testLogger.logs.last.level, LogLevel.info);

        // 2. 404 Not Found -> warning
        adapter.cannedStatus = 404;
        await dio.get<void>('https://api.example.com/missing');
        expect(testLogger.logs.last.level, LogLevel.warning);

        // 3. 500 Internal Error -> error
        adapter.cannedStatus = 500;
        await dio.get<void>('https://api.example.com/crash');
        expect(testLogger.logs.last.level, LogLevel.error);
      },
    );

    test(
      'retains default responseLevel when elevateHttpErrors is false',
      () async {
        dio.interceptors.add(
          LogdDioInterceptor(
            LogdDioOptions(
              logger: testLogger.logger,
              elevateHttpErrors: false,
              responseLevel: LogLevel.info,
            ),
          ),
        );

        adapter.cannedStatus = 500;
        await dio.get<void>('https://api.example.com/crash');
        expect(testLogger.logs.last.level, LogLevel.info);
      },
    );
  });
}

class _CustomStatusAdapter implements HttpClientAdapter {
  int cannedStatus = 200;

  @override
  Future<ResponseBody> fetch(
    final RequestOptions options,
    final Stream<dynamic>? requestStream,
    final Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"status": $cannedStatus}',
    cannedStatus,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({final bool force = false}) {}
}
