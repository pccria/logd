import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'html_encoder.dart';
import 'html_stylesheet.dart';

/// A [LogFormatter] that facilitates HTML output.
///
/// It delegates the actual node structuring to [StructuredFormatter], but
/// injects an [HtmlEncoder] into the [LogDocument]'s metadata so that
/// [AutoEncoder]-based sinks (like [FileSink]) automatically render the output
/// as HTML.
@immutable
final class HtmlFormatter implements LogFormatter {
  /// Creates an [HtmlFormatter].
  ///
  /// - [title]: The title of the generated HTML document.
  /// - [stylesheet]: The stylesheet used for HTML CSS/JS injection.
  const HtmlFormatter({
    this.title = 'Log Output',
    this.stylesheet = const DefaultHtmlStylesheet(),
    this.metadata = const {
      LogMetadata.timestamp,
      LogMetadata.logger,
      LogMetadata.origin,
    },
  });

  /// The title of the generated HTML document.
  final String title;

  /// The stylesheet used for HTML CSS/JS injection.
  final HtmlStylesheet stylesheet;

  @override
  final Set<LogMetadata> metadata;

  @override
  void format(
    final LogEntry entry,
    final LogDocument document,
    final LogPipelineFactory factory,
  ) {
    const StructuredFormatter().format(entry, document, factory);
    document.metadata[AutoEncoder.encoderKey] = HtmlEncoder(
      title: title,
      stylesheet: stylesheet,
    );
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is HtmlFormatter &&
          runtimeType == other.runtimeType &&
          title == other.title;
  // Stylesheets are intentionally excluded from equality as custom
  // ones may not implement operator ==.

  @override
  int get hashCode => Object.hash(runtimeType, title);
}
