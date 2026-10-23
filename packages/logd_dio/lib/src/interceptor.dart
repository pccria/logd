import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'curl_generator.dart';
import 'options.dart';
import 'sanitizer.dart';

const String _stopwatchExtraKey = '_logd_dio_sw';

/// A production-grade Dio [Interceptor] powered by the `logd` logging engine.
///
/// Features:
/// - Monotonic latency measurement using [Stopwatch] (immune to system clock drifts).
/// - Automatic security sanitization for tokens, cookies, and sensitive headers (SOC2/GDPR compliance).
/// - Clean request cancellation handling (distinguishes user aborts from operational failures).
/// - Optional cURL command generation for fast debugging and Postman reproduction.
/// - Ambient distributed tracing support: automatically forwards `LogContext` request IDs.
class LogdDioInterceptor extends Interceptor {
  /// Creates a new [LogdDioInterceptor] with optional [options].
  LogdDioInterceptor([this.options = const LogdDioOptions()]);

  /// Configuration options governing logging levels, sanitization, and body truncation.
  final LogdDioOptions options;

  Logger get _logger => options.logger ?? Logger.get('http');

  @override
  void onRequest(
    final RequestOptions options,
    final RequestInterceptorHandler handler,
  ) {
    // 1. Ambient Context Trace ID Propagation
    if (this.options.attachAmbientTraceId) {
      final currentContext = LogContext.current;
      final ambientTraceId =
          currentContext?['requestId'] ?? currentContext?['traceId'];
      final hasTraceId = options.headers.keys.any(
        (final key) =>
            key.toLowerCase() == this.options.traceIdHeader.toLowerCase(),
      );
      if (ambientTraceId != null && !hasTraceId) {
        options.headers[this.options.traceIdHeader] = ambientTraceId.toString();
      }
    }

    // 2. Monotonic Stopwatch Timing
    final sw = Stopwatch()..start();
    options.extra[_stopwatchExtraKey] = sw;

    // 3. Sanitized Context
    final sanitizedHeaders = this.options.logRequestHeaders
        ? LogdSanitizer.sanitizeHeaders(
            options.headers,
            this.options.sensitiveHeaders,
            this.options.redactedPlaceholder,
          )
        : null;

    final sanitizedQueryParams = options.queryParameters.isNotEmpty
        ? LogdSanitizer.sanitizeQueryParams(
            options.queryParameters,
            this.options.sensitiveQueryParams,
            this.options.redactedPlaceholder,
          )
        : null;

    final bodyPreview = this.options.logRequestBody
        ? LogdSanitizer.safeBodyPreview(
            options.data,
            maxBodyLength: this.options.maxBodyLength,
            sensitiveKeys: this.options.sensitiveBodyKeys,
            placeholder: this.options.redactedPlaceholder,
          )
        : null;

    final curl = this.options.logCurl
        ? LogdCurlGenerator.generate(
            options,
            sensitiveHeaders: this.options.sensitiveHeaders,
            placeholder: this.options.redactedPlaceholder,
            sensitiveQueryParams: this.options.sensitiveQueryParams,
            sensitiveBodyKeys: this.options.sensitiveBodyKeys,
          )
        : null;

    final context = <String, dynamic>{
      if (sanitizedHeaders != null && sanitizedHeaders.isNotEmpty)
        'headers': sanitizedHeaders,
      if (sanitizedQueryParams != null && sanitizedQueryParams.isNotEmpty)
        'query': sanitizedQueryParams,
      if (bodyPreview != null) 'body': bodyPreview,
      if (curl != null) 'curl': curl,
    };

    final sanitizedUri = LogdSanitizer.sanitizeUri(
      options.uri,
      this.options.sensitiveQueryParams,
      this.options.redactedPlaceholder,
    );
    final message = '--> ${options.method.toUpperCase()} $sanitizedUri';
    _dispatchLog(this.options.requestLevel, message, context: context);

    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    final Response response,
    final ResponseInterceptorHandler handler,
  ) {
    final sw = response.requestOptions.extra[_stopwatchExtraKey] as Stopwatch?;
    sw?.stop();
    final durationMs = sw?.elapsedMilliseconds ?? 0;
    final statusCode = response.statusCode ?? 0;

    final sanitizedHeaders = options.logResponseHeaders
        ? LogdSanitizer.sanitizeHeaders(
            response.headers.map,
            options.sensitiveHeaders,
            options.redactedPlaceholder,
          )
        : null;

    final bodyPreview = options.logResponseBody
        ? LogdSanitizer.safeBodyPreview(
            response.data,
            maxBodyLength: options.maxBodyLength,
            sensitiveKeys: options.sensitiveBodyKeys,
            placeholder: options.redactedPlaceholder,
          )
        : null;

    final context = <String, dynamic>{
      'status': statusCode,
      'durationMs': durationMs,
      if (sanitizedHeaders != null && sanitizedHeaders.isNotEmpty)
        'headers': sanitizedHeaders,
      if (bodyPreview != null) 'body': bodyPreview,
    };

    final sanitizedUri = LogdSanitizer.sanitizeUri(
      response.requestOptions.uri,
      options.sensitiveQueryParams,
      options.redactedPlaceholder,
    );
    final message =
        '<-- $statusCode ${response.requestOptions.method.toUpperCase()} $sanitizedUri (${durationMs}ms)';

    _dispatchLog(options.responseLevel, message, context: context);

    super.onResponse(response, handler);
  }

