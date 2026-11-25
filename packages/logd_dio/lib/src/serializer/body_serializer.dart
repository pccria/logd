import 'package:meta/meta.dart';

/// Pluggable interface for custom request and response payload serializers.
///
/// Implement this interface to provide customized representations for Protocol
/// Buffers (`GeneratedMessage`), XML, FlatBuffers, or proprietary binary formats
/// before payload truncation and sensitive key redaction.
abstract interface class LogdBodySerializer {
  /// Returns `true` if this serializer can handle [data] with the optional [contentType].
  bool canSerialize(final Object? data, final String? contentType);

  /// Converts [data] into a safe string representation for log dispatch and cURL generation.
  String serialize(final Object? data, final String? contentType);
}

/// A lightweight, lambda-based [LogdBodySerializer] for inline configuration.
@immutable
class FunctionalBodySerializer implements LogdBodySerializer {
  /// Creates a [FunctionalBodySerializer] with explicit [predicate] and [formatter].
  const FunctionalBodySerializer({
    required this.predicate,
    required this.formatter,
  });

  /// Evaluates whether this serializer applies to the given payload.
  final bool Function(Object? data, String? contentType) predicate;

  /// Transforms the payload into a readable string preview.
  final String Function(Object? data, String? contentType) formatter;

  @override
  bool canSerialize(final Object? data, final String? contentType) =>
      predicate(data, contentType);

  @override
  String serialize(final Object? data, final String? contentType) =>
      formatter(data, contentType);
}
