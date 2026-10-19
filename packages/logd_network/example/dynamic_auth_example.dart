import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';

/// Simulated external authentication service (e.g., OAuth2, AWS STS, Keycloak).
class AuthService {
  int _tokenVersion = 0;

  /// Simulates fetching a freshly minted bearer token or rotating HMAC signature.
  Future<String> fetchFreshToken() async {
    // Simulate brief network latency for auth exchange
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _tokenVersion++;
    return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.token-v$_tokenVersion';
  }
}

Future<void> main() async {
  print('=== logd_network: Dynamic Auth Hook Demonstration ===\n');

  // 1. Spin up an in-process HTTP log ingestion server
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  print('[Server] Listening on http://127.0.0.1:${server.port}/api/v1/logs');

  var receivedCount = 0;
  server.listen((final request) async {
    receivedCount++;
    final auth = request.headers.value('authorization') ?? '(missing)';
    final service = request.headers.value('x-service-name') ?? '(missing)';
    final body = await utf8.decoder.bind(request).join();
    final List<dynamic> logs = jsonDecode(body) as List<dynamic>;

    print(
      '\n[Server] Received Batch #$receivedCount (${logs.length} logs)'
      '\n         • Authorization: $auth'
      '\n         • X-Service-Name: $service',
    );
    for (final log in logs) {
      if (log is Map) {
        print('         • [${log['level']}] ${log['message']}');
      }
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..write('{"status": "ok"}');
    await request.response.close();
  });

  // 2. Initialize our simulated auth manager
  final authService = AuthService();

  // 3. Configure HttpSink with static headers AND a dynamic headersProvider
  final httpHandler = Handler(
    formatter: const JsonFormatter(),
    sink: HttpSink(
      url: 'http://127.0.0.1:${server.port}/api/v1/logs',
      headers: const {
        'X-Service-Name': 'billing-service',
        'X-Environment': 'production',
      },
      // headersProvider is called before each batch POST
      headersProvider: () async {
        final token = await authService.fetchFreshToken();
        return {'Authorization': 'Bearer $token'};
      },
      batchSize: 2, // Flush every 2 logs
      flushInterval: const Duration(seconds: 1),
    ),
  );

  Logger.configure('billing', handlers: [httpHandler]);
  final logger = Logger.get('billing');

  // 4. Emit logs for Batch #1
  print('\n[Client] Emitting 2 logs (triggers Batch #1)...');
  logger.info('Order invoice created', context: {'invoiceId': 'INV-4091'});
  logger.info('Tax calculated via Avalara', context: {'taxAmount': 8.50});
  await Future<void>.delayed(const Duration(milliseconds: 300));

  // 5. Emit logs for Batch #2 — headersProvider is re-evaluated with a new token!
  print(
      '\n[Client] Emitting 2 logs (triggers Batch #2 with fresh auth token)...');
  logger.warning('Payment gateway retry needed (attempt 1/3)');
  logger.info('Payment captured successfully via Stripe');
  await Future<void>.delayed(const Duration(milliseconds: 300));

  // 6. Clean teardown
  await httpHandler.sink.dispose();
  await server.close(force: true);

  print('\n=== Demonstration Completed Successfully ===');
}
