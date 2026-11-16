// ignore_for_file: comment_references

library;

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'html_encoder.dart';
import 'html_file_sink.dart';
import 'html_formatter.dart';
import 'html_stylesheet.dart';
import 'html_view.dart';

/// A pre-wired [Handler] that writes formatted logs to an HTML file.
///
/// It configures [HtmlEncoder] with a specialized [HtmlFileSink]. Document
/// integrity is maintained via [HtmlFileMode] to prevent duplicate headers
/// and footers across application restarts or multi-logger outputs.
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
    final HtmlView? view,
    final LogTheme? theme,
    final FileRotation? fileRotation,
    final int? lineLength,
    final String? sessionLabel,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final HtmlFileMode fileMode = HtmlFileMode.appendSession,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
         formatter: _createFormatter(formatter, title, stylesheet, view),
         sink: _createSink(
           path,
           title,
           stylesheet,
           view,
           fileMode,
           fileRotation,
           lineLength,
           sessionLabel,
         ),
         decorators: decorators ?? [StyleDecorator(theme ?? const DarkTheme())],
       );

  /// Creates an asynchronous [HtmlFileHandler] offloaded to a background
  /// isolate.
  static AsyncHandler async({
    required final String path,
    final String? title,
    final HtmlStylesheet? stylesheet,
    final HtmlView? view,
    final LogTheme? theme,
    final FileRotation? fileRotation,
    final int? lineLength,
    final String? sessionLabel,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final HtmlFileMode fileMode = HtmlFileMode.appendSession,
    final List<LogFilter> filters = const [],
    final LogEngine engine = const StandardEngine(),
    final Duration? timeout,
  }) => AsyncHandler(
    formatter: _createFormatter(formatter, title, stylesheet, view),
    sink: _createSink(
      path,
      title,
      stylesheet,
      view,
      fileMode,
      fileRotation,
      lineLength,
      sessionLabel,
    ),
    decorators: decorators ?? [StyleDecorator(theme ?? const DarkTheme())],
    filters: filters,
    engine: engine,
    timeout: timeout,
  );

  static LogFormatter _createFormatter(
    final LogFormatter? formatter,
    final String? title,
    final HtmlStylesheet? stylesheet,
    final HtmlView? view,
  ) =>
      formatter ??
      (view != null
          ? HtmlFormatter(view: view)
          : HtmlFormatter(
              title: title ?? 'logd Session',
              stylesheet: stylesheet ?? const DefaultHtmlStylesheet(),
            ));

  static HtmlFileSink _createSink(
    final String path,
    final String? title,
    final HtmlStylesheet? stylesheet,
    final HtmlView? view,
    final HtmlFileMode fileMode,
    final FileRotation? fileRotation,
    final int? lineLength,
    final String? sessionLabel,
  ) => HtmlFileSink(
    path,
    encoder: _createEncoder(title, stylesheet, view),
    mode: fileMode,
    fileRotation: fileRotation,
    lineLength: lineLength,
    sessionLabel: sessionLabel,
  );

  static HtmlEncoder _createEncoder(
    final String? title,
    final HtmlStylesheet? stylesheet,
    final HtmlView? view,
  ) => view != null
      ? HtmlEncoder(view: view)
      : HtmlEncoder(
          title: title ?? 'logd Session',
          stylesheet: stylesheet ?? const DefaultHtmlStylesheet(),
        );
}
