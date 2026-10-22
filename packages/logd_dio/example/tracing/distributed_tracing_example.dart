import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

/// In-depth example demonstrating Distributed Tracing and Ambient Context
/// propagation with `logd_dio` and `LogContext`.
///
/// Features highlighted:
/// 1. Automatic propagation of ambient `requestId` into outgoing HTTP headers.
/// 2. Configuring custom trace header names (e.g. `x-correlation-id`).
/// 3. Trace ID fallback resolution (`traceId` when `requestId` is omitted).
/// 4. Concurrent asynchronous isolation: zero cross-talk between multiple
///    in-flight requests executing under separate [LogContext] zones.
Future<void> main() async {
  // 1. Configure logd console output
  Logger.configure('global', handlers: [
    ConsoleHandler(theme: const DarkTheme()),
  ]);

  final appLogger = Logger.get('checkout_service');

  // 2. Configure Dio with custom distributed trace header
  final dio = Dio();
  dio.httpClientAdapter = _EchoHeaderHttpAdapter();

  dio.interceptors.add(
    LogdDioInterceptor(
      const LogdDioOptions(
        attachAmbientTraceId: true,
        traceIdHeader: 'x-correlation-id', // Standard enterprise header
        logRequestHeaders: true,
      ),
    ),
  );

  appLogger.info('Starting Distributed Tracing Demo');

  // Scenario A: Single Trace Scope
  appLogger
      .info('--- Scenario A: Sequential Request inside LogContext Scope ---');
  await LogContext.run({
    'requestId': 'req-order-9821',
    'tenantId': 'enterprise-corp',
    'userId': 4002,
  }, () async {
    appLogger.info('Preparing order payload...');
    await dio.post<void>(
      'https://api.example.com/orders',
      data: {'item': 'Widget Pro', 'qty': 2},
    );
    appLogger.info('Order placed successfully.');
  });

  // Scenario B: Concurrent Asynchronous Requests (Zero Cross-Talk Verification)
  appLogger.info('--- Scenario B: Concurrent Requests in Isolated Zones ---');
  await Future.wait([
    // Worker 1: Customer Alice
    LogContext.run({
      'requestId': 'worker-alice-001',
      'customer': 'Alice',
    }, () async {
      appLogger.info('Alice worker initiating payment...');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await dio.post<void>(
        'https://api.example.com/payments',
        data: {'customer': 'Alice', 'amount': 150.0},
      );
      appLogger.info('Alice payment complete.');
    }),

    // Worker 2: Customer Bob
    LogContext.run({
      'requestId': 'worker-bob-002',
      'customer': 'Bob',
    }, () async {
      appLogger.info('Bob worker initiating payment...');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await dio.post<void>(
        'https://api.example.com/payments',
        data: {'customer': 'Bob', 'amount': 89.5},
      );
      appLogger.info('Bob payment complete.');
    }),
  ]);

  // Scenario C: Trace ID Fallback
  appLogger
      .info('--- Scenario C: Fallback to traceId when requestId is absent ---');
  await LogContext.run({
    'traceId': 'trace-uuid-4488-bbf',
  }, () async {
    await dio.get<void>('https://api.example.com/inventory/check');
  });

  appLogger.info('Distributed Tracing Demo completed successfully.');
}

/// Simulated adapter that echoes back sent headers in response body for verification.
class _EchoHeaderHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    final RequestOptions options,
    final Stream<Uint8List>? requestStream,
    final Future<void>? cancelFuture,
  ) async {
    final correlationId = options.headers['x-correlation-id'] ?? 'none';
    return ResponseBody.fromString(
      '{"status": "ok", "echoCorrelationId": "$correlationId"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({final bool force = false}) {}
}
