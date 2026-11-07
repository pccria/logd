part of 'encoder.dart';

/// Base class for encoders that automatically detect protocol encoders attached
/// to [LogDocument.metadata] under the standard `'logd.encoder'` key, falling
/// back to a medium-specific default encoder when no encoder is specified.
@immutable
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
@immutable
final class AutoConsoleEncoder extends AutoEncoder {
  /// Creates an [AutoConsoleEncoder].
  ///
  /// Set [allowSgr] to `true` to allow safe ANSI SGR styling/color codes through
  /// without neutralization. Intended for trusted logs only.
  const AutoConsoleEncoder({this.allowSgr = false});

  /// Whether safe ANSI SGR styling/color codes are allowed through without
  /// neutralization.
  ///
  /// Intended for trusted logs only.
  final bool allowSgr;

  @override
  @protected
  LogEncoder get defaultFallback => _defaultConsoleDelegate;

  LogEncoder get _defaultConsoleDelegate {
    try {
      if (io.stdout.supportsAnsiEscapes || allowSgr) {
        return AnsiEncoder(allowSgr: allowSgr);
      }
    } catch (_) {
      // Accessing stdout in some environments might throw
    }
    return const PlainTextEncoder();
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AutoConsoleEncoder &&
          runtimeType == other.runtimeType &&
          allowSgr == other.allowSgr;

  @override
  int get hashCode => Object.hash(runtimeType, allowSgr);
}

/// An encoder for non-terminal sinks (Files, Network) that automatically
/// detects document protocol metadata (e.g. TOON or JSON) and delegates to
/// protocol-specific encoders (such as [JsonEncoder]), falling back to
/// [PlainTextEncoder] for standard plain text.
@immutable
final class AutoTextEncoder extends AutoEncoder {
  /// Creates an [AutoTextEncoder].
  const AutoTextEncoder();

  @override
  @protected
  LogEncoder get defaultFallback => const PlainTextEncoder();
}
