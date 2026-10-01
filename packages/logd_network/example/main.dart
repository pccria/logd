import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

void main() async {
  // Always register serializers when using isolates or async handlers
  registerLogdNetworkSerializers();

  // 1. Asynchronous real-time HTTP & WebSocket browser dashboard on background isolate
  final dashboard = HttpDashboardHandler.async(
    port: 8080,
    title: 'Production Telemetry Stream',
    bufferCapacity: 200,
  );

  // 2. HTTP POST batching sink with exponential backoff retries
  final httpHandler = Handler(
    formatter: const JsonFormatter(),
    sink: HttpSink(
      url: 'https://logs.example.com/api/v1/ingest',
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
