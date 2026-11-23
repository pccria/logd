import 'package:logd/logd.dart';
import 'package:meta/meta.dart';
import 'serializer/body_serializer.dart';
import 'tracing/w3c_trace_context.dart';

/// Configuration options for [LogdDioInterceptor].
@immutable
class LogdDioOptions {
  /// Creates a new [LogdDioOptions] instance.
  const LogdDioOptions({
    this.logger,
    this.requestLevel = LogLevel.debug,
    this.responseLevel = LogLevel.info,
    this.warningLevel = LogLevel.warning,
    this.errorLevel = LogLevel.error,
    this.cancelLevel = LogLevel.debug,
    this.streamCompleteLevel = LogLevel.info,
    this.logRequestHeaders = true,
    this.logRequestBody = true,
    this.logResponseHeaders = false,
    this.logResponseBody = true,
    this.logCurl = false,
    this.prettyCurl = false,
    this.curlIncludeCompressed = true,
    this.maxBodyLength = 1024,
    this.attachAmbientTraceId = true,
    this.tracePropagationMode = TracePropagationMode.both,
    this.traceIdHeader = 'x-request-id',
    this.extractResponseTraceId = true,
    this.logMetrics = true,
    this.trackStreamMetrics = true,
    this.elevateHttpErrors = true,
    this.bodySerializers = const [],
    this.redactedPlaceholder = '***REDACTED***',
    this.sensitiveHeaders = defaultSensitiveHeaders,
    this.sensitiveQueryParams = defaultSensitiveQueryParams,
    this.sensitiveBodyKeys = defaultSensitiveBodyKeys,
  });

  /// Default headers to redact for security and privacy.
  static const Set<String> defaultSensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'token',
    'secret',
    'proxy-authorization',
    'x-auth-token',
    'x-csrf-token',
    'x-access-token',
    'api-key',
  };

  /// Default query parameters to redact.
  static const Set<String> defaultSensitiveQueryParams = {
    'api_key',
    'apikey',
    'token',
    'access_token',
    'refresh_token',
    'secret',
    'password',
    'auth',
  };

  /// Default JSON request and response body keys to redact.
  static const Set<String> defaultSensitiveBodyKeys = {
    'password',
    'password_confirmation',
    'new_password',
    'old_password',
    'secret',
    'client_secret',
    'api_key',
    'apikey',
    'token',
    'access_token',
    'refresh_token',
    'auth_token',
    'id_token',
    'credit_card',
    'creditcard',
    'card_number',
    'cvv',
    'cvc',
    'pin',
    'ssn',
  };

  /// Explicit logger instance to use. If null, defaults to `Logger.get('http')`.
  final Logger? logger;

  /// Log level used when logging outgoing HTTP requests.
  final LogLevel requestLevel;

  /// Log level used when logging successful HTTP responses (< 400).
  final LogLevel responseLevel;

  /// Log level used when logging client HTTP errors (4xx) when [elevateHttpErrors] is enabled.
  final LogLevel warningLevel;

  /// Log level used when logging HTTP request failures or server errors (5xx).
  final LogLevel errorLevel;

  /// Log level used when a request is cancelled by a CancelToken.
  final LogLevel cancelLevel;

  /// Log level used when a streaming response finishes.
  final LogLevel streamCompleteLevel;

  /// Whether to include request headers in the log context.
  final bool logRequestHeaders;

  /// Whether to include the request payload body in the log context.
  final bool logRequestBody;

  /// Whether to include response headers in the log context.
  final bool logResponseHeaders;

  /// Whether to include the response body in the log context.
  final bool logResponseBody;

  /// Whether to generate and log an executable cURL command on outgoing requests.
  final bool logCurl;

  /// Whether to pretty-print generated cURL commands across multiple lines with `\` escapes.
  final bool prettyCurl;

  /// Whether to append `--compressed` to generated cURL when `Accept-Encoding` contains gzip/deflate/br.
  final bool curlIncludeCompressed;

  /// Maximum character length before request/response bodies are truncated.
  final int maxBodyLength;

  /// Legacy toggle: whether to automatically look up `LogContext.current` and inject trace headers.
  ///
  /// When `false`, distributed tracing is disabled (equivalent to [TracePropagationMode.none]).
  final bool attachAmbientTraceId;

  /// Distributed tracing header propagation strategy (W3C, custom single header, both, or none).
  final TracePropagationMode tracePropagationMode;

  /// The header name used when injecting the ambient trace ID in [TracePropagationMode.custom] or [TracePropagationMode.both].
  ///
  /// Defaults to `'x-request-id'`.
  final String traceIdHeader;

  /// Whether to inspect incoming response headers for server trace IDs (`traceparent`, `x-request-id`, etc.)
  /// and attach them to the response log context.
  final bool extractResponseTraceId;

  /// Whether to compute and attach network performance metrics (byte sizes, throughput KB/s, duration).
  final bool logMetrics;

  /// Whether to attach non-blocking streaming telemetry to `ResponseBody.stream` responses.
  final bool trackStreamMetrics;

  /// Whether to automatically elevate HTTP 4xx responses to [warningLevel] and 5xx to [errorLevel]
  /// when non-throwing status validation (`validateStatus`) is configured.
  final bool elevateHttpErrors;

  /// Ordered list of pluggable payload serializers to inspect before falling back to default preview logic.
  final List<LogdBodySerializer> bodySerializers;

  /// Replacement string for sensitive values. Defaults to `'***REDACTED***'`.
  final String redactedPlaceholder;

  /// Case-insensitive set of header names whose values will be redacted.
  final Set<String> sensitiveHeaders;

  /// Case-insensitive set of query parameter keys whose values will be redacted.
  final Set<String> sensitiveQueryParams;

  /// Case-insensitive set of JSON request/response body keys whose values will be redacted.
  final Set<String> sensitiveBodyKeys;
}
