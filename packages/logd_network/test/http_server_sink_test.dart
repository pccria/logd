import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';
import 'package:test/test.dart';

void main() {
  group('HttpServerSink Tests', () {
    setUp(() {
      Logger.reset();
    });

    test(
      'should serve HTML dashboard and upgrade WebSockets to stream logs',
      () async {
        // Bind to localhost on a random ephemeral port
        final sink = HttpServerSink(
          address: 'localhost',
          port: 0,
          encoder: const PlainTextEncoder(),
        );

        await sink.ready;

        final port = sink.boundPort;
        expect(port, isPositive);

        // 1. Verify HTTP GET returns the dashboard HTML page
        final httpUrl = Uri.parse('http://localhost:$port/');
        final httpResponse = await http.get(httpUrl);
        expect(httpResponse.statusCode, equals(200));
        expect(httpResponse.headers['content-type'], contains('text/html'));
        expect(
          httpResponse.body,
          contains('<title>Logd Viewer Dashboard</title>'),
        );

        // 2. Connect WebSocket
        final wsUrl = 'ws://localhost:$port/ws';
        final socket = await io.WebSocket.connect(wsUrl);

        final completer = Completer<String>();
        socket.listen((final data) {
          if (!completer.isCompleted) {
            completer.complete(data as String);
          }
        });

        // Allow the event loop to run so the server registers the connection
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // 3. Emit a log to trigger broadcast
        final logger = Logger.get('dash_logger');
        Logger.configure(
          'dash_logger',
          handlers: [Handler(formatter: const PlainFormatter(), sink: sink)],
        );

        logger.info('Test dashboard log message', context: {'meta': 'data'});

        // 4. Assert broadcasted payload matches structure
        final payloadString = await completer.future.timeout(
          const Duration(seconds: 5),
        );
        final payload =
            convert.jsonDecode(payloadString) as Map<String, dynamic>;

        expect(payload['formatted'], contains('Test dashboard log message'));

        final entryMap = payload['entry'] as Map<String, dynamic>;
        expect(entryMap['message'], equals('Test dashboard log message'));
        expect(entryMap['level'], equals('info'));
        expect(entryMap['loggerName'], equals('dash_logger'));
        expect(entryMap['context'], equals({'meta': 'data'}));

        await socket.close();
        await sink.dispose();
      },
    );

    test(
        'should buffer log history and replay to late-connecting WebSocket'
        ' clients', () async {
      final sink = HttpServerSink(
        address: 'localhost',
        port: 0,
        bufferCapacity: 10,
        encoder: const PlainTextEncoder(),
      );

      await sink.ready;
      final port = sink.boundPort;

      // 1. Emit logs BEFORE any WebSocket client connects
      final logger = Logger.get('buffered_logger');
      Logger.configure(
        'buffered_logger',
        handlers: [Handler(formatter: const PlainFormatter(), sink: sink)],
      );

      logger
        ..info('Early startup event 1')
        ..warning('Early startup event 2');

      // 2. Connect WebSocket AFTER log emission
      final wsUrl = 'ws://localhost:$port/ws';
      final socket = await io.WebSocket.connect(wsUrl);

      final receivedLogs = <String>[];
      final completer = Completer<void>();

      socket.listen((final data) {
        receivedLogs.add(data as String);
        if (receivedLogs.length == 2 && !completer.isCompleted) {
          completer.complete();
        }
      });

      await completer.future.timeout(const Duration(seconds: 5));
      expect(receivedLogs.length, equals(2));

      final firstPayload = convert.jsonEncode(
        convert.jsonDecode(receivedLogs[0]),
      );
      expect(firstPayload, contains('Early startup event 1'));

      final secondPayload = convert.jsonEncode(
        convert.jsonDecode(receivedLogs[1]),
      );
      expect(secondPayload, contains('Early startup event 2'));

      await socket.close();
      await sink.dispose();
    });

    test(
      'should evict oldest logs when bufferCapacity is exceeded',
      () async {
        final sink = HttpServerSink(
          address: 'localhost',
          port: 0,
          bufferCapacity: 2,
          encoder: const PlainTextEncoder(),
        );

        await sink.ready;
        final port = sink.boundPort;

        final logger = Logger.get('capacity_logger');
        Logger.configure(
          'capacity_logger',
          handlers: [Handler(formatter: const PlainFormatter(), sink: sink)],
        );

        logger
          ..info('Log 1 - should be evicted')
          ..info('Log 2 - should be retained')
          ..info('Log 3 - should be retained');

        final wsUrl = 'ws://localhost:$port/ws';
        final socket = await io.WebSocket.connect(wsUrl);

        final receivedLogs = <String>[];
        final completer = Completer<void>();

        socket.listen((final data) {
          receivedLogs.add(data as String);
          if (receivedLogs.length == 2 && !completer.isCompleted) {
            completer.complete();
          }
        });

        await completer.future.timeout(const Duration(seconds: 5));
        expect(receivedLogs.length, equals(2));

        expect(receivedLogs[0], contains('Log 2 - should be retained'));
        expect(receivedLogs[1], contains('Log 3 - should be retained'));

        await socket.close();
        await sink.dispose();
      },
    );

    test(
      'should broadcast logs to multiple concurrent WebSocket clients',
      () async {
        final sink = HttpServerSink(
          address: 'localhost',
          port: 0,
          encoder: const PlainTextEncoder(),
        );

        await sink.ready;
        final port = sink.boundPort;

        final wsUrl = 'ws://localhost:$port/ws';
        final socket1 = await io.WebSocket.connect(wsUrl);
        final socket2 = await io.WebSocket.connect(wsUrl);

        final completer1 = Completer<String>();
        final completer2 = Completer<String>();

        socket1.listen((final data) {
          if (!completer1.isCompleted) {
            completer1.complete(data as String);
          }
        });
        socket2.listen((final data) {
          if (!completer2.isCompleted) {
            completer2.complete(data as String);
          }
        });

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final logger = Logger.get('multi_client_logger');
        Logger.configure(
          'multi_client_logger',
          handlers: [Handler(formatter: const PlainFormatter(), sink: sink)],
        );

        logger.info('Broadcast event');

        final res1 = await completer1.future.timeout(
          const Duration(seconds: 5),
        );
        final res2 = await completer2.future.timeout(
          const Duration(seconds: 5),
        );

        expect(res1, contains('Broadcast event'));
        expect(res2, contains('Broadcast event'));

        await socket1.close();
        await socket2.close();
        await sink.dispose();
      },
    );

    test('should return 404 for unknown HTTP routes', () async {
      final sink = HttpServerSink(
        address: 'localhost',
        port: 0,
      );

      await sink.ready;
      final port = sink.boundPort;

      final res =
          await http.get(Uri.parse('http://localhost:$port/unknown_route'));
      expect(res.statusCode, equals(404));

      await sink.dispose();
    });
  });
}
