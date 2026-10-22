import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

/// In-depth example demonstrating Advanced Configuration, cURL Generation,
/// and Custom Logging Pipelines with `logd_dio`.
///
/// Features highlighted:
/// 1. Copy-pasteable cURL command generation (`logCurl: true`) with sensitive
///    credentials safely redacted.
/// 2. Opt-in response headers logging (`logResponseHeaders: true`).
/// 3. Fine-tuned log levels per lifecycle phase (trace for requests, debug
///    for responses, error for failures).
/// 4. Routing HTTP logs to a dedicated, isolated [Logger] instance with
///    specialized handlers.
/// 5. Suppressing body payloads for high-throughput or binary pipelines.
Future<void> main() async {
  // 1. Configure a dedicated logger pipeline for network telemetry
  final networkLogger = Logger.get('telemetry.http');

  Logger.configure('telemetry', handlers: [
    ConsoleHandler(theme: const DarkTheme()),
  ]);

  // 2. Configure Dio with advanced options
  final dio = Dio();
  dio.httpClientAdapter = _CannedApiResponseAdapter();

  dio.interceptors.add(
    LogdDioInterceptor(
      LogdDioOptions(
        // Route all logs through our custom dedicated logger
        logger: networkLogger,

        // Generate executable cURL commands
        logCurl: true,

        // Include response headers in context (useful for caching/rate-limit inspection)
        logResponseHeaders: true,

        // Fine-tuned log levels
        requestLevel: LogLevel.trace,
        responseLevel: LogLevel.debug,
        errorLevel: LogLevel.error,
        cancelLevel: LogLevel.trace,

        // Maximum body length
        maxBodyLength: 256,
      ),
    ),
  );

  networkLogger.info('Starting Advanced Configuration & cURL Demo');

  // Scenario A: Request with cURL generation & response headers inspection
  networkLogger
      .info('--- Scenario A: Executing POST with cURL & Response Headers ---');
  await dio.post<void>(
    'https://api.example.com/v2/compute/job',
    queryParameters: {'priority': 'high', 'env': 'staging'},
    data: {
      'jobType': 'ml_training',
      'dataset': 'telemetry_q4',
      'epochs': 50,
    },
    options: Options(
      headers: {
        'Authorization': 'Bearer test-bearer-token',
        'X-Job-Client': 'logd-agent-worker',
      },
    ),
  );

  // Scenario B: High-Throughput Minimal Mode (Headers & Body disabled)
  networkLogger
      .info('--- Scenario B: High-Throughput Lightweight Interceptor ---');
  final fastDio = Dio();
  fastDio.httpClientAdapter = _CannedApiResponseAdapter();

  fastDio.interceptors.add(
    LogdDioInterceptor(
      LogdDioOptions(
        logger: networkLogger,
        logRequestHeaders: false,
        logRequestBody: false,
        logResponseHeaders: false,
        logResponseBody: false,
        responseLevel: LogLevel.info,
      ),
    ),
  );

  await fastDio.get<void>('https://api.example.com/stream/metrics');

  networkLogger.info('Advanced Configuration Demo completed successfully.');
}

/// Simulated adapter returning realistic server headers (e.g. rate limits, caching).
class _CannedApiResponseAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    final RequestOptions options,
    final Stream<Uint8List>? requestStream,
    final Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"jobId": "job-99120", "status": "queued", "estimatedSeconds": 45}',
      202,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'x-ratelimit-limit': ['1000'],
        'x-ratelimit-remaining': ['985'],
        'cache-control': ['no-store, max-age=0'],
        'set-cookie': ['session_id=confidential_cookie_123'],
      },
    );
  }

  @override
  void close({final bool force = false}) {}
}
