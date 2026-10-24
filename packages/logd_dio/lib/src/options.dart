import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

/// Configuration options for [LogdDioInterceptor].
@immutable
class LogdDioOptions {
  /// Creates a new [LogdDioOptions] instance.
  const LogdDioOptions({
    this.logger,
    this.requestLevel = LogLevel.debug,
    this.responseLevel = LogLevel.info,
    this.errorLevel = LogLevel.error,
    this.cancelLevel = LogLevel.debug,
    this.logRequestHeaders = true,
    this.logRequestBody = true,
    this.logResponseHeaders = false,
    this.logResponseBody = true,
    this.logCurl = false,
    this.maxBodyLength = 1024,
    this.attachAmbientTraceId = true,
    this.traceIdHeader = 'x-request-id',
    this.redactedPlaceholder = '***REDACTED***',
    this.sensitiveHeaders = defaultSensitiveHeaders,
    this.sensitiveQueryParams = defaultSensitiveQueryParams,
    this.sensitiveBodyKeys = defaultSensitiveBodyKeys,
  });

  /// Default headers to redact for security and compliance (SOC2 / GDPR).
  static const Set<String> defaultSensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'token',
    'secret',
    'proxy-authorization',
  };

  /// Default query parameters to redact.
  static const Set<String> defaultSensitiveQueryParams = {
    'api_key',
    'apikey',
    'token',
    'access_token',
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
    'api_key',
    'apikey',
    'token',
    'access_token',
    'refresh_token',
    'auth_token',
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

  /// Log level used when logging successful HTTP responses.
  final LogLevel responseLevel;

  /// Log level used when logging HTTP request failures.
  final LogLevel errorLevel;

  /// Log level used when a request is cancelled by a CancelToken.
  final LogLevel cancelLevel;

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

  /// Maximum character length before request/response bodies are truncated.
  final int maxBodyLength;

  /// Whether to automatically look up `LogContext.current['requestId']` and
  /// inject it into the outgoing request's headers if not already present.
  final bool attachAmbientTraceId;

  /// The header name used when injecting the ambient trace ID. Defaults to `'x-request-id'`.
  final String traceIdHeader;

  /// Replacement string for sensitive values. Defaults to `'***REDACTED***'`.
  final String redactedPlaceholder;

  /// Case-insensitive set of header names whose values will be redacted.
  final Set<String> sensitiveHeaders;

  /// Case-insensitive set of query parameter keys whose values will be redacted.
  final Set<String> sensitiveQueryParams;

  /// Case-insensitive set of JSON request/response body keys whose values will be redacted.
  final Set<String> sensitiveBodyKeys;
}
