import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logd/testing.dart';
import 'package:logd_dio/logd_dio.dart';
import 'package:test/test.dart';

void main() {
  group('HttpMetrics Calculation & Categorization', () {
    test('computes throughput and categorizes status accurately', () {
      final metrics = HttpMetrics.compute(
        durationMs: 500, // 0.5s
        statusCode: 200,
        requestBytes: 1024, // 1 KB
        responseBytes: 1024, // 1 KB -> 2 KB total in 0.5s = 4.0 KB/s
      );

      expect(metrics.durationMs, 500);
      expect(metrics.statusCode, 200);
      expect(metrics.statusCategory, '2xx');
      expect(metrics.isHttpError, isFalse);
      expect(metrics.throughputKBps, 4.0);
    });

    test('categorizes all HTTP status ranges correctly', () {
      expect(
        HttpMetrics.compute(durationMs: 10, statusCode: 101).statusCategory,
        '1xx',
      );
      expect(
        HttpMetrics.compute(durationMs: 10, statusCode: 204).statusCategory,
        '2xx',
      );
      expect(
        HttpMetrics.compute(durationMs: 10, statusCode: 302).statusCategory,
        '3xx',
      );
      expect(
        HttpMetrics.compute(durationMs: 10, statusCode: 404).statusCategory,
        '4xx',
      );
      expect(
        HttpMetrics.compute(durationMs: 10, statusCode: 503).statusCategory,
        '5xx',
      );
    });

    test('serializes to and from JSON faithfully', () {
      final original = HttpMetrics.compute(
        durationMs: 250,
        statusCode: 201,
        requestBytes: 512,
        responseBytes: 2048,
      );
      final json = original.toJson();
      final restored = HttpMetrics.fromJson(json);
      expect(restored, equals(original));
      expect(restored.throughputKBps, original.throughputKBps);
    });
  });

  group('StreamMetricsTracker Unit Tests', () {
    test(
      'passes chunks through downstream without mutation or buffering',
      () async {
        final controller = StreamController<Uint8List>();
        int? trackedChunks;
        int? trackedBytes;
        Duration? trackedDuration;
        Object? trackedError;

        final wrapped = StreamMetricsTracker.wrap(
          source: controller.stream,
          onComplete: (final chunks, final bytes, final elapsed, final err) {
            trackedChunks = chunks;
            trackedBytes = bytes;
            trackedDuration = elapsed;
            trackedError = err;
          },
        );

        final receivedChunks = <Uint8List>[];
        final subscription = wrapped.listen(receivedChunks.add);

        controller.add(Uint8List.fromList([1, 2, 3]));
        controller.add(Uint8List.fromList([4, 5, 6, 7]));
        await controller.close();
        await subscription.asFuture<void>();

        expect(receivedChunks.length, 2);
        expect(receivedChunks[0], [1, 2, 3]);
        expect(receivedChunks[1], [4, 5, 6, 7]);

        expect(trackedChunks, 2);
        expect(trackedBytes, 7);
        expect(trackedDuration, isNotNull);
        expect(trackedError, isNull);
      },
    );

    test('captures stream errors and notifies onComplete', () async {
      final controller = StreamController<Uint8List>();
      Object? capturedError;

      final wrapped = StreamMetricsTracker.wrap(
        source: controller.stream,
        onComplete: (final chunks, final bytes, final elapsed, final err) {
          capturedError = err;
        },
      );

      final completer = Completer<void>();
      wrapped.listen(
        (final _) {},
        onError: (final Object err) {
          completer.complete();
        },
      );

      controller.add(Uint8List.fromList([1, 2]));
      controller.addError(StateError('Stream connection reset'));
      await completer.future;

      expect(capturedError, isA<StateError>());
    });
  });

  group('Streaming Telemetry Integration with Dio', () {
    test('emits STREAM_COMPLETED log on stream completion', () async {
      final testLogger = TestLogger('test_stream_logging');

      final dio = Dio();
      dio.httpClientAdapter = _MockStreamingAdapter();
      dio.interceptors.add(
        LogdDioInterceptor(
          LogdDioOptions(logger: testLogger.logger, trackStreamMetrics: true),
        ),
      );

      final response = await dio.get<ResponseBody>(
        'https://cdn.example.com/stream/data',
        options: Options(responseType: ResponseType.stream),
      );

      // Drain response stream as consumer would
      final streamBytes = <int>[];
      await for (final chunk in response.data!.stream) {
        streamBytes.addAll(chunk);
      }

      expect(utf8.decode(streamBytes), 'CHUNK1-CHUNK2-CHUNK3');

      // Wait for stream completion callback microtasks
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final streamLog = testLogger.logs.firstWhere(
        (final l) => l.message.toString().contains('<-- STREAM_COMPLETED'),
      );

      expect(streamLog, isNotNull);
      final ctx = streamLog.context!;
      final streamCtx = ctx['stream'] as Map<String, dynamic>;
      expect(streamCtx['chunks'], 3);
      expect(streamCtx['bytes'], 20); // 'CHUNK1-CHUNK2-CHUNK3'.length == 20

      testLogger.dispose();
    });
  });
}

class _MockStreamingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    final RequestOptions options,
    final Stream<dynamic>? requestStream,
    final Future<void>? cancelFuture,
  ) async {
    final stream = Stream<Uint8List>.fromIterable([
      Uint8List.fromList(utf8.encode('CHUNK1-')),
      Uint8List.fromList(utf8.encode('CHUNK2-')),
      Uint8List.fromList(utf8.encode('CHUNK3')),
    ]);

    return ResponseBody(
      stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/octet-stream'],
      },
    );
  }

  @override
  void close({final bool force = false}) {}
}
