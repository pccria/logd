import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'markdown_encoder.dart';

/// A [LogFormatter] that facilitates Markdown (GFM) output.
///
/// It delegates node structuring to [StructuredFormatter], but injects
/// a [MarkdownEncoder] into the [LogDocument]'s metadata so that
/// [AutoEncoder]-based sinks (like [FileSink]) automatically render the output
/// as Markdown.
@immutable
final class MarkdownFormatter implements LogFormatter {
  /// Creates a [MarkdownFormatter].
  const MarkdownFormatter({
    this.metadata = const {
      LogMetadata.timestamp,
      LogMetadata.logger,
      LogMetadata.origin,
    },
  });

  @override
  final Set<LogMetadata> metadata;

  @override
  void format(
    final LogEntry entry,
    final LogDocument document,
    final LogPipelineFactory factory,
  ) {
    StructuredFormatter(metadata: metadata).format(entry, document, factory);
    document.metadata[AutoEncoder.encoderKey] = const MarkdownEncoder();
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is MarkdownFormatter &&
          runtimeType == other.runtimeType &&
          _setEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(metadata));

  static bool _setEquals<T>(final Set<T> a, final Set<T> b) =>
      a.length == b.length && a.containsAll(b);
}
