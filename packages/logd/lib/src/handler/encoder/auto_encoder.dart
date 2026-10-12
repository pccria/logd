part of 'encoder.dart';

/// Base class for encoders that automatically detect protocol encoders attached
/// to [LogDocument.metadata] under the standard `'logd.encoder'` key, falling
/// back to a medium-specific default encoder when no encoder is specified.
abstract base class AutoEncoder implements LogEncoder {
  /// Abstract const constructor for [AutoEncoder].
  const AutoEncoder();

  /// The standard metadata key used by formatters to specify their preferred
  /// physical encoder.
  static const String encoderKey = 'logd.encoder';

  @override
  WrappingStrategy get wrappingStrategy => WrappingStrategy.document;

  /// Resolves the delegate encoder based on the standard `'logd.encoder'`
  /// metadata contract, or [defaultFallback].
  @protected
  LogEncoder resolveDelegate(final LogDocument? document) {
    if (document != null && document.metadata.isNotEmpty) {
      final encoder = document.metadata[encoderKey];
      if (encoder is LogEncoder) {
        return encoder;
      }
    }
    return defaultFallback;
  }

  /// The fallback encoder to use when no protocol metadata is present.
  @protected
  LogEncoder get defaultFallback;

  @override
  void preamble(
    final HandlerContext context,
    final LogLevel level,
    final LogPipelineFactory factory, {
    final LogDocument? document,
  }) {
    resolveDelegate(document).preamble(
      context,
      level,
      factory,
      document: document,
    );
  }

  @override
  void postamble(
    final HandlerContext context,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) {
    resolveDelegate(null).postamble(context, level, factory);
  }

  @override
  void encode(
    final LogEntry entry,
    final LogDocument document,
    final LogLevel level,
    final HandlerContext context,
    final LogPipelineFactory factory, {
    final int? width,
  }) {
    resolveDelegate(document).encode(
      entry,
      document,
      level,
      context,
      factory,
      width: width,
    );
  }
}

/// An encoder for console output that automatically detects document protocol
/// metadata (e.g. TOON or JSON) and delegates to protocol-specific encoders
/// (such as [JsonEncoder]), falling back to terminal capabilities
/// ([AnsiEncoder] vs [PlainTextEncoder]).
final class AutoConsoleEncoder extends AutoEncoder {
  /// Creates an [AutoConsoleEncoder].
  const AutoConsoleEncoder();

  @override
  @protected
  LogEncoder get defaultFallback => _defaultConsoleDelegate;

  LogEncoder get _defaultConsoleDelegate {
    try {
      if (io.stdout.supportsAnsiEscapes) {
        return const AnsiEncoder();
      }
    } catch (_) {
      // Accessing stdout in some environments might throw
    }
    return const PlainTextEncoder();
  }
}

/// An encoder for non-terminal sinks (Files, Network) that automatically
/// detects document protocol metadata (e.g. TOON or JSON) and delegates to
/// protocol-specific encoders (such as [JsonEncoder]), falling back to
/// [PlainTextEncoder] for standard plain text.
final class AutoTextEncoder extends AutoEncoder {
  /// Creates an [AutoTextEncoder].
  const AutoTextEncoder();

  @override
  @protected
  LogEncoder get defaultFallback => const PlainTextEncoder();
}
