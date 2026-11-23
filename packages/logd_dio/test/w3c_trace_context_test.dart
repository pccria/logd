import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd/testing.dart';
import 'package:logd_dio/logd_dio.dart';
import 'package:test/test.dart';

void main() {
  group('W3cTraceContext Unit & Parsing Tests', () {
    test('parses valid W3C traceparent string correctly', () {
      const traceparent =
          '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';
      final ctx = W3cTraceContext.parse(traceparent);
      expect(ctx, isNotNull);
      expect(ctx!.traceId, '4bf92f3577b34da6a3ce929d0e0e4736');
      expect(ctx.spanId, '00f067aa0ba902b7');
      expect(ctx.traceFlags, '01');
      expect(ctx.isSampled, isTrue);
      expect(ctx.traceparent, traceparent);
    });

    test('parses traceparent with optional tracestate', () {
      const traceparent =
          '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00';
      const tracestate = 'congo=t61rcWkgMzE,rojo=1';
      final ctx = W3cTraceContext.parse(traceparent, tracestate);
      expect(ctx, isNotNull);
      expect(ctx!.isSampled, isFalse);
      expect(ctx.tracestate, tracestate);
    });

    test('rejects malformed or all-zero trace identifiers', () {
      expect(W3cTraceContext.parse(null), isNull);
      expect(W3cTraceContext.parse('invalid-header'), isNull);
      expect(
        W3cTraceContext.parse(
          '00-00000000000000000000000000000000-00f067aa0ba902b7-01',
        ),
        isNull,
      );
      expect(
        W3cTraceContext.parse(
          '00-4bf92f3577b34da6a3ce929d0e0e4736-0000000000000000-01',
        ),
        isNull,
      );
      expect(
        W3cTraceContext.parse(
          '01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
        ),
        isNull,
      );
    });

    test('generates valid 32-hex traceId and 16-hex spanId', () {
      final ctx = W3cTraceContext.generate(sampled: true);
      expect(ctx.traceId.length, 32);
      expect(ctx.spanId.length, 16);
      expect(ctx.traceFlags, '01');
      expect(ctx.isSampled, isTrue);
      expect(ctx.traceparent.startsWith('00-'), isTrue);
    });

    test('childSpan maintains traceId and creates new spanId', () {
      final parent = W3cTraceContext.generate();
      final child = parent.childSpan();
      expect(child.traceId, parent.traceId);
      expect(child.spanId, isNot(equals(parent.spanId)));
      expect(child.spanId.length, 16);
    });

    test('serializes to and from JSON faithfully', () {
      final original = W3cTraceContext.generate(tracestate: 'vendor=alpha');
      final json = original.toJson();
      final restored = W3cTraceContext.fromJson(json);
      expect(restored, equals(original));
      expect(restored.tracestate, 'vendor=alpha');
    });
  });

  group('W3C TraceContext & Interceptor Injection Tests', () {
    late Dio dio;
    late _CapturingAdapter adapter;

    setUp(() {
      adapter = _CapturingAdapter();
      dio = Dio()..httpClientAdapter = adapter;
    });

    test(
      'TracePropagationMode.both injects traceparent and custom header',
      () async {
        dio.interceptors.add(
          LogdDioInterceptor(
            const LogdDioOptions(
              tracePropagationMode: TracePropagationMode.both,
              traceIdHeader: 'x-request-id',
            ),
          ),
        );

        await LogContext.run(
          {
            'traceId': '4bf92f3577b34da6a3ce929d0e0e4736',
            'tracestate': 'congo=val1',
          },
          () async {
            await dio.get<void>('https://api.example.com/data');
          },
        );

        expect(adapter.lastHeaders, isNotNull);
        final headers = adapter.lastHeaders!;
        expect(headers['traceparent'], isNotNull);
        expect(
          headers['traceparent'].toString().startsWith(
            '00-4bf92f3577b34da6a3ce929d0e0e4736-',
          ),
          isTrue,
        );
        expect(headers['tracestate'], 'congo=val1');
        expect(headers['x-request-id'], isNotNull);
      },
    );

    test('TracePropagationMode.w3c injects only W3C headers', () async {
      dio.interceptors.add(
        LogdDioInterceptor(
          const LogdDioOptions(
            tracePropagationMode: TracePropagationMode.w3c,
            traceIdHeader: 'x-request-id',
          ),
        ),
      );

      await LogContext.run(
        {'traceId': '4bf92f3577b34da6a3ce929d0e0e4736'},
        () async {
          await dio.get<void>('https://api.example.com/data');
        },
      );

      final headers = adapter.lastHeaders!;
      expect(headers['traceparent'], isNotNull);
      expect(headers.containsKey('x-request-id'), isFalse);
    });

    test('TracePropagationMode.custom injects only custom header', () async {
      dio.interceptors.add(
        LogdDioInterceptor(
          const LogdDioOptions(
            tracePropagationMode: TracePropagationMode.custom,
            traceIdHeader: 'x-correlation-id',
          ),
        ),
      );

      await LogContext.run({'requestId': 'req-alpha-99'}, () async {
        await dio.get<void>('https://api.example.com/data');
      });

      final headers = adapter.lastHeaders!;
      expect(headers['x-correlation-id'], 'req-alpha-99');
      expect(headers.containsKey('traceparent'), isFalse);
    });

    test('TracePropagationMode.none injects zero trace headers', () async {
      dio.interceptors.add(
        LogdDioInterceptor(
          const LogdDioOptions(tracePropagationMode: TracePropagationMode.none),
        ),
      );

      await LogContext.run(
        {
          'requestId': 'req-alpha-99',
          'traceId': '4bf92f3577b34da6a3ce929d0e0e4736',
        },
        () async {
          await dio.get<void>('https://api.example.com/data');
        },
      );

      final headers = adapter.lastHeaders!;
      expect(headers.containsKey('traceparent'), isFalse);
      expect(headers.containsKey('x-request-id'), isFalse);
    });

    test('extracts server response trace headers into context', () async {
      final testLogger = TestLogger('test_server_trace');

      adapter.responseHeaders = {
        'traceparent': [
          '00-88882f3577b34da6a3ce929d0e0e4736-111167aa0ba902b7-01',
        ],
        'x-request-id': ['srv-req-4290'],
      };

      dio.interceptors.add(
        LogdDioInterceptor(
          LogdDioOptions(
            logger: testLogger.logger,
            extractResponseTraceId: true,
          ),
        ),
      );

      await dio.get<void>('https://api.example.com/data');

      final responseLog = testLogger.logs.firstWhere(
        (final l) => l.message.toString().contains('<-- 200'),
      );
      final ctx = responseLog.context!;
      expect(
        ctx['serverTraceparent'],
        '00-88882f3577b34da6a3ce929d0e0e4736-111167aa0ba902b7-01',
      );
      expect(ctx['serverResponseTraceId'], 'srv-req-4290');

      testLogger.dispose();
    });
  });
}

class _CapturingAdapter implements HttpClientAdapter {
  Map<String, dynamic>? lastHeaders;
  Map<String, List<String>> responseHeaders = {};

  @override
  Future<ResponseBody> fetch(
    final RequestOptions options,
    final Stream<dynamic>? requestStream,
    final Future<void>? cancelFuture,
  ) async {
    lastHeaders = Map<String, dynamic>.from(options.headers);
    return ResponseBody.fromString(
      '{"status":"ok"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...responseHeaders,
      },
    );
  }

  @override
  void close({final bool force = false}) {}
}
