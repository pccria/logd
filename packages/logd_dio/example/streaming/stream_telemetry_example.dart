import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

/// Demonstrates non-blocking streaming response telemetry with `logd_dio`.
Future<void> main() async {
  Logger.configure(
    'global',
    handlers: [ConsoleHandler(theme: const DarkTheme())],
  );

  final streamLogger = Logger.get('streaming');

  final dio = Dio();
  dio.httpClientAdapter = _MockStreamingAdapter();

  dio.interceptors.add(
    LogdDioInterceptor(
      const LogdDioOptions(
        trackStreamMetrics: true,
        streamCompleteLevel: LogLevel.info,
      ),
    ),
  );

  streamLogger.info('Initiating large file streaming download (10 chunks)...');

  final response = await dio.get<ResponseBody>(
    'https://storage.example.com/data/export.ndjson',
    options: Options(responseType: ResponseType.stream),
  );

  // Consume stream chunks downstream as an application consumer would
  var totalReceivedBytes = 0;
  await for (final chunk in response.data!.stream) {
    totalReceivedBytes += chunk.length;
    // Simulate lightweight stream consumer processing
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  streamLogger.info(
    'Application completed consuming stream ($totalReceivedBytes bytes total).',
  );
}

class _MockStreamingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    final RequestOptions options,
    final Stream<Uint8List>? requestStream,
    final Future<void>? cancelFuture,
  ) async {
    Stream<Uint8List> generateChunks() async* {
      for (var i = 1; i <= 10; i++) {
        final line =
            '{"event": "telemetry_ping", "seq": $i, "timestamp": 17000000$i}\n';
        yield Uint8List.fromList(utf8.encode(line));
      }
    }

    return ResponseBody(
      generateChunks(),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/x-ndjson'],
      },
    );
  }

  @override
  void close({final bool force = false}) {}
}
