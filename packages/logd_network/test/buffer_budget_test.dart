import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com/logs'));
    registerFallbackValue(<String, String>{});
  });

  group('Buffer Budget & Priority Eviction Tests', () {
    late MockHttpClient mockClient;
    const testUrl = 'https://example.com/logs';
    const factory = StandardPipelineFactory();

    final testEntry = LogEntry(
      loggerName: 'app',
      origin: 'test',
      level: LogLevel.info,
      message: 'test',
      timestamp: '2026-11-20T00:00:00Z',
    );

    setUp(() {
      mockClient = MockHttpClient();
    });

    test(
      'maxBufferBytes enforces memory cap with DropPolicy.discardOldest',
      () async {
        String? capturedBody;

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((final invocation) async {
          capturedBody = invocation.namedArguments[#body] as String?;
          return http.Response('OK', 200);
        });

        // 15 bytes max budget allows 3 entries of 5 bytes each ('AAAAA', 'BBBBB', 'CCCCC')
        final sink = HttpSink(
          url: testUrl,
          batchSize: 50,
          maxBufferSize: 100,
          maxBufferBytes: 15,
          dropPolicy: DropPolicy.discardOldest,
          client: mockClient,
        );

        await sink.output(
          createTestDocument(['AAAAA']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.output(
          createTestDocument(['BBBBB']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.output(
          createTestDocument(['CCCCC']),
          testEntry,
          LogLevel.info,
          factory,
        );

        expect(sink.bufferedLogCount, equals(3));
        expect(sink.bufferedBytes, equals(15));

        // Adding DDDDD (5 bytes) must evict AAAAA (oldest)
        await sink.output(
          createTestDocument(['DDDDD']),
          testEntry,
          LogLevel.info,
          factory,
        );
        expect(sink.bufferedLogCount, equals(3));
        expect(sink.bufferedBytes, equals(15));

        await sink.dispose();

        expect(capturedBody, isNotNull);
        final list = convert.jsonDecode(capturedBody!) as List;
        expect(list, equals(['BBBBB', 'CCCCC', 'DDDDD']));
        expect(sink.bufferedBytes, equals(0));
        expect(sink.bufferedLogCount, equals(0));
      },
    );

    test(
      'maxBufferBytes enforces memory cap with DropPolicy.discardNewest',
      () async {
        String? capturedBody;

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((final invocation) async {
          capturedBody = invocation.namedArguments[#body] as String?;
          return http.Response('OK', 200);
        });

        final sink = HttpSink(
          url: testUrl,
          batchSize: 50,
          maxBufferSize: 100,
          maxBufferBytes: 10,
          dropPolicy: DropPolicy.discardNewest,
          client: mockClient,
        );

        await sink.output(
          createTestDocument(['AAAAA']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.output(
          createTestDocument(['BBBBB']),
          testEntry,
          LogLevel.info,
          factory,
        );

        expect(sink.bufferedLogCount, equals(2));
        expect(sink.bufferedBytes, equals(10));

        // Adding CCCCC (5 bytes) would exceed 10 bytes -> rejected
        await sink.output(
          createTestDocument(['CCCCC']),
          testEntry,
          LogLevel.info,
          factory,
        );
        expect(sink.bufferedLogCount, equals(2));
        expect(sink.bufferedBytes, equals(10));

        await sink.dispose();

        expect(capturedBody, isNotNull);
        final list = convert.jsonDecode(capturedBody!) as List;
        expect(list, equals(['AAAAA', 'BBBBB']));
      },
    );

    test(
      'DropPolicy.discardByPriority evicts lowest severity entries first',
      () async {
        String? capturedBody;

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((final invocation) async {
          capturedBody = invocation.namedArguments[#body] as String?;
          return http.Response('OK', 200);
        });

        // 4 entries max
        final sink = HttpSink(
          url: testUrl,
          batchSize: 50,
          maxBufferSize: 4,
          dropPolicy: DropPolicy.discardByPriority,
          client: mockClient,
        );

        await sink.output(
          createTestDocument(['error-1']),
          testEntry,
          LogLevel.error,
          factory,
        );
        await sink.output(
          createTestDocument(['debug-1']),
          testEntry,
          LogLevel.debug,
          factory,
        );
        await sink.output(
          createTestDocument(['info-1']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.output(
          createTestDocument(['warning-1']),
          testEntry,
          LogLevel.warning,
          factory,
        );

        expect(sink.bufferedLogCount, equals(4));

        // Adding error-2 when buffer is full should evict debug-1 (lowest severity)
        await sink.output(
          createTestDocument(['error-2']),
          testEntry,
          LogLevel.error,
          factory,
        );
        expect(sink.bufferedLogCount, equals(4));

        await sink.dispose();

        expect(capturedBody, isNotNull);
        final list = convert.jsonDecode(capturedBody!) as List;
        expect(list, equals(['error-1', 'info-1', 'warning-1', 'error-2']));
      },
    );

    test(
      'DropPolicy.discardByPriority discards incoming entry if lower than all buffered items',
      () async {
        String? capturedBody;

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((final invocation) async {
          capturedBody = invocation.namedArguments[#body] as String?;
          return http.Response('OK', 200);
        });

        final sink = HttpSink(
          url: testUrl,
          batchSize: 50,
          maxBufferSize: 2,
          dropPolicy: DropPolicy.discardByPriority,
          client: mockClient,
        );

        await sink.output(
          createTestDocument(['error-1']),
          testEntry,
          LogLevel.error,
          factory,
        );
        await sink.output(
          createTestDocument(['error-2']),
          testEntry,
          LogLevel.error,
          factory,
        );

        // Incoming debug-1 is lower severity (1) than buffered errors (4) -> dropped
        await sink.output(
          createTestDocument(['debug-1']),
          testEntry,
          LogLevel.debug,
          factory,
        );

        await sink.dispose();

        expect(capturedBody, isNotNull);
        final list = convert.jsonDecode(capturedBody!) as List;
        expect(list, equals(['error-1', 'error-2']));
      },
    );

    test(
      'entries individually exceeding maxBufferBytes are rejected cleanly',
      () async {
        String? capturedBody;

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((final invocation) async {
          capturedBody = invocation.namedArguments[#body] as String?;
          return http.Response('OK', 200);
        });

        final sink = HttpSink(
          url: testUrl,
          batchSize: 50,
          maxBufferSize: 10,
          maxBufferBytes: 8,
          client: mockClient,
        );

        await sink.output(
          createTestDocument(['1234']),
          testEntry,
          LogLevel.info,
          factory,
        ); // 4 bytes -> ok
        expect(sink.bufferedBytes, equals(4));

        await sink.output(
          createTestDocument(['1234567890']),
          testEntry,
          LogLevel.info,
          factory,
        ); // 10 bytes > 8 bytes -> rejected
        expect(sink.bufferedBytes, equals(4));
        expect(sink.bufferedLogCount, equals(1));

        await sink.dispose();

        expect(capturedBody, isNotNull);
        final list = convert.jsonDecode(capturedBody!) as List;
        expect(list, equals(['1234']));
      },
    );

    test(
      'DropPolicy.discardByPriority prevents partial eviction when incoming entry cannot fit',
      () async {
        String? capturedBody;

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((final invocation) async {
          capturedBody = invocation.namedArguments[#body] as String?;
          return http.Response('OK', 200);
        });

        // 15 bytes max budget.
        final sink = HttpSink(
          url: testUrl,
          batchSize: 50,
          maxBufferSize: 10,
          maxBufferBytes: 15,
          dropPolicy: DropPolicy.discardByPriority,
          client: mockClient,
        );

        // 1. Add 5 bytes debug
        await sink.output(
          createTestDocument(['debug']),
          testEntry,
          LogLevel.debug,
          factory,
        );
        // 2. Add 8 bytes error
        await sink.output(
          createTestDocument(['critical']),
          testEntry,
          LogLevel.error,
          factory,
        );

        expect(sink.bufferedBytes, equals(13));
        expect(sink.bufferedLogCount, equals(2));

        // 3. Incoming info entry of 10 bytes:
        // Even if 'debug' (5 bytes) was evicted, 13 - 5 + 10 = 18 > 15 bytes.
        // It cannot fit without evicting 'critical' (error), which is higher priority than info.
        // The incoming entry must be rejected immediately without discarding 'debug'.
        await sink.output(
          createTestDocument(['0123456789']),
          testEntry,
          LogLevel.info,
          factory,
        );

        expect(sink.bufferedBytes, equals(13));
        expect(sink.bufferedLogCount, equals(2));

        await sink.dispose();

        expect(capturedBody, isNotNull);
        final list = convert.jsonDecode(capturedBody!) as List;
        expect(list, equals(['debug', 'critical']));
      },
    );
  });
}
