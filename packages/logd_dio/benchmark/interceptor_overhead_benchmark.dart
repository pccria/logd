import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

void main() {
  const iterations = 10000;

  // 1. Benchmark LogdSanitizer.sanitizeUri
  final testUri = Uri.parse(
    'https://api.example.com/v1/orders/lookup?client_id=123&token=super-secret-token-value&status=active&api_key=secret-api-key',
  );
  final sensitiveQueryParams = LogdDioOptions.defaultSensitiveQueryParams;

  // Warmup
  for (var i = 0; i < 1000; i++) {
    LogdSanitizer.sanitizeUri(testUri, sensitiveQueryParams, '***REDACTED***');
  }

  final swUri = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    LogdSanitizer.sanitizeUri(testUri, sensitiveQueryParams, '***REDACTED***');
  }
  swUri.stop();
  final uriUsPerOp =
      (swUri.elapsedMicroseconds / iterations).toStringAsFixed(2);
  final uriOpsSec =
      (iterations / (swUri.elapsedMicroseconds / 1000000)).toStringAsFixed(0);

  // 2. Benchmark LogdSanitizer.sanitizeBody
  final complexPayload = {
    'email': 'user@example.com',
    'password': 'cleartext-password-to-redact',
    'profile': {
      'first_name': 'John',
      'last_name': 'Doe',
      'token': 'jwt-access-token-to-redact',
      'credit_card': '4111-1111-1111-1234',
      'metadata': {
        'tags': ['vip', 'enterprise'],
        'api_key': 'internal-api-key',
      },
    },
    'items': [
      {'item_id': 1, 'price': 99.99},
      {'item_id': 2, 'price': 14.50, 'pin': '1234'},
    ],
  };
  final sensitiveBodyKeys = LogdDioOptions.defaultSensitiveBodyKeys;

  // Warmup
  for (var i = 0; i < 1000; i++) {
    LogdSanitizer.sanitizeBody(
      complexPayload,
      sensitiveBodyKeys,
      '***REDACTED***',
    );
  }

  final swBody = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    LogdSanitizer.sanitizeBody(
      complexPayload,
      sensitiveBodyKeys,
      '***REDACTED***',
    );
  }
  swBody.stop();
  final bodyUsPerOp =
      (swBody.elapsedMicroseconds / iterations).toStringAsFixed(2);
  final bodyOpsSec =
      (iterations / (swBody.elapsedMicroseconds / 1000000)).toStringAsFixed(0);

  // 3. Benchmark LogdCurlGenerator.generate
  final requestOptions = RequestOptions(
    path:
        'https://api.example.com/v1/orders/lookup?client_id=123&token=super-secret-token-value&status=active',
    method: 'POST',
    headers: {
      'authorization': 'Bearer secret-jwt-token',
      'content-type': 'application/json',
      'x-custom-id': '99021',
    },
    data: complexPayload,
  );

  // Warmup
  for (var i = 0; i < 1000; i++) {
    LogdCurlGenerator.generate(
      requestOptions,
      sensitiveHeaders: LogdDioOptions.defaultSensitiveHeaders,
      placeholder: '***REDACTED***',
      sensitiveQueryParams: sensitiveQueryParams,
      sensitiveBodyKeys: sensitiveBodyKeys,
    );
  }

  final swCurl = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    LogdCurlGenerator.generate(
      requestOptions,
      sensitiveHeaders: LogdDioOptions.defaultSensitiveHeaders,
      placeholder: '***REDACTED***',
      sensitiveQueryParams: sensitiveQueryParams,
      sensitiveBodyKeys: sensitiveBodyKeys,
    );
  }
  swCurl.stop();
  final curlUsPerOp =
      (swCurl.elapsedMicroseconds / iterations).toStringAsFixed(2);
  final curlOpsSec =
      (iterations / (swCurl.elapsedMicroseconds / 1000000)).toStringAsFixed(0);

  // 4. Benchmark Full Interceptor Request + Response Cycle
  // Configure dev-null sink to measure pure CPU overhead without terminal I/O
  Logger.configure(
    'bench_http',
    handlers: [
      Handler(
        formatter: const PlainFormatter(),
        sink: _DevNullSink(),
      ),
    ],
  );
  final noopLogger = Logger.get('bench_http');
  final interceptor = LogdDioInterceptor(
    LogdDioOptions(
      logger: noopLogger,
      logCurl: true,
      logRequestHeaders: true,
      logRequestBody: true,
      logResponseHeaders: true,
      logResponseBody: true,
    ),
  );

  final dummyHandlerReq = _NoopRequestHandler();
  final dummyHandlerRes = _NoopResponseHandler();

  // Warmup
  for (var i = 0; i < 1000; i++) {
    final req = RequestOptions(
      path:
          'https://api.example.com/v1/orders/lookup?client_id=123&token=super-secret-token-value',
      method: 'POST',
      headers: {'authorization': 'Bearer secret-jwt'},
      data: complexPayload,
    );
    interceptor.onRequest(req, dummyHandlerReq);
    final res = Response(
      requestOptions: req,
      statusCode: 200,
      data: {'status': 'success', 'token': 'new-token'},
    );
    interceptor.onResponse(res, dummyHandlerRes);
  }

  final swCycle = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    final req = RequestOptions(
      path:
          'https://api.example.com/v1/orders/lookup?client_id=123&token=super-secret-token-value',
      method: 'POST',
      headers: {'authorization': 'Bearer secret-jwt'},
      data: complexPayload,
    );
    interceptor.onRequest(req, dummyHandlerReq);
    final res = Response(
      requestOptions: req,
      statusCode: 200,
      data: {'status': 'success', 'token': 'new-token'},
    );
    interceptor.onResponse(res, dummyHandlerRes);
  }
  swCycle.stop();
  final cycleUsPerOp =
      (swCycle.elapsedMicroseconds / iterations).toStringAsFixed(2);
  final cycleOpsSec =
      (iterations / (swCycle.elapsedMicroseconds / 1000000)).toStringAsFixed(0);

  print('===============================================================');
  print('          logd_dio Sanitization & Overhead Benchmark           ');
  print('                  (10,000 iterations per test)                 ');
  print('===============================================================');
  print('1. Uri Sanitization (URI parsing & query params redaction):');
  print('   -> Average latency: $uriUsPerOp µs/op ($uriOpsSec ops/sec)');
  print('2. Body Sanitization (deep nested map/list traversal & redaction):');
  print('   -> Average latency: $bodyUsPerOp µs/op ($bodyOpsSec ops/sec)');
  print('3. cURL Generator (full command building with shell escaping):');
  print('   -> Average latency: $curlUsPerOp µs/op ($curlOpsSec ops/sec)');
  print('4. Full Lifecycle Overhead (onRequest + onResponse combined):');
  print('   -> Average latency: $cycleUsPerOp µs/op ($cycleOpsSec ops/sec)');
  print('===============================================================');
}

class _NoopRequestHandler extends RequestInterceptorHandler {
  @override
  void next(final RequestOptions requestOptions) {}
}

class _NoopResponseHandler extends ResponseInterceptorHandler {
  @override
  void next(final Response response) {}
}

final class _DevNullSink extends LogSink<LogDocument> {
  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {}
}
