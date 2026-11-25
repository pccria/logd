import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'curl_generator.dart';
import 'metrics/http_metrics.dart';
import 'options.dart';
import 'sanitizer.dart';
import 'stream/stream_metrics_tracker.dart';
import 'tracing/w3c_trace_context.dart';

const String _stopwatchExtraKey = '_logd_dio_sw';
const String _requestBytesExtraKey = '_logd_dio_req_bytes';
const String _traceContextExtraKey = '_logd_dio_trace_ctx';

/// A production-grade Dio [Interceptor] powered by the `logd` logging engine.
///
/// Features:
/// - W3C TraceContext distributed tracing (`traceparent`, `tracestate`) and ambient correlation.
/// - Non-blocking streaming telemetry tracking for `ResponseBody.stream`.
/// - Monotonic latency measurement using [Stopwatch] (immune to system clock drifts).
/// - Network transfer metrics calculation (request/response bytes and throughput KB/s).
/// - Automatic security sanitization for tokens, cookies, and sensitive parameters.
/// - Clean request cancellation handling (distinguishes user aborts from operational failures).
/// - Pluggable custom payload serializers and pretty/compressed cURL command generation.
/// - Automatic HTTP status code elevation (4xx/5xx in non-throwing pipelines).
class LogdDioInterceptor extends Interceptor {
  /// Creates a new [LogdDioInterceptor] with optional [options].
  LogdDioInterceptor([this.options = const LogdDioOptions()]);

  /// Configuration options governing logging levels, sanitization, tracing, and metrics.
  final LogdDioOptions options;

  Logger get _logger => options.logger ?? Logger.get('http');

