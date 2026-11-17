library;

import 'package:meta/meta.dart';

import '../engine/async_handler.dart';
import '../handler.dart';
import '../sink/file_sink.dart';

/// A pre-wired [Handler] that outputs structured JSON to a file.
///
/// Uses [JsonFormatter] paired with a [JsonEncoder] and a [FileSink].
/// When `pretty` is `true`, the output is formatted with indentation.
///
/// To offload formatting, JSON encoding, and file I/O to a background isolate,
/// use the [JsonFileHandler.async] constructor.
@immutable
class JsonFileHandler extends Handler {
  /// Creates a synchronous [JsonFileHandler].
  JsonFileHandler({
    required final String path,
    final bool pretty = true,
    final FileRotation? fileRotation,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
          formatter: formatter ?? const JsonFormatter(),
          sink: FileSink(
            path,
            encoder: JsonEncoder(indent: pretty ? '  ' : null),
            fileRotation: fileRotation,
            lineLength: lineLength,
          ),
          decorators: decorators ?? const [],
        );

  /// Creates an asynchronous [JsonFileHandler] offloaded to a background
  /// isolate.
  static AsyncHandler async({
    required final String path,
    final bool pretty = true,
    final FileRotation? fileRotation,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final List<LogFilter> filters = const [],
    final LogEngine engine = const StandardEngine(),
    final Duration? timeout,
  }) =>
      AsyncHandler(
        formatter: formatter ?? const JsonFormatter(),
        sink: FileSink(
          path,
          encoder: JsonEncoder(indent: pretty ? '  ' : null),
          fileRotation: fileRotation,
          lineLength: lineLength,
        ),
        decorators: decorators ?? const [],
        filters: filters,
        engine: engine,
        timeout: timeout,
      );
}
