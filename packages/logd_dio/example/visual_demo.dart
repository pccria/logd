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

  final authLogger = Logger.get('auth');

  final dio = Dio();
  dio.httpClientAdapter = _MockOAuthAdapter();
  dio.interceptors.add(
    LogdDioInterceptor(
      const LogdDioOptions(
        logCurl: true,
        redactedPlaceholder: '[***REDACTED***]',
        sensitiveBodyKeys: {
          ...LogdDioOptions.defaultSensitiveBodyKeys,
          'client_secret',
        },
      ),
    ),
  );

  await LogContext.run(
    {'traceId': 'trace-49a8', 'tenant': 'us-east-prod'},
    () async {
      authLogger.info(
        'Initiating OAuth2 token exchange with identity provider...',
      );

      await dio.post<Map<String, dynamic>>(
        'https://auth.acme.com/oauth/v2/token',
        data: {
          'grant_type': 'client_credentials',
          'client_id': 'app-worker-07',
          'client_secret': 'vault-secret-94820194812039',
        },
        options: Options(
          headers: {
            'Authorization': 'Basic dXNlcjpwYXNzd29yZA==',
            'x-api-key': 'live_sk_83921938102938',
            'Accept': 'application/json',
          },
        ),
      );

      authLogger.info(
        'Token acquired. Auth worker [worker-07] initialized successfully.',
      );
    },
  );
}

class _MockOAuthAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"token_type": "Bearer", "expires_in": 3600, "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
