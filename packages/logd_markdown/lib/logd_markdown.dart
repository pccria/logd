/// Markdown satellite package for logd.
///
/// Provides [MarkdownEncoder], [MarkdownFormatter], [MarkdownTableFormatter],
/// [MarkdownDialect], [MarkdownFileHandler], [GitHubStepSummaryHandler],
/// [MarkdownRunSummary], and [MarkdownSummaryFailure] for rendering
/// GitHub-Flavored Markdown (GFM), CommonMark, and GitLab CI log documents.
library;

import 'package:logd/logd.dart';

import 'src/markdown_dialect.dart';
import 'src/markdown_encoder.dart';
import 'src/markdown_file_handler.dart';
import 'src/markdown_formatter.dart';
import 'src/markdown_table_formatter.dart';

export 'src/github_step_summary_handler.dart';
export 'src/markdown_dialect.dart';
export 'src/markdown_encoder.dart';
export 'src/markdown_file_handler.dart';
export 'src/markdown_formatter.dart';
export 'src/markdown_table_formatter.dart';

/// Registers Markdown components into logd's [LoggerSerializationRegistry].
///
/// Call this during isolate setup or app bootstrapping when using isolates or
/// custom serialization pipelines:
/// ```dart
/// registerLogdMarkdownSerializers();
/// ```
void registerLogdMarkdownSerializers() {
  LoggerSerializationRegistry.ensureInitialized();

  LoggerSerializationRegistry.registerFormatter<MarkdownFormatter>(
    type: 'MarkdownFormatter',
    fromJson: (final json) => MarkdownFormatter(
      dialect: MarkdownDialect.values.firstWhere(
        (final e) => e.name == json['dialect'],
        orElse: () => MarkdownDialect.gfm,
      ),
      contextLanguage: json['contextLanguage'] as String? ?? 'json',
      metadata:
          (json['metadata'] as List<dynamic>?)
              ?.map(
                (final e) => LogMetadata.values.firstWhere(
                  (final m) => m.name == e,
                  orElse: () => LogMetadata.timestamp,
                ),
              )
              .toSet() ??
          const {LogMetadata.timestamp, LogMetadata.logger, LogMetadata.origin},
    ),
    toJson: (final val) => <String, dynamic>{
      'dialect': val.dialect.name,
      'contextLanguage': val.contextLanguage,
      'metadata': val.metadata.map((final e) => e.name).toList(),
    },
  );

  LoggerSerializationRegistry.registerFormatter<MarkdownTableFormatter>(
    type: 'MarkdownTableFormatter',
    fromJson: (final json) => MarkdownTableFormatter(
      includeContext: json['includeContext'] as bool? ?? true,
      dialect: MarkdownDialect.values.firstWhere(
        (final e) => e.name == json['dialect'],
        orElse: () => MarkdownDialect.gfm,
      ),
      metadata:
          (json['metadata'] as List<dynamic>?)
              ?.map(
                (final e) => LogMetadata.values.firstWhere(
                  (final m) => m.name == e,
                  orElse: () => LogMetadata.timestamp,
                ),
              )
              .toSet() ??
          const {LogMetadata.timestamp, LogMetadata.logger},
    ),
    toJson: (final val) => <String, dynamic>{
      'includeContext': val.includeContext,
      'dialect': val.dialect.name,
      'metadata': val.metadata.map((final e) => e.name).toList(),
    },
  );
}
