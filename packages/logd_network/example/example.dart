import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

void main() async {
  // Pre-wired HTTP & WebSocket browser dashboard
  final dashboard = HttpDashboardHandler(
    port: 8080,
    title: 'Production Telemetry Stream',
    bufferCapacity: 200,
  );

  // HTTP POST batching sink with exponential backoff retries
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

  Logger.configure('app', handlers: [dashboard, httpHandler]);

  final logger = Logger.get('app.service');
  logger.info('Network observability pipeline initialized');
  logger.warning('High memory pressure detected', context: {'usage': '87%'});
  logger.error('Circuit breaker tripped for payment-service');

  // Dispose dashboard and flush network buffers on app exit
  await dashboard.dispose();
  await httpHandler.sink.dispose();
}
