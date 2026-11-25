import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'markdown_dialect.dart';
import 'markdown_encoder.dart';

/// A [LogFormatter] that facilitates Markdown markup output.
///
/// Delegates node structuring to [StructuredFormatter] and injects a
/// [MarkdownEncoder] configured with [dialect] and [contextLanguage] into the
/// [LogDocument] metadata so [AutoEncoder]-based sinks automatically render the
/// output as Markdown.
@immutable
final class MarkdownFormatter implements LogFormatter {
  /// Creates a [MarkdownFormatter].
  const MarkdownFormatter({
    this.metadata = const {
      LogMetadata.timestamp,
      LogMetadata.logger,
      LogMetadata.origin,
    },
    this.dialect = MarkdownDialect.gfm,
    this.contextLanguage = 'json',
  });

  @override
  final Set<LogMetadata> metadata;

  /// The Markdown flavor used for alerts, callouts, and collapsible blocks.
  final MarkdownDialect dialect;

  /// The fenced code-block language tag used when rendering context maps.
  final String contextLanguage;

  @override
  void format(
    final LogEntry entry,
    final LogDocument document,
    final LogPipelineFactory factory,
  ) {
    StructuredFormatter(metadata: metadata).format(entry, document, factory);
    document.metadata[AutoEncoder.encoderKey] = MarkdownEncoder(
      dialect: dialect,
      contextLanguage: contextLanguage,
    );
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is MarkdownFormatter &&
          runtimeType == other.runtimeType &&
          dialect == other.dialect &&
          contextLanguage == other.contextLanguage &&
          _setEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
    runtimeType,
    dialect,
    contextLanguage,
    Object.hashAll(metadata),
  );

  static bool _setEquals<T>(final Set<T> a, final Set<T> b) =>
      a.length == b.length && a.containsAll(b);
}
