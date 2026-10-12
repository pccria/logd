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
  });
}
