import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';
import 'package:test/test.dart';

void main() {
  group('Network Sinks Integration (Pure Dart)', () {
    late HttpServer socketServer;
    late HttpServer httpServer;

    final receivedSocketMessages = StreamController<String>.broadcast();
    final receivedHttpBatches = StreamController<List<dynamic>>.broadcast();

    setUpAll(() async {
      // 1. Start pure-Dart WebSocket server on an ephemeral port
      socketServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      socketServer.transform(WebSocketTransformer()).listen((final webSocket) {
        webSocket.listen((final data) {
          receivedSocketMessages.add(data as String);
        });
      });

      // 2. Start pure-Dart HTTP server on an ephemeral port
      httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      httpServer.listen((final request) async {
        if (request.method == 'POST' && request.uri.path == '/logs') {
          final body = await utf8.decoder.bind(request).join();
          final decoded = jsonDecode(body) as List<dynamic>;
          receivedHttpBatches.add(decoded);
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'status': 'ok'}));
          await request.response.close();
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found');
          await request.response.close();
        }
      });
    });

    tearDownAll(() async {
      await socketServer.close(force: true);
      await httpServer.close(force: true);
      await receivedSocketMessages.close();
      await receivedHttpBatches.close();
    });

    setUp(() {
      Logger.reset();
    });

    test('SocketSink streams logs in real-time', () async {
      final sink = SocketSink(
        url: 'ws://127.0.0.1:${socketServer.port}',
      );

      final handler = Handler(
        formatter: const PlainFormatter(metadata: {}),
        sink: sink,
      );

      Logger.configure('test.socket', handlers: [handler]);
      final logger = Logger.get('test.socket');

      final messageFuture = receivedSocketMessages.stream.firstWhere(
        (final msg) => msg.contains('INTEGRATION_TEST_SOCKET'),
      );

      logger.info('INTEGRATION_TEST_SOCKET');

      final receivedMessage = await messageFuture.timeout(
        const Duration(seconds: 5),
      );

      expect(receivedMessage, contains('INTEGRATION_TEST_SOCKET'));
      await sink.dispose();
    });

    test('HttpSink ships logs in batches', () async {
      final sink = HttpSink(
        url: 'http://127.0.0.1:${httpServer.port}/logs',
        batchSize: 2,
      );

      final handler = Handler(
        formatter: const PlainFormatter(metadata: {}),
        sink: sink,
      );

      Logger.configure('test.http', handlers: [handler]);
      final logger = Logger.get('test.http');

      // Send first - should NOT be sent yet because batchSize is 2
      logger.info('log_1');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final batchFuture = receivedHttpBatches.stream.firstWhere(
        (final batch) => batch.length == 2,
      );

      // Send second - should trigger batch flush
      logger.info('INTEGRATION_TEST_HTTP_BATCH');

      final batch = await batchFuture.timeout(
        const Duration(seconds: 5),
      );

      expect(batch.length, equals(2));
      expect(batch[0], contains('log_1'));
      expect(batch[1], contains('INTEGRATION_TEST_HTTP_BATCH'));

      await sink.dispose();
    });

    test(
      'HttpSink retries and succeeds against transient HTTP 500 error',
      () async {
        var failCount = 1;
        final retryServer =
            await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final retryBatches = <List<dynamic>>[];
        final completer = Completer<void>();

        retryServer.listen((final request) async {
          if (failCount > 0) {
            failCount--;
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..write('Temporary Server Error');
            await request.response.close();
          } else {
            final body = await utf8.decoder.bind(request).join();
            retryBatches.add(jsonDecode(body) as List<dynamic>);
            request.response
              ..statusCode = HttpStatus.ok
              ..write('OK');
            await request.response.close();
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        });

        final sink = HttpSink(
          url: 'http://127.0.0.1:${retryServer.port}/retry_logs',
          batchSize: 1,
          maxRetries: 3,
        );

        final handler = Handler(
          formatter: const PlainFormatter(metadata: {}),
          sink: sink,
        );

        Logger.configure('test.http.retry', handlers: [handler]);
        final logger = Logger.get('test.http.retry');

        logger.info('retry_payload');

        await completer.future.timeout(const Duration(seconds: 5));
        expect(retryBatches, hasLength(1));
        expect(retryBatches[0][0], contains('retry_payload'));

        await sink.dispose();
        await retryServer.close(force: true);
      },
    );
  });
}
