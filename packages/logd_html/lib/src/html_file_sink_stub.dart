import 'package:logd/logd.dart';

import 'html_encoder.dart';

/// Supported open modes for HTML log files.
enum HtmlFileMode {
  /// Always truncates the target file, creating a fresh HTML document.
  overwrite,

  /// Appends to an existing HTML document if present, safely stripping closing
  /// tags and inserting a session divider, or creates a new document if absent.
  appendSession,

  /// Emits an embeddable HTML fragment without document shells.
  fragment,
}

/// Web/stub implementation of [HtmlFileSink].
base class HtmlFileSink extends LogSink<LogDocument> {
  /// Creates an [HtmlFileSink] stub.
  HtmlFileSink(
    this.path, {
    this.encoder = const HtmlEncoder(),
    this.mode = HtmlFileMode.appendSession,
    this.fileRotation,
    this.lineLength = 120,
    super.enabled,
  });

  /// The path to the file.
  final String path;

  /// The HTML encoder used.
  final HtmlEncoder encoder;

  /// The file open mode.
  final HtmlFileMode mode;

  /// The rotation policy.
  final FileRotation? fileRotation;

  /// The preferred line length.
  final int? lineLength;

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    throw UnsupportedError('HtmlFileSink is not supported on web platforms.');
  }
}
