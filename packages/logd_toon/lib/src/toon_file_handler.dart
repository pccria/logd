// ignore_for_file: comment_references

library;

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'toon_encoder.dart';
import 'toon_formatter.dart';

/// A pre-wired [Handler] that outputs TOON formatted log entries to a file.
///
/// TOON is a compact, token-efficient format designed for feeding logs into
/// machine parsers or LLMs. Uses [ToonFormatter], [ToonEncoder],
/// and [FileSink].
///
/// To offload formatting, TOON encoding, and file I/O to a background
/// isolate, use the [ToonFileHandler.async] constructor.
@immutable
class ToonFileHandler extends Handler {
  /// Creates a synchronous [ToonFileHandler].
  ToonFileHandler({
    required final String path,
    final String delimiter = '\t',
    final String arrayName = 'logs',
    final bool explicitSchema = false,
    final ToonDialect dialect = ToonDialect.compact,
    final FileRotation? fileRotation,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
          formatter: formatter ??
              ToonFormatter(
                delimiter: delimiter,
                arrayName: arrayName,
                explicitSchema: explicitSchema,
                dialect: dialect,
              ),
          sink: FileSink(
            path,
            encoder: const ToonEncoder(),
            fileRotation: fileRotation,
            lineLength: lineLength,
          ),
          decorators: decorators ?? const [],
        );

  /// Creates an asynchronous [ToonFileHandler] offloaded to a background
  /// isolate.
  static AsyncHandler async({
    required final String path,
    final String delimiter = '\t',
    final String arrayName = 'logs',
    final bool explicitSchema = false,
    final ToonDialect dialect = ToonDialect.compact,
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
            ToonFormatter(
              delimiter: delimiter,
              arrayName: arrayName,
              explicitSchema: explicitSchema,
              dialect: dialect,
            ),
        sink: FileSink(
          path,
          encoder: const ToonEncoder(),
          fileRotation: fileRotation,
          lineLength: lineLength,
        ),
        decorators: decorators ?? const [],
        filters: filters,
        engine: engine,
        timeout: timeout,
      );
}
