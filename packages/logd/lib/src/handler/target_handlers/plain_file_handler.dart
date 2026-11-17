library;

import 'package:meta/meta.dart';

import '../engine/async_handler.dart';
import '../handler.dart';
import '../sink/file_sink.dart';

/// A pre-wired [Handler] that outputs plain text to a file.
///
/// Uses [PlainFormatter] and a [FileSink].
///
/// To offload formatting and file I/O to a background isolate,
/// use the [PlainFileHandler.async] constructor.
@immutable
class PlainFileHandler extends Handler {
  /// Creates a synchronous [PlainFileHandler].
  PlainFileHandler({
    required final String path,
    final FileRotation? fileRotation,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
          formatter: formatter ?? const PlainFormatter(),
          sink: FileSink(
            path,
            encoder: const AutoTextEncoder(),
            fileRotation: fileRotation,
            lineLength: lineLength,
          ),
          decorators: decorators ?? const [],
        );

  /// Creates an asynchronous [PlainFileHandler] offloaded to a background
  /// isolate.
  static AsyncHandler async({
    required final String path,
    final FileRotation? fileRotation,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final List<LogFilter> filters = const [],
    final LogEngine engine = const StandardEngine(),
    final Duration? timeout,
  }) =>
      AsyncHandler(
        formatter: formatter ?? const PlainFormatter(),
        sink: FileSink(
          path,
          encoder: const AutoTextEncoder(),
          fileRotation: fileRotation,
          lineLength: lineLength,
        ),
        decorators: decorators ?? const [],
        filters: filters,
        engine: engine,
        timeout: timeout,
      );
}
