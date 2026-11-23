import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

/// Demonstrates W3C TraceContext distributed tracing, network metrics,
/// and automatic HTTP error status elevation with `logd_dio`.
Future<void> main() async {
  Logger.configure(
    'global',
    handlers: [ConsoleHandler(theme: const DarkTheme())],
  );

  final telemetryLogger = Logger.get('telemetry');

  final dio = Dio(
    BaseOptions(
      // Non-throwing status validation so 4xx/5xx are handled in onResponse
      validateStatus: (final _) => true,
    ),
  );
  dio.httpClientAdapter = _MockCloudGatewayAdapter();

  dio.interceptors.add(
    LogdDioInterceptor(
      const LogdDioOptions(
        tracePropagationMode: TracePropagationMode.both,
        traceIdHeader: 'x-request-id',
        extractResponseTraceId: true,
        logMetrics: true,
        elevateHttpErrors: true,
        logCurl: true,
        prettyCurl: true,
      ),
    ),
  );

  telemetryLogger.info(
    '--- 1. Outgoing Request with Ambient W3C Trace Context ---',
  );
  await LogContext.run(
    {
      'traceId': '4bf92f3577b34da6a3ce929d0e0e4736',
      'tracestate': 'congo=t61rcWkgMzE,rojo=1',
    },
    () async {
      await dio.post<void>(
        'https://gateway.cloud.example.com/v1/orders',
        data: {'orderId': 'ord-9021', 'items': 4},
        options: Options(
          headers: {'Authorization': 'Bearer secret-access-token'},
        ),
      );
    },
  );

  telemetryLogger.info(
    '--- 2. Non-throwing 404 Client Error Elevation to Warning ---',
  );
  await dio.get<void>('https://gateway.cloud.example.com/v1/missing');

  telemetryLogger.info(
    '--- 3. Non-throwing 503 Service Failure Elevation to Error ---',
  );
  await dio.get<void>('https://gateway.cloud.example.com/v1/outage');

  telemetryLogger.info('W3C Tracing and Metrics demo completed successfully.');
}

class _MockCloudGatewayAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    final RequestOptions options,
    final Stream<Uint8List>? requestStream,
    final Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    int status = 200;
    String body = '{"status":"ok"}';

    if (path.contains('missing')) {
      status = 404;
      body = '{"error":"Resource not found"}';
    } else if (path.contains('outage')) {
      status = 503;
      body = '{"error":"Downstream cluster unavailable"}';
    }

    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'traceparent': [
          '00-88882f3577b34da6a3ce929d0e0e4736-111167aa0ba902b7-01',
        ],
        'x-request-id': ['gw-srv-trace-4921'],
        'content-length': [body.length.toString()],
      },
    );
  }

  @override
  void close({final bool force = false}) {}
}
