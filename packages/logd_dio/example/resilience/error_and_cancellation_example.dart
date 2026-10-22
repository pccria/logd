import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

/// In-depth example demonstrating Error Resilience and Cancellation handling
/// in `logd_dio`.
///
/// Features highlighted:
/// 1. Cancellation awareness: User aborts via [CancelToken] are logged at
///    [cancelLevel] (debug by default) rather than generating spurious error alerts.
/// 2. Operational error logging: HTTP 4xx and 5xx failures are logged with status
///    codes, error response bodies, elapsed latency, and stack traces.
/// 3. Connection and timeout error diagnostics.
Future<void> main() async {
  // 1. Configure logd console output
  Logger.configure('global', handlers: [
    ConsoleHandler(theme: const DarkTheme()),
  ]);

  final appLogger = Logger.get('resilience_demo');
  appLogger.info('Starting Resilience & Cancellation Demo');

  // 2. Configure Dio with LogdDioInterceptor
  final dio = Dio();
  dio.httpClientAdapter = _FaultInjectingAdapter();

  dio.interceptors.add(
    LogdDioInterceptor(
      const LogdDioOptions(
        // Cancellations are intentionally logged as debug to keep production error feeds clean
        cancelLevel: LogLevel.debug,
        // Real errors are logged as error with diagnostic payload
        errorLevel: LogLevel.error,
        logResponseBody: true,
      ),
    ),
  );

  // Scenario A: User Cancellation with CancelToken
  appLogger.info('--- Scenario A: User Cancellation with CancelToken ---');
  final cancelToken = CancelToken();

  final pendingRequest = dio.get<void>(
    'https://api.example.com/slow-endpoint',
    cancelToken: cancelToken,
  );

  // Simulate user pressing "Cancel" or navigating away after 20ms
  await Future<void>.delayed(const Duration(milliseconds: 20));
  cancelToken.cancel('User navigated away before completion');

  try {
    await pendingRequest;
  } on DioException catch (e) {
    appLogger.debug('Caught expected cancellation in caller: ${e.message}');
  }

  // Scenario B: HTTP 500 Internal Server Failure
  appLogger.info('--- Scenario B: Server 500 Failure Diagnostics ---');
  try {
    await dio.post<void>(
      'https://api.example.com/faulty-endpoint',
      data: {'action': 'process_payment'},
    );
  } on DioException catch (e) {
    appLogger.warning('Caught server error: ${e.response?.statusCode}');
  }

  // Scenario C: HTTP 404 Not Found Client Error
  appLogger.info('--- Scenario C: HTTP 404 Client Error ---');
  try {
    await dio.get<void>('https://api.example.com/not-found');
  } on DioException catch (e) {
    appLogger.warning('Resource not found: ${e.requestOptions.uri}');
  }

  appLogger.info('Resilience & Cancellation Demo completed successfully.');
}

/// Simulated adapter that simulates faults, timeouts, and cancellations.
class _FaultInjectingAdapter implements HttpClientAdapter {
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
            reason: 'User navigated away before completion',
          ),
        );
      }
    });

    if (options.path.contains('slow-endpoint')) {
      // Intentionally hangs until cancelled
      return completer.future;
    }

    if (options.path.contains('faulty-endpoint')) {
      // Simulate HTTP 500 error
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 500,
          data: {
            'error': 'InternalServerError',
            'code': 'DB_POOL_EXHAUSTED',
            'detail': 'Database connection pool timed out after 3000ms',
          },
        ),
      );
    }

    if (options.path.contains('not-found')) {
      // Simulate HTTP 404 error
      throw DioException.badResponse(
        statusCode: 404,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 404,
          data: {'error': 'ResourceNotFound', 'id': 'missing-record-1'},
        ),
      );
    }

    return Future.value(
      ResponseBody.fromString('{"status": "ok"}', 200),
    );
  }

  @override
  void close({final bool force = false}) {}
}
