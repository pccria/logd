import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

/// # logd_dio: Quick-Start & Basic Usage Guide
///
/// This is the primary example showing how to quickly integrate `logd_dio`
/// into any Dio-powered application.
///
/// For specialized and in-depth feature examples, see:
/// - `security/sanitization_example.dart`: Header/query redaction & body truncation.
/// - `tracing/distributed_tracing_example.dart`: Ambient request IDs & async zone isolation.
/// - `resilience/error_and_cancellation_example.dart`: CancelToken handling & error diagnostics.
/// - `advanced/custom_pipeline_example.dart`: cURL output, response headers & custom loggers.
/// - `showcase_gallery.dart`: Interactive multi-demo CLI launcher.
Future<void> main() async {
  // 1. Initialize logd with styled console output
  Logger.configure('global', handlers: [
    ConsoleHandler(theme: const DarkTheme()),
  ]);

  // 2. Configure Dio with LogdDioInterceptor
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 5),
    ),
  );

  dio.interceptors.add(
    LogdDioInterceptor(
      const LogdDioOptions(
        logCurl: true, // Output executable cURL commands
        maxBodyLength: 512, // Truncate large payloads safely
      ),
    ),
  );

  // 3. Trace requests across async zones using LogContext
  await LogContext.run({'requestId': 'req-demo-42', 'userId': 101}, () async {
    Logger.get('app').info('Fetching user profile...');

    try {
      final response = await dio.get<Map<String, dynamic>>('/todos/1');
      Logger.get('app').info(
        'Fetched todo successfully',
        context: {'title': response.data?['title']},
      );
    } on DioException catch (e) {
      Logger.get('app').error('Request failed', error: e);
    }
  });
}
