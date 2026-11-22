import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';
import 'package:test/test.dart';

void main() {
  group('Logd Network Serialization Tests', () {
    setUp(() {
      Logger.reset();
      registerLogdNetworkSerializers();
    });

    test('HttpSink round-trip serialization and deserialization', () {
      final original = HttpSink(
        url: 'https://logs.example.com/api/v1',
        failoverUrls: const ['https://logs-backup.example.com/api/v1'],
        failureThreshold: 4,
        recoveryTimeout: const Duration(seconds: 30),
        headers: const {'Authorization': 'Bearer token-123'},
        batchSize: 25,
        flushInterval: const Duration(seconds: 45),
        maxRetries: 7,
        deliveryFormat: HttpDeliveryFormat.ndjson,
        backoffPolicy: const BackoffPolicy(
          initialDelay: Duration(milliseconds: 500),
          maxDelay: Duration(seconds: 15),
          multiplier: 1.5,
          jitter: true,
        ),
        compress: true,
        maxBufferSize: 500,
        maxBufferBytes: 1048576,
        dropPolicy: DropPolicy.discardByPriority,
      );

      final json = LoggerSerializationRegistry.serializeSink(original);
      expect(json['type'], equals('HttpSink'));

      final restored =
          LoggerSerializationRegistry.deserializeSink(json) as HttpSink;
      expect(restored.url, equals('https://logs.example.com/api/v1'));
      expect(
        restored.failoverUrls,
        equals(['https://logs-backup.example.com/api/v1']),
      );
      expect(restored.failureThreshold, equals(4));
      expect(restored.recoveryTimeout, equals(const Duration(seconds: 30)));
      expect(restored.headers, equals({'Authorization': 'Bearer token-123'}));
      expect(restored.batchSize, equals(25));
      expect(restored.flushInterval, equals(const Duration(seconds: 45)));
      expect(restored.maxRetries, equals(7));
      expect(restored.deliveryFormat, equals(HttpDeliveryFormat.ndjson));
      expect(
        restored.backoffPolicy.initialDelay,
        equals(const Duration(milliseconds: 500)),
      );
      expect(
        restored.backoffPolicy.maxDelay,
        equals(const Duration(seconds: 15)),
      );
      expect(restored.backoffPolicy.multiplier, equals(1.5));
      expect(restored.backoffPolicy.jitter, isTrue);
      expect(restored.compress, isTrue);
      expect(restored.maxBufferSize, equals(500));
      expect(restored.maxBufferBytes, equals(1048576));
      expect(restored.dropPolicy, equals(DropPolicy.discardByPriority));
      expect(restored.headersProvider, isNull);
    });

    test('SocketSink round-trip serialization and deserialization', () {
      final original = SocketSink(
        url: 'wss://stream.example.com/logs',
        headers: const {'X-Custom-Protocol': 'v1'},
        protocols: const ['v1.logd', 'telemetry'],
        reconnectInterval: const Duration(seconds: 10),
        backoffPolicy: const BackoffPolicy(
          initialDelay: Duration(seconds: 3),
          maxDelay: Duration(seconds: 60),
          multiplier: 2.0,
          jitter: true,
        ),
        heartbeatInterval: const Duration(seconds: 20),
        heartbeatTimeout: const Duration(seconds: 5),
        pingMessage: 'heartbeat-ping',
        pongMessage: 'heartbeat-pong',
        maxBufferSize: 800,
        maxBufferBytes: 524288,
        dropPolicy: DropPolicy.discardOldest,
      );

      final json = LoggerSerializationRegistry.serializeSink(original);
      expect(json['type'], equals('SocketSink'));

      final restored =
          LoggerSerializationRegistry.deserializeSink(json) as SocketSink;
      expect(restored.url, equals('wss://stream.example.com/logs'));
      expect(restored.headers, equals({'X-Custom-Protocol': 'v1'}));
      expect(restored.protocols, equals(['v1.logd', 'telemetry']));
      expect(restored.reconnectInterval, equals(const Duration(seconds: 10)));
      expect(restored.backoffPolicy, isNotNull);
      expect(
        restored.backoffPolicy!.initialDelay,
        equals(const Duration(seconds: 3)),
      );
      expect(
        restored.backoffPolicy!.maxDelay,
        equals(const Duration(seconds: 60)),
      );
      expect(restored.heartbeatInterval, equals(const Duration(seconds: 20)));
      expect(restored.heartbeatTimeout, equals(const Duration(seconds: 5)));
      expect(restored.pingMessage, equals('heartbeat-ping'));
      expect(restored.pongMessage, equals('heartbeat-pong'));
      expect(restored.maxBufferSize, equals(800));
      expect(restored.maxBufferBytes, equals(524288));
      expect(restored.dropPolicy, equals(DropPolicy.discardOldest));
    });

    test('HttpServerSink round-trip serialization and deserialization', () {
      final original = HttpServerSink(
        address: '127.0.0.1',
        port: 0,
        title: 'Custom Observability Center',
        bufferCapacity: 250,
        lineLength: 140,
        allowedHosts: const {'dashboard.internal'},
        authToken: 'secret-token-123',
      );

      final json = LoggerSerializationRegistry.serializeSink(original);
      expect(json['type'], equals('HttpServerSink'));

      final restored =
          LoggerSerializationRegistry.deserializeSink(json) as HttpServerSink;
      expect(restored.address, equals('127.0.0.1'));
      expect(restored.title, equals('Custom Observability Center'));
      expect(restored.bufferCapacity, equals(250));
      expect(restored.preferredWidth, equals(140));
      expect(restored.allowedHosts, contains('dashboard.internal'));
      expect(restored.authToken, equals('secret-token-123'));

      original.dispose();
      restored.dispose();
    });
  });
}
