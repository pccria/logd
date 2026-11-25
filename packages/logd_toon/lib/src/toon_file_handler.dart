library;

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'toon_encoder.dart';
import 'toon_formatter.dart';

/// A pre-wired [Handler] that outputs TOON formatted log entries to a file.
///
/// TOON is a compact, token-efficient format designed for feeding logs into
/// machine parsers, analytical query engines, or Large Language Models (LLMs).
/// Uses [ToonFormatter], [ToonEncoder], and [FileSink].
///
/// To offload formatting, TOON encoding, and file I/O to a background
/// worker isolate, use the [ToonFileHandler.async] factory.
@immutable
class ToonFileHandler extends Handler {
  /// Creates a synchronous [ToonFileHandler].
  ///
  /// The [path] specifies the target destination file.
  ///
  /// Contextual [metadata] defines which standard log attributes to include as columns.
  ///
  /// Optional [contextColumns] specifies top-level keys from [LogEntry.context] to promote
  /// to dedicated leading columns before the general `context` column.
  ///
  /// If [sortKeys] is `true`, nested map keys are sorted alphabetically.
  ///
  /// The [maxDepth] bounds recursive serialization for deeply nested objects (defaults to 5).
  ToonFileHandler({
    required final String path,
    final String delimiter = '\t',
    final String arrayName = 'logs',
    final Set<LogMetadata> metadata = const {
      LogMetadata.timestamp,
      LogMetadata.logger,
      LogMetadata.origin,
    },
    final bool explicitSchema = false,
    final bool sortKeys = false,
    final int maxDepth = 5,
    final ToonDialect dialect = ToonDialect.compact,
    final List<String> contextColumns = const [],
    final FileRotation? fileRotation,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
         formatter:
             formatter ??
             ToonFormatter(
               delimiter: delimiter,
               arrayName: arrayName,
               metadata: metadata,
               explicitSchema: explicitSchema,
               sortKeys: sortKeys,
               maxDepth: maxDepth,
               dialect: dialect,
               contextColumns: contextColumns,
             ),
         sink: FileSink(
           path,
           encoder: const ToonEncoder(),
           fileRotation: fileRotation,
           lineLength: lineLength,
         ),
         decorators: decorators ?? const [],
       );

  /// Creates an asynchronous [ToonFileHandler] offloaded to a background isolate.
  ///
  /// The [path] specifies the destination log file path on disk.
  ///
  /// Formatting, serialization, and disk I/O are completely decoupled from the
  /// calling isolate, returning in ~15µs to avoid UI frame drops or event loop lag.
  static AsyncHandler async({
    required final String path,
    final String delimiter = '\t',
    final String arrayName = 'logs',
    final Set<LogMetadata> metadata = const {
      LogMetadata.timestamp,
      LogMetadata.logger,
      LogMetadata.origin,
    },
    final bool explicitSchema = false,
    final bool sortKeys = false,
    final int maxDepth = 5,
    final ToonDialect dialect = ToonDialect.compact,
    final List<String> contextColumns = const [],
    final FileRotation? fileRotation,
    final int? lineLength,
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final List<LogFilter> filters = const [],
    final LogEngine engine = const StandardEngine(),
    final Duration? timeout,
  }) => AsyncHandler(
    formatter:
        formatter ??
        ToonFormatter(
          delimiter: delimiter,
          arrayName: arrayName,
          metadata: metadata,
          explicitSchema: explicitSchema,
          sortKeys: sortKeys,
          maxDepth: maxDepth,
          dialect: dialect,
          contextColumns: contextColumns,
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
