import 'dart:math';
import 'package:meta/meta.dart';

/// Modes for propagating distributed tracing headers in outgoing HTTP requests.
enum TracePropagationMode {
  /// Injects both W3C `traceparent` (and `tracestate` if present) and the custom
  /// [LogdDioOptions.traceIdHeader] (e.g. `x-request-id`) for maximum backward
  /// and modern cloud compatibility.
  both,

  /// Injects standard W3C `traceparent` (and `tracestate` if present) only.
  w3c,

  /// Injects custom single header [LogdDioOptions.traceIdHeader] only.
  custom,

  /// Disables distributed tracing header injection.
  none,
}

/// Representation of a W3C TraceContext per RFC / W3C Recommendation.
///
/// Encapsulates the `traceparent` header (`00-${traceId}-${spanId}-${traceFlags}`)
/// and optional vendor-specific `tracestate`.
@immutable
class W3cTraceContext {
  /// Creates a new [W3cTraceContext].
  const W3cTraceContext({
    required this.traceId,
    required this.spanId,
    this.traceFlags = '01',
    this.tracestate,
  }) : assert(traceId.length == 32, 'traceId must be 32 hex characters'),
       assert(spanId.length == 16, 'spanId must be 16 hex characters'),
       assert(traceFlags.length == 2, 'traceFlags must be 2 hex characters');

  /// Creates a [W3cTraceContext] from JSON.
  factory W3cTraceContext.fromJson(final Map<String, dynamic> json) =>
      W3cTraceContext(
        traceId: json['traceId'] as String,
        spanId: json['spanId'] as String,
        traceFlags: (json['traceFlags'] as String?) ?? '01',
        tracestate: json['tracestate'] as String?,
      );

  static final RegExp _traceparentRegex = RegExp(
    r'^([0-9a-f]{2})-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})$',
  );

  static final Random _random = Random();

  /// 16-byte (32 lowercase hex characters) unique trace identifier.
  final String traceId;

  /// 8-byte (16 lowercase hex characters) unique span identifier.
  final String spanId;

  /// 1-byte (2 lowercase hex characters) trace flags.
  ///
  /// `01` denotes sampled/recorded; `00` denotes not sampled.
  final String traceFlags;

  /// Optional vendor-specific opaque state list per W3C specification.
  final String? tracestate;

  /// Returns true if the trace is marked as recorded/sampled (`traceFlags` ends with odd bit).
  bool get isSampled => (int.tryParse(traceFlags, radix: 16) ?? 0) & 1 == 1;

  /// Formatted W3C `traceparent` header string (e.g. `00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01`).
  String get traceparent => '00-$traceId-$spanId-$traceFlags';

  /// Parses a W3C `traceparent` header and optional `tracestate`.
  ///
  /// Returns `null` if [traceparent] is null, malformed, or has all-zero traceId/spanId.
  static W3cTraceContext? parse(
    final String? traceparent, [
    final String? tracestate,
  ]) {
    if (traceparent == null) return null;
    final match = _traceparentRegex.firstMatch(
      traceparent.trim().toLowerCase(),
    );
    if (match == null) return null;

    final version = match.group(1)!;
    final traceId = match.group(2)!;
    final spanId = match.group(3)!;
    final traceFlags = match.group(4)!;

    // Spec: Version 00 is the current standard; invalid versions rejected
    if (version != '00') return null;
    if (traceId == '00000000000000000000000000000000') return null;
    if (spanId == '0000000000000000') return null;

    return W3cTraceContext(
      traceId: traceId,
      spanId: spanId,
      traceFlags: traceFlags,
      tracestate: tracestate?.trim().isEmpty ?? true
          ? null
          : tracestate?.trim(),
    );
  }

  /// Generates a compliant [W3cTraceContext].
  ///
  /// If [traceId] is provided, it is sanitized (hyphens removed, padded or trimmed to 32 hex chars).
  /// If omitted, a fresh 32-hex random trace ID is generated.
  /// If [spanId] is omitted, a fresh 16-hex random span ID is generated.
  static W3cTraceContext generate({
    final String? traceId,
    final String? spanId,
    final bool sampled = true,
    final String? tracestate,
  }) {
    final resolvedTraceId = _normalizeOrGenerateHex(traceId, 32);
    final resolvedSpanId = _normalizeOrGenerateHex(spanId, 16);
    final flags = sampled ? '01' : '00';

    return W3cTraceContext(
      traceId: resolvedTraceId,
      spanId: resolvedSpanId,
      traceFlags: flags,
      tracestate: tracestate,
    );
  }

  /// Creates a child span with the same [traceId] and a freshly generated [spanId].
  W3cTraceContext childSpan({final bool? sampled, final String? tracestate}) =>
      W3cTraceContext(
        traceId: traceId,
        spanId: _generateRandomHex(16),
        traceFlags: sampled != null ? (sampled ? '01' : '00') : traceFlags,
        tracestate: tracestate ?? this.tracestate,
      );

  static String _normalizeOrGenerateHex(
    final String? input,
    final int targetLength,
  ) {
    if (input != null && input.isNotEmpty) {
      final sanitized = input.replaceAll('-', '').toLowerCase();
      final hexRegex = RegExp(r'^[0-9a-f]+$');
      if (sanitized.length == targetLength &&
          hexRegex.hasMatch(sanitized) &&
          !sanitized.split('').every((final c) => c == '0')) {
        return sanitized;
      }
      if (sanitized.length > targetLength && hexRegex.hasMatch(sanitized)) {
        final truncated = sanitized.substring(0, targetLength);
        if (!truncated.split('').every((final c) => c == '0')) {
          return truncated;
        }
      }
      if (sanitized.length < targetLength && hexRegex.hasMatch(sanitized)) {
        final padded = sanitized.padLeft(targetLength, '0');
        if (!padded.split('').every((final c) => c == '0')) {
          return padded;
        }
      }
    }
    return _generateRandomHex(targetLength);
  }

  static String _generateRandomHex(final int length) {
    const chars = '0123456789abcdef';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[_random.nextInt(16)]);
    }
    // Prevent all zeros
    if (buffer.toString().split('').every((final c) => c == '0')) {
      return ('1'.padRight(length, 'a'));
    }
    return buffer.toString();
  }

  /// Serializes to a JSON-safe map for isolate transfer.
  Map<String, dynamic> toJson() => {
    'traceId': traceId,
    'spanId': spanId,
    'traceFlags': traceFlags,
    if (tracestate != null) 'tracestate': tracestate,
    'traceparent': traceparent,
  };

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is W3cTraceContext &&
          runtimeType == other.runtimeType &&
          traceId == other.traceId &&
          spanId == other.spanId &&
          traceFlags == other.traceFlags &&
          tracestate == other.tracestate;

  @override
  int get hashCode => Object.hash(traceId, spanId, traceFlags, tracestate);

  @override
  String toString() => traceparent;
}
