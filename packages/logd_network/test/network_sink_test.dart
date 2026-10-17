import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

    test(
      'invokes onDropped with provider error when headersProvider throws continuously',
      () async {
        List<Uint8List>? droppedBatch;
        Object? droppedError;

        final sink = HttpSink(
          url: httpUrl,
          batchSize: 1,
          maxRetries: 2,
          headersProvider: () =>
              throw const FormatException('Invalid auth state'),
          client: mockClient,
          onDropped: (final batch, final error) {
            droppedBatch = batch;
            droppedError = error;
          },
        );

        await sink.output(
          createTestDocument(['fail-token']),
          testEntry,
          LogLevel.info,
          const StandardPipelineFactory(),
        );
        await Future.delayed(const Duration(milliseconds: 500));

        expect(droppedBatch, isNotNull);
        expect(droppedBatch, hasLength(1));
        expect(utf8.decode(droppedBatch!.first), equals('fail-token'));
        expect(droppedError, isA<FormatException>());
      },
    );

    test('evaluates headersProvider during periodic timer flushes', () async {
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
        headersProvider: () async => {'X-Timer-Auth': 'scheduled-token'},
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['scheduled-log']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future.delayed(const Duration(milliseconds: 100));

      verify(
        () => mockClient.post(
          any(),
          headers: {
            'Content-Type': 'application/json',
            'X-Timer-Auth': 'scheduled-token',
          },
          body: any(named: 'body'),
        ),
      ).called(1);

      await sink.dispose();
    });

    test('re-evaluates headersProvider dynamically across distinct batches',
        () async {
      var callIndex = 0;
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
        headersProvider: () => {'X-Sequence': 'seq-${++callIndex}'},
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['batch-1']),
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
            'X-Sequence': 'seq-1',
          },
          body: any(named: 'body'),
        ),
      ).called(1);

      await sink.output(
        createTestDocument(['batch-2']),
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
            'X-Sequence': 'seq-2',
          },
          body: any(named: 'body'),
        ),
      ).called(1);

      expect(callIndex, equals(2));
      await sink.dispose();
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

  group('HttpDate and Retry-After Parsing', () {
    test('parses integer seconds correctly', () {
      expect(parseRetryAfter('120'), equals(const Duration(seconds: 120)));
      expect(parseRetryAfter('0'), equals(Duration.zero));
      expect(parseRetryAfter('  45  '), equals(const Duration(seconds: 45)));
    });

    test('parses IMF-fixdate / RFC 1123 HTTP-date', () {
      final baseTime = DateTime.utc(1994, 11, 6, 8, 49, 0);
      final duration = parseRetryAfter(
        'Sun, 06 Nov 1994 08:49:37 GMT',
        clock: () => baseTime,
      );
      expect(duration, equals(const Duration(seconds: 37)));
    });

    test('parses RFC 850 HTTP-date', () {
      final baseTime = DateTime.utc(1994, 11, 6, 8, 49, 0);
      final duration = parseRetryAfter(
        'Sunday, 06-Nov-94 08:49:37 GMT',
        clock: () => baseTime,
      );
      expect(duration, equals(const Duration(seconds: 37)));
    });

    test('parses asctime HTTP-date', () {
      final baseTime = DateTime.utc(1994, 11, 6, 8, 49, 0);
      final duration = parseRetryAfter(
        'Sun Nov  6 08:49:37 1994',
        clock: () => baseTime,
      );
      expect(duration, equals(const Duration(seconds: 37)));
    });

    test('returns Duration.zero for elapsed date in the past', () {
      final baseTime = DateTime.utc(2026, 1, 1, 0, 0, 0);
      final duration = parseRetryAfter(
        'Sun, 06 Nov 1994 08:49:37 GMT',
        clock: () => baseTime,
      );
      expect(duration, equals(Duration.zero));
    });

    test('returns null for invalid, empty, or null values', () {
      expect(parseRetryAfter(null), isNull);
      expect(parseRetryAfter(''), isNull);
      expect(parseRetryAfter('   '), isNull);
      expect(parseRetryAfter('invalid-header-content'), isNull);
    });
  });

  group('HttpSink Circuit Breaker & Failover', () {
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
    });

    test('initializes with closed circuit and zero consecutive failures', () {
      final sink = HttpSink(
        url: 'https://primary.example.com/logs',
        failoverUrls: const ['https://backup.example.com/logs'],
        failureThreshold: 3,
        client: mockClient,
      );

      expect(sink.circuitState, equals(CircuitState.closed));
      expect(sink.consecutiveFailures, equals(0));
      expect(sink.currentUrl, equals('https://primary.example.com/logs'));
      expect(sink.failoverUrls, equals(['https://backup.example.com/logs']));
      expect(sink.failureThreshold, equals(3));
    });

    test(
        'trips circuit to open after failureThreshold failures without failovers',
        () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('Internal Error', 500));

      final sink = HttpSink(
        url: 'https://example.com/logs',
        batchSize: 1,
        maxRetries: 1,
        failureThreshold: 2,
        recoveryTimeout: const Duration(milliseconds: 50),
        client: mockClient,
      );

      // Batch 1 fails
      await sink.output(
        createTestDocument(['msg1']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(sink.consecutiveFailures, equals(1));
      expect(sink.circuitState, equals(CircuitState.closed));

      // Batch 2 fails -> reaches failureThreshold (2) -> trips to open!
      await sink.output(
        createTestDocument(['msg2']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(sink.consecutiveFailures, equals(2));
      expect(sink.circuitState, equals(CircuitState.open));

      // Batch 3 sent while circuit is open -> fails fast, no network calls made!
      await sink.output(
        createTestDocument(['msg3']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify msg1 and msg2 were called, but msg3 was NEVER called because circuit is open!
      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: jsonEncode(['msg1']),
        ),
      ).called(1);
      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: jsonEncode(['msg2']),
        ),
      ).called(1);
      verifyNever(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: jsonEncode(['msg3']),
        ),
      );
      verifyNoMoreInteractions(mockClient);

      await sink.dispose();
    });

    test('recovers from open to halfOpen and closes on successful probe',
        () async {
      int requestCount = 0;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async {
        requestCount++;
        if (requestCount <= 2) {
          return http.Response('Service Unavailable', 503);
        }
        return http.Response('OK', 200);
      });

      final sink = HttpSink(
        url: 'https://example.com/logs',
        batchSize: 1,
        maxRetries: 1,
        failureThreshold: 2,
        recoveryTimeout: const Duration(milliseconds: 30),
        client: mockClient,
      );

      // Send 2 batches to trip circuit to open
      await sink.output(
        createTestDocument(['batch1']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await sink.output(
        createTestDocument(['batch2']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(sink.circuitState, equals(CircuitState.open));

      // Wait for recovery timeout to elapse
      await Future<void>.delayed(const Duration(milliseconds: 40));

      // Send probe log
      await sink.output(
        createTestDocument(['probe']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Probe succeeded -> circuit closes and resets consecutiveFailures!
      expect(sink.circuitState, equals(CircuitState.closed));
      expect(sink.consecutiveFailures, equals(0));

      await sink.dispose();
    });

    test('trips back to open if probe fails in halfOpen', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('Error', 500));

      final sink = HttpSink(
        url: 'https://example.com/logs',
        batchSize: 1,
        maxRetries: 1,
        failureThreshold: 1,
        recoveryTimeout: const Duration(milliseconds: 30),
        client: mockClient,
      );

      // 1 failure trips circuit to open
      await sink.output(
        createTestDocument(['batch1']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(sink.circuitState, equals(CircuitState.open));

      // Wait for recoveryTimeout
      await Future<void>.delayed(const Duration(milliseconds: 40));

      // Send probe batch
      await sink.output(
        createTestDocument(['probe']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Probe failed -> immediately back to open!
      expect(sink.circuitState, equals(CircuitState.open));

      await sink.dispose();
    });

    test('fails over to fallback endpoint when primary endpoint fails',
        () async {
      final primaryUri = Uri.parse('https://primary.example.com/logs');
      final backupUri = Uri.parse('https://backup.example.com/logs');

      when(
        () => mockClient.post(
          primaryUri,
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('Primary down', 500));

      when(
        () => mockClient.post(
          backupUri,
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('Backup OK', 200));

      final sink = HttpSink(
        url: 'https://primary.example.com/logs',
        failoverUrls: const ['https://backup.example.com/logs'],
        batchSize: 1,
        maxRetries: 1,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['important_log']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Failed over to backup endpoint and succeeded without dropping the log!
      expect(sink.currentUrl, equals('https://backup.example.com/logs'));
      expect(sink.circuitState, equals(CircuitState.closed));

      verify(
        () => mockClient.post(
          backupUri,
          headers: any(named: 'headers'),
          body: jsonEncode(['important_log']),
        ),
      ).called(1);

      // resetFailover brings it back to primary
      sink.resetFailover();
      expect(sink.currentUrl, equals('https://primary.example.com/logs'));

      await sink.dispose();
    });

    test(
        'manual resetCircuit restores closed state and resets consecutiveFailures',
        () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async => http.Response('Error', 500));

      final sink = HttpSink(
        url: 'https://example.com/logs',
        batchSize: 1,
        maxRetries: 1,
        failureThreshold: 1,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['fail']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(sink.circuitState, equals(CircuitState.open));

      sink.resetCircuit();
      expect(sink.circuitState, equals(CircuitState.closed));
      expect(sink.consecutiveFailures, equals(0));

      await sink.dispose();
    });
  });

  group('HttpSink Retry-After Backpressure', () {
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
    });

    test('honors Retry-After integer delay and retries successfully', () async {
      int attempts = 0;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final _) async {
        attempts++;
        if (attempts == 1) {
          return http.Response(
            'Rate Limited',
            429,
            headers: {'retry-after': '0'},
          );
        }
        return http.Response('OK', 200);
      });

      final sink = HttpSink(
        url: 'https://example.com/logs',
        batchSize: 1,
        maxRetries: 2,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['throttled_log']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(attempts, equals(2));
      expect(sink.consecutiveFailures, equals(0));

      await sink.dispose();
    });
  });

  group('HttpSink Serialization', () {
    test(
        'serializes and deserializes circuit breaker and failover configuration',
        () {
      registerLogdNetworkSerializers();

      final sink = HttpSink(
        url: 'https://logs.prod.acme.corp',
        failoverUrls: const [
          'https://backup1.acme.corp',
          'https://backup2.acme.corp',
        ],
        failureThreshold: 7,
        recoveryTimeout: const Duration(seconds: 45),
        batchSize: 25,
      );

      final json = LoggerSerializationRegistry.serializeSink(sink);
      expect(json['type'], equals('HttpSink'));
      final config = json['config'] as Map<String, dynamic>;
      expect(config['url'], equals('https://logs.prod.acme.corp'));
      expect(
          config['failoverUrls'],
          equals([
            'https://backup1.acme.corp',
            'https://backup2.acme.corp',
          ]));
      expect(config['failureThreshold'], equals(7));
      expect(config['recoveryTimeoutMs'], equals(45000));
      expect(config['batchSize'], equals(25));

      final deserialized =
          LoggerSerializationRegistry.deserializeSink(json) as HttpSink;
      expect(deserialized.url, equals(sink.url));
      expect(deserialized.failoverUrls, equals(sink.failoverUrls));
      expect(deserialized.failureThreshold, equals(7));
      expect(deserialized.recoveryTimeout, equals(const Duration(seconds: 45)));
      expect(deserialized.batchSize, equals(25));
    });
  });

  group('HttpSink GZip Compression', () {
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
    });

    test(
        'compresses payload with GZip and adds Content-Encoding header when compress is true',
        () async {
      Object? capturedBody;
      Map<String, String>? capturedHeaders;

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final invocation) async {
        capturedHeaders =
            invocation.namedArguments[#headers] as Map<String, String>?;
        capturedBody = invocation.namedArguments[#body];
        return http.Response('OK', 200);
      });

      final sink = HttpSink(
        url: 'https://example.com/logs',
        batchSize: 1,
        compress: true,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['gzip_compressed_message']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(capturedHeaders, isNotNull);
      expect(capturedHeaders!['Content-Encoding'], equals('gzip'));
      expect(capturedHeaders!['Content-Type'], equals('application/json'));

      expect(capturedBody, isA<List<int>>());
      final decompressedBytes = gzip.decode(capturedBody as List<int>);
      final jsonString = utf8.decode(decompressedBytes);
      final decodedList = jsonDecode(jsonString) as List<dynamic>;
      expect(decodedList, equals(['gzip_compressed_message']));

      await sink.dispose();
    });

    test(
        'does not compress payload or add Content-Encoding header when compress is false',
        () async {
      Object? capturedBody;
      Map<String, String>? capturedHeaders;

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((final invocation) async {
        capturedHeaders =
            invocation.namedArguments[#headers] as Map<String, String>?;
        capturedBody = invocation.namedArguments[#body];
        return http.Response('OK', 200);
      });

      final sink = HttpSink(
        url: 'https://example.com/logs',
        batchSize: 1,
        compress: false,
        client: mockClient,
      );

      await sink.output(
        createTestDocument(['uncompressed_message']),
        testEntry,
        LogLevel.info,
        const StandardPipelineFactory(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(capturedHeaders, isNotNull);
      expect(capturedHeaders!.containsKey('Content-Encoding'), isFalse);
      expect(capturedHeaders!['Content-Type'], equals('application/json'));

      expect(capturedBody, isA<String>());
      final decodedList = jsonDecode(capturedBody as String) as List<dynamic>;
      expect(decodedList, equals(['uncompressed_message']));

      await sink.dispose();
    });
  });
}
