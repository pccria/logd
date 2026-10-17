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
        maxBufferSize: 500,
        dropPolicy: DropPolicy.discardNewest,
      );

      final json = LoggerSerializationRegistry.serializeSink(original);
      expect(json['type'], equals('HttpSink'));

      final restored =
          LoggerSerializationRegistry.deserializeSink(json) as HttpSink;
      expect(restored.url, equals('https://logs.example.com/api/v1'));
      expect(restored.failoverUrls,
          equals(['https://logs-backup.example.com/api/v1']));
      expect(restored.failureThreshold, equals(4));
      expect(restored.recoveryTimeout, equals(const Duration(seconds: 30)));
      expect(restored.headers, equals({'Authorization': 'Bearer token-123'}));
      expect(restored.batchSize, equals(25));
      expect(restored.flushInterval, equals(const Duration(seconds: 45)));
      expect(restored.maxRetries, equals(7));
      expect(restored.maxBufferSize, equals(500));
      expect(restored.dropPolicy, equals(DropPolicy.discardNewest));
      expect(restored.headersProvider, isNull);
    });

    test('SocketSink round-trip serialization and deserialization', () {
      final original = SocketSink(
        url: 'wss://stream.example.com/logs',
        headers: const {'X-Custom-Protocol': 'v1'},
        reconnectInterval: const Duration(seconds: 10),
        maxBufferSize: 800,
        dropPolicy: DropPolicy.discardOldest,
      );

      final json = LoggerSerializationRegistry.serializeSink(original);
      expect(json['type'], equals('SocketSink'));

      final restored =
          LoggerSerializationRegistry.deserializeSink(json) as SocketSink;
      expect(restored.url, equals('wss://stream.example.com/logs'));
      expect(restored.headers, equals({'X-Custom-Protocol': 'v1'}));
      expect(restored.reconnectInterval, equals(const Duration(seconds: 10)));
      expect(restored.maxBufferSize, equals(800));
      expect(restored.dropPolicy, equals(DropPolicy.discardOldest));
    });

    test('HttpServerSink round-trip serialization and deserialization', () {
      final original = HttpServerSink(
        address: '127.0.0.1',
        port: 0,
        bufferCapacity: 250,
        lineLength: 140,
      );

      final json = LoggerSerializationRegistry.serializeSink(original);
      expect(json['type'], equals('HttpServerSink'));

      final restored =
          LoggerSerializationRegistry.deserializeSink(json) as HttpServerSink;
      expect(restored.address, equals('127.0.0.1'));
      expect(restored.bufferCapacity, equals(250));
      expect(restored.preferredWidth, equals(140));

      original.dispose();
      restored.dispose();
    });
  });
}
