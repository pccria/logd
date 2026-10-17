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

    test('HttpSink delivers logs with dynamic auth headersProvider', () async {
      final authServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final receivedHeaders = <String, String>{};
      final completer = Completer<void>();

      authServer.listen((final request) async {
        if (request.method == 'POST') {
          request.headers.forEach((final name, final values) {
            receivedHeaders[name] = values.join(',');
          });
          // Consume request body to release socket
          await utf8.decoder.bind(request).drain<void>();
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
        url: 'http://127.0.0.1:${authServer.port}/auth_logs',
        batchSize: 1,
        headers: const {'X-Static-Client': 'mobile-app'},
        headersProvider: () async => {
          'Authorization': 'Bearer dynamic-oauth-token-789',
        },
      );

      final handler = Handler(
        formatter: const PlainFormatter(metadata: {}),
        sink: sink,
      );

      Logger.configure('test.http.auth', handlers: [handler]);
      final logger = Logger.get('test.http.auth');

      logger.info('auth_test_log');

      await completer.future.timeout(const Duration(seconds: 5));
      expect(receivedHeaders['x-static-client'], equals('mobile-app'));
      expect(
        receivedHeaders['authorization'],
        equals('Bearer dynamic-oauth-token-789'),
      );

      await sink.dispose();
      await authServer.close(force: true);
    });

    test('HttpSink fails over to secondary server when primary is down',
        () async {
      // Primary server returns 503
      final primaryServer =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      primaryServer.listen((final request) async {
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..write('Maintenance');
        await request.response.close();
      });

      // Backup server returns 200 and captures logs
      final backupServer =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final receivedBackupBatches = <List<dynamic>>[];
      final completer = Completer<void>();

      backupServer.listen((final request) async {
        final body = await utf8.decoder.bind(request).join();
        receivedBackupBatches.add(jsonDecode(body) as List<dynamic>);
        request.response
          ..statusCode = HttpStatus.ok
          ..write('OK');
        await request.response.close();
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      final sink = HttpSink(
        url: 'http://127.0.0.1:${primaryServer.port}/primary',
        failoverUrls: ['http://127.0.0.1:${backupServer.port}/backup'],
        batchSize: 1,
        maxRetries: 1,
      );

      final handler = Handler(
        formatter: const PlainFormatter(metadata: {}),
        sink: sink,
      );

      Logger.configure('test.http.failover', handlers: [handler]);
      final logger = Logger.get('test.http.failover');

      logger.info('FAILOVER_SURVIVED_LOG');

      await completer.future.timeout(const Duration(seconds: 5));
      expect(receivedBackupBatches.length, equals(1));
      expect(receivedBackupBatches[0][0], contains('FAILOVER_SURVIVED_LOG'));
      expect(sink.currentUrl,
          equals('http://127.0.0.1:${backupServer.port}/backup'));
      expect(sink.circuitState, equals(CircuitState.closed));

      await sink.dispose();
      await primaryServer.close(force: true);
      await backupServer.close(force: true);
    });

    test('HttpSink transmits GZip compressed batches to real HttpServer',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final completer = Completer<void>();
      final receivedBatches = <List<dynamic>>[];
      String? receivedEncoding;

      server.listen((final request) async {
        receivedEncoding = request.headers.value('content-encoding');
        if (receivedEncoding == 'gzip') {
          final decompressedStream = gzip.decoder.bind(request);
          final body = await utf8.decoder.bind(decompressedStream).join();
          receivedBatches.add(jsonDecode(body) as List<dynamic>);
        }
        request.response
          ..statusCode = HttpStatus.ok
          ..write('OK');
        await request.response.close();
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      final sink = HttpSink(
        url: 'http://127.0.0.1:${server.port}/gzip_logs',
        batchSize: 1,
        compress: true,
      );

      final handler = Handler(
        formatter: const PlainFormatter(metadata: {}),
        sink: sink,
      );

      Logger.configure('test.http.gzip', handlers: [handler]);
      final logger = Logger.get('test.http.gzip');

      logger.info('COMPRESSED_PAYLOAD_EVENT_4892');

      await completer.future.timeout(const Duration(seconds: 5));
      expect(receivedEncoding, equals('gzip'));
      expect(receivedBatches.length, equals(1));
      expect(receivedBatches[0][0], contains('COMPRESSED_PAYLOAD_EVENT_4892'));

      await sink.dispose();
      await server.close(force: true);
    });
  });
}
