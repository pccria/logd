import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'markdown_dialect.dart';
import 'markdown_formatter.dart';
import 'markdown_table_formatter.dart';

/// A pre-wired [Handler] that outputs Markdown markup to a file.
///
/// Uses [MarkdownFormatter] (or [MarkdownTableFormatter] when [tableMode] is
/// `true`), `MarkdownEncoder`, and [FileSink].
///
/// To offload formatting, Markdown encoding, and file I/O to a background
/// isolate, use [MarkdownFileHandler.async].
@immutable
class MarkdownFileHandler extends Handler {
  /// Creates a synchronous [MarkdownFileHandler].
  ///
  /// The [path] specifies the target destination `.md` file.
  ///
  /// Contextual [metadata] controls which standard log attributes are included.
  ///
  /// The [dialect] selects between [MarkdownDialect.gfm],
  /// [MarkdownDialect.commonmark], and [MarkdownDialect.gitlab].
  ///
  /// When [tableMode] is `true`, uses [MarkdownTableFormatter] to emit compact
  /// table rows instead of full card sections.
  MarkdownFileHandler({
    required final String path,
    final Set<LogMetadata> metadata = const {
      LogMetadata.timestamp,
      LogMetadata.logger,
      LogMetadata.origin,
    },
    final MarkdownDialect dialect = MarkdownDialect.gfm,
    final String contextLanguage = 'json',
    final bool tableMode = false,
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
             (tableMode
                 ? MarkdownTableFormatter(metadata: metadata, dialect: dialect)
                 : MarkdownFormatter(
                     metadata: metadata,
                     dialect: dialect,
                     contextLanguage: contextLanguage,
                   )),
         sink: FileSink(
           path,
           encoder: const AutoTextEncoder(),
           fileRotation: fileRotation,
           lineLength: lineLength,
         ),
         decorators: decorators ?? const [],
       );

  /// Creates an asynchronous [MarkdownFileHandler] offloaded to a background
  /// isolate.
  static AsyncHandler async({
    required final String path,
    final Set<LogMetadata> metadata = const {
      LogMetadata.timestamp,
      LogMetadata.logger,
      LogMetadata.origin,
    },
    final MarkdownDialect dialect = MarkdownDialect.gfm,
    final String contextLanguage = 'json',
    final bool tableMode = false,
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
        (tableMode
            ? MarkdownTableFormatter(metadata: metadata, dialect: dialect)
            : MarkdownFormatter(
                metadata: metadata,
                dialect: dialect,
                contextLanguage: contextLanguage,
              )),
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
