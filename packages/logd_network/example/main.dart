import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

void main() async {
  // Always register serializers when using isolates or async handlers
  registerLogdNetworkSerializers();

  // 1. Asynchronous real-time HTTP & WebSocket browser dashboard on background isolate
  final dashboard = HttpDashboardHandler.async(
    port: 0,
    title: 'Production Telemetry Stream',
    bufferCapacity: 200,
  );

  // 2. Resilient HTTP POST sink with failover endpoints and circuit breaker
  final httpHandler = Handler(
    formatter: const JsonFormatter(),
    sink: HttpSink(
      url: 'https://primary.logs.example.com/api/v1/ingest',
      failoverUrls: const [
        'https://backup.logs.example.com/api/v1/ingest',
      ],
      failureThreshold: 5,
      recoveryTimeout: const Duration(seconds: 30),
      headers: const {'X-Service': 'checkout-service'},
      // Dynamic auth hook: refreshed before each batch POST (e.g. OAuth2 tokens)
      headersProvider: () async => {
        'Authorization': 'Bearer dynamic-oauth2-token-xyz',
      },
      batchSize: 50,
      flushInterval: const Duration(seconds: 30),
      maxRetries: 3,
      dropPolicy: DropPolicy.discardOldest,
    ),
  );

  // 3. Configure logd pipeline with network handlers
  Logger.configure('app', handlers: [dashboard, httpHandler]);

  // 4. Emit telemetry logs
  Logger.get('app.service')
    ..info('Network observability pipeline initialized')
    ..warning('High memory pressure detected', context: const {'usage': '87%'})
    ..error('Circuit breaker tripped for payment-service');

  // 5. Clean teardown on exit
  await dashboard.dispose();
  await httpHandler.sink.dispose();
  print('Network handlers disposed cleanly.');
}
