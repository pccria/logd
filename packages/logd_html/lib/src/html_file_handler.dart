// ignore_for_file: comment_references

library;

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'html_encoder.dart';
import 'html_formatter.dart';
import 'html_stylesheet.dart';

/// A pre-wired [Handler] that writes formatted logs to an HTML file.
///
/// It configures [HtmlEncoder] with a [FileSink]. The required HTML document
/// preamble and structure are automatically applied via
/// [WrappingStrategy.document] without requiring manual sink configuration.
///
/// To offload formatting, decoration, and file I/O to a background isolate,
/// use the [HtmlFileHandler.async] constructor.
@immutable
class HtmlFileHandler extends Handler {
  /// Creates a synchronous [HtmlFileHandler].
  HtmlFileHandler({
    required final String path,
    final String? title,
    final HtmlStylesheet? stylesheet,
    final LogTheme? theme,
    final FileRotation? fileRotation,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
          formatter: formatter ??
              HtmlFormatter(
                title: title ?? 'logd Session',
                stylesheet: stylesheet ?? const DefaultHtmlStylesheet(),
              ),
          sink: FileSink(
            path,
            encoder: const AutoTextEncoder(),
            fileRotation: fileRotation,
            lineLength: lineLength,
          ),
          decorators: decorators ??
              [
                StyleDecorator(theme ?? const DarkTheme()),
              ],
        );

  /// Creates an asynchronous [HtmlFileHandler] offloaded to a background
  /// isolate.
  static AsyncHandler async({
    required final String path,
    final String? title,
    final HtmlStylesheet? stylesheet,
    final LogTheme? theme,
    final FileRotation? fileRotation,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final List<LogFilter> filters = const [],
    final LogEngine engine = const StandardEngine(),
    final Duration? timeout,
  }) =>
      AsyncHandler(
        formatter: formatter ??
            HtmlFormatter(
              title: title ?? 'logd Session',
              stylesheet: stylesheet ?? const DefaultHtmlStylesheet(),
            ),
        sink: FileSink(
          path,
          encoder: const AutoTextEncoder(),
          fileRotation: fileRotation,
          lineLength: lineLength,
        ),
        decorators: decorators ??
            [
              StyleDecorator(theme ?? const DarkTheme()),
            ],
        filters: filters,
        engine: engine,
        timeout: timeout,
      );
}
