import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'test_helpers.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockWebSocketChannel extends Mock implements WebSocketChannel {}

class MockWebSocketSink extends Mock implements WebSocketSink {}

class _TestDocumentEncoder implements LogEncoder {
  const _TestDocumentEncoder();

  @override
  WrappingStrategy get wrappingStrategy => WrappingStrategy.document;

  @override
  void preamble(
    final HandlerContext context,
    final LogLevel level,
    final LogPipelineFactory factory, {
    final LogDocument? document,
  }) {
    context.writeString('<!-- PREAMBLE -->');
  }

  @override
  void postamble(
    final HandlerContext context,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) {
    context.writeString('<!-- POSTAMBLE -->');
  }

  @override
  void encode(
    final LogEntry entry,
    final LogDocument document,
    final LogLevel level,
    final HandlerContext context,
    final LogPipelineFactory factory, {
    final int? width,
  }) {
    context.writeString(entry.message);
  }
}

void main() {
  const httpUrl = 'https://example.com/logs';
  const wsUrl = 'ws://example.com/logs';

  final testEntry = LogEntry(
    loggerName: 'test',
    origin: 'main',
    level: LogLevel.info,
    message: 'msg',
    timestamp: '2025-01-01',
  );

  group('HttpSink', () {
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      registerFallbackValue(Uri.parse(httpUrl));
    });

    test('buffers logs until batchSize reached', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('OK', 200));

      final sink = HttpSink(url: httpUrl, batchSize: 3, client: mockClient);

      await sink.output(
        createTestDocument(['log1']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await sink.output(
        createTestDocument(['log2']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      verifyNever(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );

      await sink.output(
        createTestDocument(['log3']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(Duration.zero);

      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: jsonEncode(['log1', 'log2', 'log3']),
        ),
      ).called(1);
    });

    test('flushes logs on timer interval', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('OK', 200));

      final sink = HttpSink(
        url: httpUrl,
        flushInterval: const Duration(milliseconds: 50),
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['queued']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(const Duration(milliseconds: 100));

      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: contains('queued'),
        ),
      ).called(1);

      await sink.dispose();
    });

    test('retries on failure with exponential backoff', () async {
      var attempts = 0;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async {
        attempts++;
        if (attempts < 2) {
          return http.Response('Error', 500);
        }
        return http.Response('OK', 200);
      });

      final sink = HttpSink(
        url: httpUrl,
        batchSize: 1,
        maxRetries: 3,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['retry-me']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(const Duration(milliseconds: 600));

      expect(attempts, equals(2));
      await sink.dispose();
    });

    test('forwards custom headers in HTTP request', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('OK', 200));

      final sink = HttpSink(
        url: httpUrl,
        batchSize: 1,
        headers: const {
          'Authorization': 'Bearer token-xyz',
          'X-Custom': '123',
        },
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['custom-headers']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(Duration.zero);

      verify(
        () => mockClient.post(
          any(),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer token-xyz',
            'X-Custom': '123',
          },
          body: any(named: 'body'),
        ),
      ).called(1);
    });

    test('evaluates async headersProvider and overrides static headers',
        () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('OK', 200));

      final sink = HttpSink(
        url: httpUrl,
        batchSize: 1,
        headers: const {
          'Authorization': 'Bearer old-token',
          'X-Static': 'static-val',
        },
        headersProvider: () async => {
          'Authorization': 'Bearer refreshed-token',
          'X-Dynamic': 'dynamic-val',
        },
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['dynamic-headers']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(Duration.zero);

      verify(
        () => mockClient.post(
          any(),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer refreshed-token',
            'X-Static': 'static-val',
            'X-Dynamic': 'dynamic-val',
          },
          body: any(named: 'body'),
        ),
      ).called(1);
    });

    test('supports synchronous headersProvider callback', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('OK', 200));

      final sink = HttpSink(
        url: httpUrl,
        batchSize: 1,
        headersProvider: () => {'X-Sync-Auth': 'signature-456'},
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['sync-headers']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(Duration.zero);

      verify(
        () => mockClient.post(
          any(),
          headers: {
            'Content-Type': 'application/json',
            'X-Sync-Auth': 'signature-456',
          },
          body: any(named: 'body'),
        ),
      ).called(1);
    });

    test('re-evaluates headersProvider on retry when token provider throws',
        () async {
      var providerCalls = 0;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('OK', 200));

      final sink = HttpSink(
        url: httpUrl,
        batchSize: 1,
        maxRetries: 3,
        headersProvider: () {
          providerCalls++;
          if (providerCalls == 1) {
            throw StateError('Auth server timeout');
          }
          return {'Authorization': 'Bearer recovered-jwt'};
        },
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['retry-token']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(const Duration(milliseconds: 500));

      expect(providerCalls, equals(2));
      verify(
        () => mockClient.post(
          any(),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer recovered-jwt',
          },
          body: any(named: 'body'),
        ),
      ).called(1);
    });

    test('invokes onDropped callback when max retries exceeded', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('Internal Error', 500));

      List<Uint8List>? droppedBatch;
      Object? droppedError;

      final sink = HttpSink(
        url: httpUrl,
        batchSize: 1,
        maxRetries: 2,
        client: mockClient,
        onDropped: (final batch, final error) {
          droppedBatch = batch;
          droppedError = error;
        },
      );

      await sink.output(
        createTestDocument(['drop-me']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(const Duration(milliseconds: 500));

      expect(droppedBatch, isNotNull);
      expect(droppedBatch, hasLength(1));
      expect(utf8.decode(droppedBatch!.first), equals('drop-me'));
      expect(droppedError, isA<http.ClientException>());
    });

    test('handles exception thrown inside onDropped gracefully', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('Internal Error', 500));

      final sink = HttpSink(
        url: httpUrl,
        batchSize: 1,
        maxRetries: 1,
        client: mockClient,
        onDropped: (final _, final __) {
          throw StateError('Callback failed');
        },
      );

      await expectLater(
        sink.output(
          createTestDocument(['safe-drop']),
          testEntry,
          LogLevel.info,
          const StandardPipelineFactory(),
        ),
        completes,
      );
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('retries on ClientException network failures', () async {
      var attempts = 0;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async {
        attempts++;
        if (attempts == 1) {
          throw http.ClientException('Connection reset');
        }
        return http.Response('OK', 200);
      });

      final sink = HttpSink(
        url: httpUrl,
        batchSize: 1,
        maxRetries: 3,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['network-fail']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(const Duration(milliseconds: 500));

      expect(attempts, equals(2));
      await sink.dispose();
    });
  });

  group('SocketSink', () {
    late MockWebSocketChannel mockChannel;
    late MockWebSocketSink mockSink;

    setUp(() {
      mockChannel = MockWebSocketChannel();
      mockSink = MockWebSocketSink();
      when(() => mockChannel.sink).thenReturn(mockSink);
      when(() => mockChannel.ready).thenAnswer((final _) async => {});
      when(() => mockSink.close()).thenAnswer((final _) async => {});
    });

    test('sends logs immediately when connected', () async {
      final sink = SocketSink(url: wsUrl, channel: mockChannel);

      await sink.output(
        createTestDocument(['instant']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(Duration.zero);

      verify(() => mockSink.add('instant')).called(1);
    });

    test('buffers logs during downtime and drains on reconnect', () async {
      final readyCompleter = Completer<void>();
      when(
        () => mockChannel.ready,
      ).thenAnswer((final _) => readyCompleter.future);

      final sink = SocketSink(url: wsUrl, channel: mockChannel);

      final f = sink.output(
        createTestDocument(['buffered']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );

      await Future.delayed(Duration.zero);
      verifyNever(() => mockSink.add(any()));

      readyCompleter.complete();
      await f;

      verify(() => mockSink.add('buffered')).called(1);
    });

    test('cancels pending reconnect timer on dispose', () async {
      when(() => mockChannel.ready).thenThrow(Exception('Connection failed'));

      final sink = SocketSink(
        url: wsUrl,
        channel: mockChannel,
        reconnectInterval: const Duration(milliseconds: 50),
      );

      await sink.output(
        createTestDocument(['fail']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );

      await sink.dispose();

      await Future.delayed(const Duration(milliseconds: 100));

      expect(sink.isDisposed, isTrue);
    });

    test('re-enqueues line and initiates reconnect when send fails', () async {
      var sendCalls = 0;
      when(() => mockSink.add(any())).thenAnswer((final _) {
        sendCalls++;
        if (sendCalls == 1) {
          throw StateError('Socket closed abruptly');
        }
      });

      final sink = SocketSink(
        url: wsUrl,
        channel: mockChannel,
        reconnectInterval: const Duration(milliseconds: 50),
      );

      await sink.output(
        createTestDocument(['faulty-stream']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(const Duration(milliseconds: 150));

      expect(sendCalls, greaterThanOrEqualTo(1));
      await sink.dispose();
    });
  });

  group('NetworkSink Edge Cases', () {
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      registerFallbackValue(Uri.parse('https://example.com'));
    });

    test('respects DropPolicy.discardNewest when buffer is full', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('OK', 200));

      final sink = HttpSink(
        url: 'https://example.com/logs',
        maxBufferSize: 2,
        batchSize: 10,
        dropPolicy: DropPolicy.discardNewest,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['first']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await sink.output(
        createTestDocument(['second']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await sink.output(
        createTestDocument(['third']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );

      await sink.dispose();

      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: jsonEncode(['first', 'second']),
        ),
      ).called(1);
    });

    test('respects DropPolicy.discardOldest when buffer is full', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('OK', 200));

      final sink = HttpSink(
        url: 'https://example.com/logs',
        maxBufferSize: 2,
        batchSize: 10,
        dropPolicy: DropPolicy.discardOldest,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['first']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await sink.output(
        createTestDocument(['second']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await sink.output(
        createTestDocument(['third']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );

      await sink.dispose();

      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: jsonEncode(['second', 'third']),
        ),
      ).called(1);
    });

    test(
      'writes preamble and postamble for WrappingStrategy.document',
      () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((final _) async => http.Response('OK', 200));

        final sink = HttpSink(
          url: 'https://example.com/logs',
          encoder: const _TestDocumentEncoder(),
          batchSize: 10,
          client: mockClient,
        );

        await sink.output(
          createTestDocument(['body']),
          testEntry,
          LogLevel.info,
          const StandardPipelineFactory(),
        );

        await sink.dispose();

        verify(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: jsonEncode([
              '<!-- PREAMBLE -->',
              'msg',
              '<!-- POSTAMBLE -->',
            ]),
          ),
        ).called(1);
      },
    );

    test('does not output when enabled is false', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('OK', 200));

      final sink = HttpSink(
        url: 'https://example.com/logs',
        batchSize: 1,
        enabled: false,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['ignored']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(Duration.zero);

      verifyNever(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );
    });

    test('dispose flushes remaining buffer', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('OK', 200));

      final sink = HttpSink(
        url: 'https://example.com/logs',
        batchSize: 100,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['pending']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      verifyNever(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );

      await sink.dispose();

      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: jsonEncode(['pending']),
        ),
      ).called(1);
    });

    test('DropPolicy.block throws AssertionError on construction', () {
      expect(
        () => HttpSink(
          url: 'https://example.com/logs',
          dropPolicy: DropPolicy.block,
          client: mockClient,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
