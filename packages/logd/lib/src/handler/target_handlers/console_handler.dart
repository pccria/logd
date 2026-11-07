// ignore_for_file: comment_references

library;

import 'package:meta/meta.dart';

import '../../core/theme/log_theme.dart';
import '../engine/async_handler.dart';
import '../handler.dart';

/// A pre-wired [Handler] that outputs styled log records to stdout/console.
///
/// By default, it uses [StructuredFormatter], [StyleDecorator] with
/// [LogTheme.dark()], and a [ConsoleSink].
///
/// To offload formatting, decoration, and console output to a background
/// isolate, use the [ConsoleHandler.async] constructor.
@immutable
class ConsoleHandler extends Handler {
  /// Creates a synchronous [ConsoleHandler].
  ///
  /// Set [allowSgr] to `true` to allow safe ANSI SGR styling/color codes through
  /// without neutralization. Intended for trusted logs only.
  ConsoleHandler({
    final LogTheme? theme,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final bool allowSgr = false,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
          formatter: formatter ?? const StructuredFormatter(),
          sink: ConsoleSink(
            lineLength: lineLength,
            allowSgr: allowSgr,
          ),
          decorators: decorators ??
              [
                StyleDecorator(theme ?? const LogTheme.dark()),
              ],
        );

  /// Creates an asynchronous [ConsoleHandler] offloaded to a background
  /// isolate.
  ///
  /// Set [allowSgr] to `true` to allow safe ANSI SGR styling/color codes through
  /// without neutralization. Intended for trusted logs only.
  static AsyncHandler async({
    final LogTheme? theme,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final bool allowSgr = false,
    final List<LogFilter> filters = const [],
    final LogEngine engine = const StandardEngine(),
    final Duration? timeout,
  }) =>
      AsyncHandler(
        formatter: formatter ?? const StructuredFormatter(),
        sink: ConsoleSink(
          lineLength: lineLength,
          allowSgr: allowSgr,
        ),
        decorators: decorators ??
            [
              StyleDecorator(theme ?? const LogTheme.dark()),
            ],
        filters: filters,
        engine: engine,
        timeout: timeout,
      );
}
