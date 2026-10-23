import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

Future<void> main() async {
  // Configure logd with dark theme, box borders, and forced ANSI encoder
  Logger.configure('global', handlers: [
    Handler(
      formatter: const StructuredFormatter(),
      decorators: const [
        StyleDecorator(DarkTheme()),
        BoxDecorator(),
      ],
      sink: const ConsoleSink(
        lineLength: 86,
        encoder: AnsiEncoder(),
      ),
    ),
  ]);

  final appLogger = Logger.get('auth');

  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter();
  dio.interceptors.add(
    LogdDioInterceptor(
      const LogdDioOptions(
        logCurl: true,
        redactedPlaceholder: '[***REDACTED***]',
      ),
    ),
  );

  await LogContext.run({'traceId': 'trace-49a8', 'tenant': 'us-east-1'},
      () async {
    appLogger.info('Verifying secure session token...');

    await dio.get<Map<String, dynamic>>(
      'https://api.acme.com/v1/auth/session',
      options: Options(
        headers: {
          'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.s3cr3t',
          'x-api-key': 'live_sk_94820194812039',
          'Accept': 'application/json',
        },
      ),
    );

    appLogger
        .info('Session validated. User [pooria] authenticated successfully.');
  });
}

class _MockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"status": "active", "userId": "usr_9921", "role": "admin"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
