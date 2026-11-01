import 'dart:async';
import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';
import 'package:test/test.dart';

void main() {
  group('Dashboard DNS Rebinding Defense & Auth Token Hardening', () {
    test('HttpServerSink rejects DNS rebinding requests where Host and Origin are foreign',
        () async {
      final sink = HttpServerSink(
        address: '127.0.0.1',
        port: 0,
      );
      await sink.ready;
      final port = sink.boundPort;
      addTearDown(sink.dispose);

      // Simulate a DNS rebinding attack:
      // Attacker controls evil.test which resolves to 127.0.0.1.
      // Browser sends Host: evil.test and Origin: http://evil.test
      final client = http.Client();
      addTearDown(client.close);

      final req = http.Request('GET', Uri.parse('http://127.0.0.1:$port/'))
        ..headers['Host'] = 'evil.test'
        ..headers['Origin'] = 'http://evil.test';

      final res = await client.send(req);
      expect(res.statusCode, equals(403));
    });

    test('HttpServerSink enforces authToken on GET / and WebSocket /ws when configured',
        () async {
      const secret = 'super-secret-token-xyz';
      final sink = HttpServerSink(
        address: '127.0.0.1',
        port: 0,
        authToken: secret,
      );
      await sink.ready;
      final port = sink.boundPort;
      addTearDown(sink.dispose);

      // 1. Unauthenticated GET / must be rejected with 401
      final unauthRes = await http.get(Uri.parse('http://127.0.0.1:$port/'));
      expect(unauthRes.statusCode, equals(401));

      // 2. Authenticated GET / with query token must succeed
      final authRes = await http.get(
        Uri.parse('http://127.0.0.1:$port/?token=$secret'),
      );
      expect(authRes.statusCode, equals(200));

      // 3. Authenticated GET / with Authorization header must succeed
      final headerRes = await http.get(
        Uri.parse('http://127.0.0.1:$port/'),
        headers: {'Authorization': 'Bearer $secret'},
      );
      expect(headerRes.statusCode, equals(200));

      // 4. Unauthenticated WebSocket /ws must fail
      await expectLater(
        io.WebSocket.connect('ws://127.0.0.1:$port/ws'),
        throwsA(isA<io.WebSocketException>()),
      );

      // 5. Authenticated WebSocket /ws with token parameter must succeed
      final ws = await io.WebSocket.connect('ws://127.0.0.1:$port/ws?token=$secret');
      expect(ws.readyState, equals(io.WebSocket.open));
      await ws.close();
    });
  });

  group('SocketSink Native Headers & Subprotocols', () {
    test('SocketSink sends HTTP headers during handshake to server', () async {
      final receivedHeaders = <String, String>{};
      final completer = Completer<void>();

      final server = await io.HttpServer.bind('127.0.0.1', 0);
      addTearDown(() => server.close(force: true));

      server.listen((final req) async {
        if (req.uri.path == '/ws') {
          req.headers.forEach((final name, final values) {
            receivedHeaders[name] = values.join(',');
          });
          final ws = await io.WebSocketTransformer.upgrade(req);
          completer.complete();
          ws.listen((final _) {});
        }
      });

      final sink = SocketSink(
        url: 'ws://127.0.0.1:${server.port}/ws',
        headers: {
          'authorization': 'Bearer jwt-token-12345',
          'x-client-id': 'agent-007',
        },
      );
      addTearDown(sink.dispose);

      Logger.configure(
        'test.socket',
        handlers: [
          Handler(
            formatter: const PlainFormatter(),
            sink: sink,
          ),
        ],
      );
      Logger.get('test.socket').info('trigger socket connection');

      await completer.future.timeout(const Duration(seconds: 3));
      expect(receivedHeaders['authorization'], equals('Bearer jwt-token-12345'));
      expect(receivedHeaders['x-client-id'], equals('agent-007'));
    });
  });
}