  @override
  void onRequest(
    final RequestOptions options,
    final RequestInterceptorHandler handler,
  ) {
    // 1. Distributed Tracing Propagation (W3C TraceContext & Custom Trace Header)
    final mode = this.options.attachAmbientTraceId
        ? this.options.tracePropagationMode
        : TracePropagationMode.none;

    if (mode != TracePropagationMode.none) {
      final currentContext = LogContext.current;
      final rawTraceparent = currentContext?['traceparent']?.toString();
      final rawTracestate = currentContext?['tracestate']?.toString();
      final rawTraceId =
          (currentContext?['traceId'] ?? currentContext?['requestId'])
              ?.toString();

      W3cTraceContext? w3cCtx;
      if (rawTraceparent != null) {
        w3cCtx = W3cTraceContext.parse(rawTraceparent, rawTracestate);
      }
      w3cCtx ??= W3cTraceContext.generate(
        traceId: rawTraceId,
        tracestate: rawTracestate,
      );
      options.extra[_traceContextExtraKey] = w3cCtx;

      // Inject W3C traceparent
      if (mode == TracePropagationMode.w3c ||
          mode == TracePropagationMode.both) {
        final hasTraceparent = options.headers.keys.any(
          (final k) => k.toLowerCase() == 'traceparent',
        );
        if (!hasTraceparent) {
          options.headers['traceparent'] = w3cCtx.traceparent;
        }
        if (w3cCtx.tracestate != null) {
          final hasTracestate = options.headers.keys.any(
            (final k) => k.toLowerCase() == 'tracestate',
          );
          if (!hasTracestate) {
            options.headers['tracestate'] = w3cCtx.tracestate;
          }
        }
      }

      // Inject custom single header (e.g. x-request-id)
      if (mode == TracePropagationMode.custom ||
          mode == TracePropagationMode.both) {
        final hasCustom = options.headers.keys.any(
          (final k) =>
              k.toLowerCase() == this.options.traceIdHeader.toLowerCase(),
        );
        if (!hasCustom) {
          final customVal =
              currentContext?['requestId']?.toString() ??
              currentContext?['traceId']?.toString() ??
              w3cCtx.traceId;
          options.headers[this.options.traceIdHeader] = customVal;
        }
      }
    }

    // 2. Monotonic Stopwatch Timing
    final sw = Stopwatch()..start();
    options.extra[_stopwatchExtraKey] = sw;

    // 3. Request Bytes Accounting
    final contentLengthHeader = options.headers[Headers.contentLengthHeader];
    int? reqContentLen;
    if (contentLengthHeader is int) {
      reqContentLen = contentLengthHeader;
    } else if (contentLengthHeader is String) {
      reqContentLen = int.tryParse(contentLengthHeader);
    }
    final reqBytes = LogdSanitizer.estimateBytes(options.data, reqContentLen);
    if (reqBytes != null) {
      options.extra[_requestBytesExtraKey] = reqBytes;
    }

    // 4. Sanitized Context
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

    final reqContentType =
        options.contentType ??
        options.headers[Headers.contentTypeHeader]?.toString();

    final bodyPreview = this.options.logRequestBody
        ? LogdSanitizer.safeBodyPreview(
            options.data,
            maxBodyLength: this.options.maxBodyLength,
            sensitiveKeys: this.options.sensitiveBodyKeys,
            placeholder: this.options.redactedPlaceholder,
            serializers: this.options.bodySerializers,
            contentType: reqContentType,
          )
        : null;

    final curl = this.options.logCurl
        ? LogdCurlGenerator.generate(
            options,
            sensitiveHeaders: this.options.sensitiveHeaders,
            placeholder: this.options.redactedPlaceholder,
            sensitiveQueryParams: this.options.sensitiveQueryParams,
            sensitiveBodyKeys: this.options.sensitiveBodyKeys,
            pretty: this.options.prettyCurl,
            includeCompressed: this.options.curlIncludeCompressed,
            serializers: this.options.bodySerializers,
          )
        : null;

    final traceCtx = options.extra[_traceContextExtraKey] as W3cTraceContext?;
    final context = <String, dynamic>{
      if (traceCtx != null) 'traceparent': traceCtx.traceparent,
      if (reqBytes != null) 'requestBytes': reqBytes,
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

    final reqBytes =
        response.requestOptions.extra[_requestBytesExtraKey] as int?;

    final resContentLengthHeader =
        response.headers[Headers.contentLengthHeader]?.firstOrNull;
    final resContentLen = resContentLengthHeader != null
        ? int.tryParse(resContentLengthHeader)
        : null;
    final resBytes = LogdSanitizer.estimateBytes(response.data, resContentLen);

    final metrics = HttpMetrics.compute(
      durationMs: durationMs,
      statusCode: statusCode,
      requestBytes: reqBytes,
      responseBytes: resBytes,
    );

    // Extract Server Trace IDs from Response Headers
    final serverTraceInfo = options.extractResponseTraceId
        ? LogdSanitizer.extractResponseTraceInfo(response.headers.map)
        : null;

    final sanitizedHeaders = options.logResponseHeaders
        ? LogdSanitizer.sanitizeHeaders(
            response.headers.map,
            options.sensitiveHeaders,
            options.redactedPlaceholder,
          )
        : null;

    final resContentType =
        response.headers[Headers.contentTypeHeader]?.firstOrNull;

    final bodyPreview = options.logResponseBody
        ? LogdSanitizer.safeBodyPreview(
            response.data,
            maxBodyLength: options.maxBodyLength,
            sensitiveKeys: options.sensitiveBodyKeys,
            placeholder: options.redactedPlaceholder,
            serializers: options.bodySerializers,
            contentType: resContentType,
          )
        : null;

    final sanitizedUri = LogdSanitizer.sanitizeUri(
      response.requestOptions.uri,
      options.sensitiveQueryParams,
      options.redactedPlaceholder,
    );

    // Non-blocking Stream Telemetry Tracking
    if (options.trackStreamMetrics && response.data is ResponseBody) {
      final responseBody = response.data as ResponseBody;
      final streamMethod = response.requestOptions.method.toUpperCase();

      responseBody.stream = StreamMetricsTracker.wrap(
        source: responseBody.stream,
        onComplete:
            (final chunkCount, final totalBytes, final elapsed, final error) {
              final streamDurationMs = elapsed.inMilliseconds;
              final streamMetrics = HttpMetrics.compute(
                durationMs: streamDurationMs,
                statusCode: statusCode,
                responseBytes: totalBytes,
              );

              final isStreamError = error != null;
              final statusTag = isStreamError
                  ? 'STREAM_FAILED'
                  : 'STREAM_COMPLETED';
              final streamMsg =
                  '<-- $statusTag $statusCode $streamMethod $sanitizedUri ($chunkCount chunks, ${totalBytes}B, ${streamDurationMs}ms)';

              _dispatchLog(
                isStreamError
                    ? options.errorLevel
                    : options.streamCompleteLevel,
                streamMsg,
                error: error,
                context: {
                  'status': statusCode,
                  'stream': {
                    'chunks': chunkCount,
                    'bytes': totalBytes,
                    'durationMs': streamDurationMs,
                    if (streamMetrics.throughputKBps != null)
                      'throughputKBps': streamMetrics.throughputKBps,
                  },
                },
              );
            },
      );
    }

    final traceCtx =
        response.requestOptions.extra[_traceContextExtraKey]
            as W3cTraceContext?;

    final context = <String, dynamic>{
      'status': statusCode,
      'durationMs': durationMs,
      'statusCategory': metrics.statusCategory,
      if (options.logMetrics) 'metrics': metrics.toJson(),
      if (traceCtx != null) 'traceparent': traceCtx.traceparent,
      if (serverTraceInfo != null) ...serverTraceInfo,
      if (sanitizedHeaders != null && sanitizedHeaders.isNotEmpty)
        'headers': sanitizedHeaders,
      if (bodyPreview != null) 'body': bodyPreview,
    };

    final message =
        '<-- $statusCode ${response.requestOptions.method.toUpperCase()} $sanitizedUri (${durationMs}ms)';

    // Automatic HTTP Status Code Level Elevation
    LogLevel dispatchLevel;
    if (options.elevateHttpErrors) {
      if (statusCode >= 500) {
        dispatchLevel = options.errorLevel;
      } else if (statusCode >= 400) {
        dispatchLevel = options.warningLevel;
      } else {
        dispatchLevel = options.responseLevel;
      }
    } else {
      dispatchLevel = options.responseLevel;
    }

    _dispatchLog(dispatchLevel, message, context: context);

    super.onResponse(response, handler);
  }

  @override
  void onError(final DioException err, final ErrorInterceptorHandler handler) {
    final sw = err.requestOptions.extra[_stopwatchExtraKey] as Stopwatch?;
    sw?.stop();
    final durationMs = sw?.elapsedMilliseconds ?? 0;
    final isCancel = err.type == DioExceptionType.cancel;
    final sanitizedUri = LogdSanitizer.sanitizeUri(
      err.requestOptions.uri,
      options.sensitiveQueryParams,
      options.redactedPlaceholder,
    );

    final traceCtx =
        err.requestOptions.extra[_traceContextExtraKey] as W3cTraceContext?;
    final serverTraceInfo = options.extractResponseTraceId
        ? LogdSanitizer.extractResponseTraceInfo(err.response?.headers.map)
        : null;

    if (isCancel) {
      final message =
          '<-- CANCELLED ${err.requestOptions.method.toUpperCase()} $sanitizedUri (${durationMs}ms)';
      final context = <String, dynamic>{
        'durationMs': durationMs,
        if (err.response?.statusCode != null)
          'status': err.response?.statusCode,
        if (traceCtx != null) 'traceparent': traceCtx.traceparent,
        if (serverTraceInfo != null) ...serverTraceInfo,
      };

      _dispatchLog(options.cancelLevel, message, context: context);
    } else {
      final statusCode = err.response?.statusCode;
      final statusPrefix = statusCode != null ? '$statusCode ' : '';
      final message =
          '<-- FAILED $statusPrefix${err.requestOptions.method.toUpperCase()} $sanitizedUri (${durationMs}ms)';

      final resContentType =
          err.response?.headers[Headers.contentTypeHeader]?.firstOrNull;

      final errorBody = options.logResponseBody
          ? LogdSanitizer.safeBodyPreview(
              err.response?.data,
              maxBodyLength: options.maxBodyLength,
              sensitiveKeys: options.sensitiveBodyKeys,
              placeholder: options.redactedPlaceholder,
              serializers: options.bodySerializers,
              contentType: resContentType,
            )
          : null;

      final metrics = HttpMetrics.compute(
        durationMs: durationMs,
        statusCode: statusCode ?? 0,
      );

      final context = <String, dynamic>{
        if (statusCode != null) 'status': statusCode,
        'durationMs': durationMs,
        'statusCategory': metrics.statusCategory,
        if (options.logMetrics) 'metrics': metrics.toJson(),
        'errorType': err.type.name,
        if (traceCtx != null) 'traceparent': traceCtx.traceparent,
        if (serverTraceInfo != null) ...serverTraceInfo,
        if (errorBody != null) 'responseBody': errorBody,
      };

      final rawError = err.error ?? err.message;
      final sanitizedError = LogdSanitizer.sanitizeError(
        rawError,
        options.sensitiveQueryParams,
        options.redactedPlaceholder,
      );

      _dispatchLog(
        options.errorLevel,
        message,
        error: sanitizedError,
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
        _logger.trace(
          message,
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
      case LogLevel.debug:
        _logger.debug(
          message,
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
      case LogLevel.info:
        _logger.info(
          message,
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
      case LogLevel.warning:
        _logger.warning(
          message,
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
      case LogLevel.error:
        _logger.error(
          message,
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
    }
  }
}
