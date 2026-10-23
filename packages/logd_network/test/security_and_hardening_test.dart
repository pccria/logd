import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';
import 'package:logd_network/src/target_handlers/http_dashboard_isolate_handler.dart';
import 'package:test/test.dart';

void main() {
  group('Security & CSWSH Hardening Tests', () {
    setUp(() {
      Logger.reset();
    });

    test('HttpServerSink serves security headers on GET /', () async {
      final sink = HttpServerSink(
        address: '127.0.0.1',
        port: 0,
      );
      await sink.ready;
      final port = sink.boundPort;

      final response = await http.get(Uri.parse('http://127.0.0.1:$port/'));
      expect(response.statusCode, equals(200));
      expect(response.headers['x-content-type-options'], equals('nosniff'));
      expect(response.headers['x-frame-options'], equals('DENY'));
      expect(response.headers['content-security-policy'], isNotNull);
      expect(
        response.headers['content-security-policy'],
        contains("default-src 'self'"),
      );

      await sink.dispose();
    });

    test('HttpServerSink rejects untrusted Cross-Origin WebSocket connections',
        () async {
      final sink = HttpServerSink(
        address: '127.0.0.1',
        port: 0,
        allowedOrigins: {'https://trusted-dashboard.internal'},
      );
      await sink.ready;
      final port = sink.boundPort;

      // 1. Malicious external origin should be rejected with 403 Forbidden
      await expectLater(
        io.WebSocket.connect(
          'ws://127.0.0.1:$port/ws',
          headers: {'Origin': 'https://malicious-site.com'},
        ),
        throwsA(
          isA<io.WebSocketException>().having(
            (final e) => e.toString(),
            'toString()',
            contains('403'),
          ),
        ),
      );

      // 2. Explicitly allowed origin should proceed and connect
      final trustedWs = await io.WebSocket.connect(
        'ws://127.0.0.1:$port/ws',
        headers: {'Origin': 'https://trusted-dashboard.internal'},
      );
      expect(trustedWs.readyState, equals(io.WebSocket.open));
      await trustedWs.close();

      // 3. Loopback / localhost origin should proceed and connect
      final loopbackWs = await io.WebSocket.connect(
        'ws://127.0.0.1:$port/ws',
        headers: {'Origin': 'http://localhost:$port'},
      );
      expect(loopbackWs.readyState, equals(io.WebSocket.open));
      await loopbackWs.close();

      // 4. Direct non-browser origin should proceed and connect
      final directWs = await io.WebSocket.connect('ws://127.0.0.1:$port/ws');
      expect(directWs.readyState, equals(io.WebSocket.open));
      await directWs.close();

      await sink.dispose();
    });

    test('HttpServerSink enforces maxConnections cap to prevent DoS', () async {
      const maxConn = 3;
      final sink = HttpServerSink(
        address: '127.0.0.1',
        port: 0,
        maxConnections: maxConn,
      );
      await sink.ready;
      final port = sink.boundPort;

      final openSockets = <io.WebSocket>[];
      for (var i = 0; i < maxConn; i++) {
        final ws = await io.WebSocket.connect('ws://127.0.0.1:$port/ws');
        openSockets.add(ws);
      }

      expect(openSockets.length, equals(maxConn));

      // Attempt (maxConn + 1)th connection: should be rejected with 503 Service Unavailable
      final client = http.Client();
      final overflowReq = http.Request(
        'GET',
        Uri.parse('http://127.0.0.1:$port/ws'),
      )
        ..headers['Connection'] = 'Upgrade'
        ..headers['Upgrade'] = 'websocket'
        ..headers['Sec-WebSocket-Version'] = '13'
        ..headers['Sec-WebSocket-Key'] = 'dGhlIHNhbXBsZSBub25jZQ==';

      final overflowRes = await client.send(overflowReq);
      expect(overflowRes.statusCode, equals(503));
      expect(overflowRes.headers['retry-after'], equals('5'));

      // Close one socket and verify a new connection can now succeed
      await openSockets.removeLast().close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final recoveredReq = http.Request(
        'GET',
        Uri.parse('http://127.0.0.1:$port/ws'),
      )
        ..headers['Connection'] = 'Upgrade'
        ..headers['Upgrade'] = 'websocket'
        ..headers['Sec-WebSocket-Version'] = '13'
        ..headers['Sec-WebSocket-Key'] = 'dGhlIHNhbXBsZSBub25jZQ==';

      final recoveredRes = await client.send(recoveredReq);
      expect(recoveredRes.statusCode, equals(101));

      for (final ws in openSockets) {
        await ws.close();
      }
      client.close();
      await sink.dispose();
    });

    test(
        'HttpServerSink marks isHtml false for plain text logs starting with <div',
        () async {
      final sink = HttpServerSink(
        address: '127.0.0.1',
        port: 0,
        encoder: const PlainTextEncoder(),
      );
      await sink.ready;
      final port = sink.boundPort;

      final socket = await io.WebSocket.connect('ws://127.0.0.1:$port/ws');
      final receivedPayload = Completer<Map<String, dynamic>>();

      socket.listen((final msg) {
        if (!receivedPayload.isCompleted) {
          final decoded =
              convert.jsonDecode(msg as String) as Map<String, dynamic>;
          receivedPayload.complete(decoded);
        }
      });

      Logger.configure(
        'sec',
        handlers: [
          Handler(
            formatter: const PlainFormatter(),
            sink: sink,
          ),
        ],
      );
      final logger = Logger.get('sec');

      // Attempt to spoof HTML by starting message with <div
      logger.info('<div onload="alert(1)">payload</div>');

      final payload = await receivedPayload.future.timeout(
        const Duration(seconds: 3),
      );

      // Verify server reports isHtml false because encoder is PlainTextEncoder
      expect(payload['isHtml'], equals(false));
      expect(payload['formatted'],
          contains('<div onload="alert(1)">payload</div>'));

      await socket.close();
      await sink.dispose();
    });

    test(
        'HttpDashboardIsolateHandler supports port 0, reports boundPort, and handles logs',
        () async {
      registerLogdNetworkSerializers();

      final handler = HttpDashboardHandler.async(
        address: '127.0.0.1',
        port: 0,
        maxConnections: 10,
      );

      // Cast to access boundPort
      final isolateHandler = handler as HttpDashboardIsolateHandler;
      await isolateHandler.ready;

      final port = isolateHandler.boundPort;
      expect(port, isPositive);
      expect(port, isNot(equals(0)));

      // Verify dashboard is serving on the bound port
      final res = await http.get(Uri.parse('http://127.0.0.1:$port/'));
      expect(res.statusCode, equals(200));
      expect(res.body, contains('Logd Viewer Dashboard'));

      // Connect WebSocket and verify background isolate streams logs
      final socket = await io.WebSocket.connect('ws://127.0.0.1:$port/ws');
      final logReceived = Completer<String>();

      socket.listen((final msg) {
        if (!logReceived.isCompleted) {
          logReceived.complete(msg as String);
        }
      });

      Logger.configure('bg', handlers: [handler]);
      Logger.get('bg').info('Background isolate log entry verification');

      final rawLog = await logReceived.future.timeout(
        const Duration(seconds: 4),
      );
      expect(rawLog, contains('Background isolate log entry verification'));

      await socket.close();
      await handler.dispose();
    });
  });
}
