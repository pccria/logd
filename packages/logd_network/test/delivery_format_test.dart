import 'dart:convert' as convert;
import 'dart:io';

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

  group('HttpDeliveryFormat Tests', () {
    late MockHttpClient mockClient;
    const testUrl = 'https://example.com/logs';
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
      'jsonArray delivery format sends JSON array with application/json header',
      () async {
        String? capturedBody;
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
          capturedBody = invocation.namedArguments[#body] as String?;
          return http.Response('OK', 200);
        });

        final sink = HttpSink(
          url: testUrl,
          batchSize: 2,
          deliveryFormat: HttpDeliveryFormat.jsonArray,
          client: mockClient,
        );

        const factory = StandardPipelineFactory();
        await sink.output(
          createTestDocument(['log entry 1']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.output(
          createTestDocument(['log entry 2']),
          testEntry,
          LogLevel.warning,
          factory,
        );
        await sink.flush();

        expect(capturedHeaders?['Content-Type'], equals('application/json'));
        expect(capturedBody, isNotNull);

        final parsed = convert.jsonDecode(capturedBody!) as List;
        expect(parsed, hasLength(2));
        expect(parsed[0], equals('log entry 1'));
        expect(parsed[1], equals('log entry 2'));

        await sink.dispose();
      },
    );

    test(
      'ndjson delivery format formats records separated by newline with application/x-ndjson header',
      () async {
        List<int>? capturedBytes;
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
          final body = invocation.namedArguments[#body];
          if (body is List<int>) {
            capturedBytes = body;
          } else if (body is String) {
            capturedBytes = convert.utf8.encode(body);
          }
          return http.Response('OK', 200);
        });

        final sink = HttpSink(
          url: testUrl,
          batchSize: 2,
          deliveryFormat: HttpDeliveryFormat.ndjson,
          client: mockClient,
        );

        const factory = StandardPipelineFactory();
        await sink.output(
          createTestDocument(['{"event":"start"}']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.output(
          createTestDocument(['{"event":"end"}']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.flush();

        expect(
          capturedHeaders?['Content-Type'],
          equals('application/x-ndjson'),
        );
        expect(capturedBytes, isNotNull);

        final payloadText = convert.utf8.decode(capturedBytes!);
        expect(payloadText, equals('{"event":"start"}\n{"event":"end"}\n'));

        final lines = payloadText.trim().split('\n');
        expect(lines, hasLength(2));
        expect(lines[0], equals('{"event":"start"}'));
        expect(lines[1], equals('{"event":"end"}'));

        await sink.dispose();
      },
    );

    test(
      'raw delivery format concatenates byte streams directly with application/octet-stream',
      () async {
        List<int>? capturedBytes;
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
          final body = invocation.namedArguments[#body];
          if (body is List<int>) {
            capturedBytes = body;
          } else if (body is String) {
            capturedBytes = convert.utf8.encode(body);
          }
          return http.Response('OK', 200);
        });

        final sink = HttpSink(
          url: testUrl,
          batchSize: 2,
          deliveryFormat: HttpDeliveryFormat.raw,
          client: mockClient,
        );

        const factory = StandardPipelineFactory();
        await sink.output(
          createTestDocument(['AAA']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.output(
          createTestDocument(['BBB']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.flush();

        expect(
          capturedHeaders?['Content-Type'],
          equals('application/octet-stream'),
        );
        expect(capturedBytes, isNotNull);
        expect(convert.utf8.decode(capturedBytes!), equals('AAABBB'));

        await sink.dispose();
      },
    );

    test(
      'explicit user headers override default delivery format Content-Type',
      () async {
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
          return http.Response('OK', 200);
        });

        final sink = HttpSink(
          url: testUrl,
          batchSize: 1,
          deliveryFormat: HttpDeliveryFormat.ndjson,
          headers: const {'Content-Type': 'application/jsonlines+custom'},
          client: mockClient,
        );

        const factory = StandardPipelineFactory();
        await sink.output(
          createTestDocument(['test']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.flush();

        expect(
          capturedHeaders?['Content-Type'],
          equals('application/jsonlines+custom'),
        );
        await sink.dispose();
      },
    );

    test(
      'GZip compression works cleanly with ndjson delivery format',
      () async {
        List<int>? capturedBytes;
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
          final body = invocation.namedArguments[#body];
          if (body is List<int>) {
            capturedBytes = body;
          }
          return http.Response('OK', 200);
        });

        final sink = HttpSink(
          url: testUrl,
          batchSize: 1,
          deliveryFormat: HttpDeliveryFormat.ndjson,
          compress: true,
          client: mockClient,
        );

        const factory = StandardPipelineFactory();
        await sink.output(
          createTestDocument(['compress-me']),
          testEntry,
          LogLevel.info,
          factory,
        );
        await sink.flush();

        expect(
          capturedHeaders?['Content-Type'],
          equals('application/x-ndjson'),
        );
        expect(capturedHeaders?['Content-Encoding'], equals('gzip'));
        expect(capturedBytes, isNotNull);

        // Decompress and verify
        final decompressed = gzip.decode(capturedBytes!);
        expect(convert.utf8.decode(decompressed), equals('compress-me\n'));

        await sink.dispose();
      },
    );
  });
}
