import 'dart:math';
import 'package:meta/meta.dart';

/// Configures the backoff and jitter strategy for network reconnects and retries.
///
/// Prevents thundering-herd reconnection storms when downstream logging gateways,
/// ingestion proxies, or WebSocket servers restart or experience outages.
@immutable
class BackoffPolicy {
  /// Creates a [BackoffPolicy].
  ///
  /// - [initialDelay]: The base delay for the first retry/reconnect attempt (default: 200ms).
  /// - [maxDelay]: The maximum upper bound duration for any backoff delay (default: 30s).
  /// - [multiplier]: The exponential factor multiplied on each consecutive attempt (default: 2.0).
  /// - [jitter]: Whether to apply randomized full jitter (default: false).
  const BackoffPolicy({
    this.initialDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.jitter = false,
  }) : assert(
         multiplier >= 1.0,
         'multiplier must be greater than or equal to 1.0',
       );

  /// The base delay for the first retry/reconnect attempt.
  final Duration initialDelay;

  /// The maximum delay ceiling.
  final Duration maxDelay;

  /// The exponential growth multiplier applied per attempt.
  final double multiplier;

  /// Whether to randomize the delay using full jitter: `delay * random.nextDouble()`.
  final bool jitter;

  /// Computes the backoff delay for the given [attempt] (1-based index).
  ///
  /// If [jitter] is true, the computed delay will be randomly distributed
  /// between 0 and the deterministic exponential ceiling for that attempt.
  Duration computeDelay(final int attempt, [final Random? random]) {
    if (attempt <= 0) {
      return Duration.zero;
    }

    // Deterministic exponential delay calculation:
    // delay = initialDelay * (multiplier ^ (attempt - 1))
    final exponent = attempt - 1;
    final factor = pow(multiplier, exponent).toDouble();
    final calculatedMs = (initialDelay.inMilliseconds * factor).clamp(
      0.0,
      maxDelay.inMilliseconds.toDouble(),
    );

    if (!jitter) {
      return Duration(milliseconds: calculatedMs.round());
    }

    final rng = random ?? Random();
    final jitteredMs = rng.nextDouble() * calculatedMs;
    return Duration(milliseconds: jitteredMs.round());
  }

  /// Converts this policy to a JSON-compatible map for isolate serialization.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'initialDelayMs': initialDelay.inMilliseconds,
    'maxDelayMs': maxDelay.inMilliseconds,
    'multiplier': multiplier,
    'jitter': jitter,
  };

  /// Deserializes a [BackoffPolicy] from a JSON map.
  factory BackoffPolicy.fromJson(final Map<String, dynamic> json) =>
      BackoffPolicy(
        initialDelay: Duration(
          milliseconds: json['initialDelayMs'] as int? ?? 2000,
        ),
        maxDelay: Duration(milliseconds: json['maxDelayMs'] as int? ?? 120000),
        multiplier: (json['multiplier'] as num?)?.toDouble() ?? 2.0,
        jitter: json['jitter'] as bool? ?? true,
      );

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is BackoffPolicy &&
          runtimeType == other.runtimeType &&
          initialDelay == other.initialDelay &&
          maxDelay == other.maxDelay &&
          multiplier == other.multiplier &&
          jitter == other.jitter;

  @override
  int get hashCode => Object.hash(initialDelay, maxDelay, multiplier, jitter);

  @override
  String toString() =>
      'BackoffPolicy(initialDelay: $initialDelay, maxDelay: $maxDelay, multiplier: $multiplier, jitter: $jitter)';
}