  @override
  void onError(
    final DioException err,
    final ErrorInterceptorHandler handler,
  ) {
    final sw = err.requestOptions.extra[_stopwatchExtraKey] as Stopwatch?;
    sw?.stop();
    final durationMs = sw?.elapsedMilliseconds ?? 0;
    final isCancel = err.type == DioExceptionType.cancel;
    final sanitizedUri = LogdSanitizer.sanitizeUri(
      err.requestOptions.uri,
      options.sensitiveQueryParams,
      options.redactedPlaceholder,
    );

    if (isCancel) {
      final message =
          '<-- CANCELLED ${err.requestOptions.method.toUpperCase()} $sanitizedUri (${durationMs}ms)';
      final context = <String, dynamic>{
        'durationMs': durationMs,
        if (err.response?.statusCode != null)
          'status': err.response?.statusCode,
      };

      _dispatchLog(options.cancelLevel, message, context: context);
    } else {
      final statusCode = err.response?.statusCode;
      final statusPrefix = statusCode != null ? '$statusCode ' : '';
      final message =
          '<-- FAILED $statusPrefix${err.requestOptions.method.toUpperCase()} $sanitizedUri (${durationMs}ms)';

      final errorBody = options.logResponseBody
          ? LogdSanitizer.safeBodyPreview(
              err.response?.data,
              maxBodyLength: options.maxBodyLength,
              sensitiveKeys: options.sensitiveBodyKeys,
              placeholder: options.redactedPlaceholder,
            )
          : null;

      final context = <String, dynamic>{
        if (statusCode != null) 'status': statusCode,
        'durationMs': durationMs,
        'errorType': err.type.name,
        if (errorBody != null) 'responseBody': errorBody,
      };

      _dispatchLog(
        options.errorLevel,
        message,
        error: err.error ?? err.message,
        stackTrace: err.stackTrace,
        context: context,
      );
    }

    super.onError(err, handler);
  }

  void _dispatchLog(
    final LogLevel level,
    final String message, {
    final Object? error,
    final StackTrace? stackTrace,
    final Map<String, dynamic>? context,
  }) {
    switch (level) {
      case LogLevel.trace:
        _logger.trace(message,
            error: error, stackTrace: stackTrace, context: context);
      case LogLevel.debug:
        _logger.debug(message,
            error: error, stackTrace: stackTrace, context: context);
      case LogLevel.info:
        _logger.info(message,
            error: error, stackTrace: stackTrace, context: context);
      case LogLevel.warning:
        _logger.warning(message,
            error: error, stackTrace: stackTrace, context: context);
      case LogLevel.error:
        _logger.error(message,
            error: error, stackTrace: stackTrace, context: context);
    }
  }
}
