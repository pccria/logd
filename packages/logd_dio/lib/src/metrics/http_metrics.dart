import 'package:meta/meta.dart';

/// Performance and transfer metrics captured during an HTTP transaction lifecycle.
@immutable
class HttpMetrics {
  /// Creates a new [HttpMetrics] snapshot.
  const HttpMetrics({
    required this.durationMs,
    required this.statusCode,
    this.requestBytes,
    this.responseBytes,
    this.throughputKBps,
  });

  /// Factory constructor that computes derived throughput from parameters.
  factory HttpMetrics.compute({
    required final int durationMs,
    required final int statusCode,
    final int? requestBytes,
    final int? responseBytes,
  }) {
    double? throughput;
    final totalBytes = (requestBytes ?? 0) + (responseBytes ?? 0);
    if (durationMs > 0 && totalBytes > 0) {
      final totalKb = totalBytes / 1024.0;
      final totalSec = durationMs / 1000.0;
      throughput = double.parse((totalKb / totalSec).toStringAsFixed(2));
    }

    return HttpMetrics(
      durationMs: durationMs,
      statusCode: statusCode,
      requestBytes: requestBytes,
      responseBytes: responseBytes,
      throughputKBps: throughput,
    );
  }

  /// Creates an [HttpMetrics] instance from a JSON-safe map.
  factory HttpMetrics.fromJson(final Map<String, dynamic> json) => HttpMetrics(
    durationMs: json['durationMs'] as int,
    statusCode: (json['statusCode'] as int?) ?? 0,
    requestBytes: json['requestBytes'] as int?,
    responseBytes: json['responseBytes'] as int?,
    throughputKBps: (json['throughputKBps'] as num?)?.toDouble(),
  );

  /// Roundtrip transaction latency in milliseconds (monotonic Stopwatch).
  final int durationMs;

  /// HTTP response status code.
  final int statusCode;

  /// Estimated or exact byte size of the outgoing HTTP request body.
  final int? requestBytes;

  /// Estimated or exact byte size of the incoming HTTP response body.
  final int? responseBytes;

  /// Computed bidirectional network throughput in Kilobytes per second (KB/s).
  final double? throughputKBps;

  /// Semantic HTTP status category (`'1xx'`, `'2xx'`, `'3xx'`, `'4xx'`, `'5xx'`).
  String get statusCategory {
    if (statusCode >= 500) return '5xx';
    if (statusCode >= 400) return '4xx';
    if (statusCode >= 300) return '3xx';
    if (statusCode >= 200) return '2xx';
    if (statusCode >= 100) return '1xx';
    return 'unknown';
  }

  /// Whether the status code indicates a client error (4xx) or server failure (5xx).
  bool get isHttpError => statusCode >= 400;

  /// Serializes into an isolate-safe map of primitives.
  Map<String, dynamic> toJson() => {
    'durationMs': durationMs,
    'statusCode': statusCode,
    'statusCategory': statusCategory,
    if (requestBytes != null) 'requestBytes': requestBytes,
    if (responseBytes != null) 'responseBytes': responseBytes,
    if (throughputKBps != null) 'throughputKBps': throughputKBps,
  };

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is HttpMetrics &&
          runtimeType == other.runtimeType &&
          durationMs == other.durationMs &&
          statusCode == other.statusCode &&
          requestBytes == other.requestBytes &&
          responseBytes == other.responseBytes &&
          throughputKBps == other.throughputKBps;

  @override
  int get hashCode => Object.hash(
    durationMs,
    statusCode,
    requestBytes,
    responseBytes,
    throughputKBps,
  );

  @override
  String toString() =>
      'HttpMetrics(status: $statusCode, duration: ${durationMs}ms, '
      'req: ${requestBytes ?? 0}B, res: ${responseBytes ?? 0}B, throughput: ${throughputKBps ?? 0}KB/s)';
}
