/// Markdown satellite package for logd.
///
/// Provides [MarkdownEncoder], [MarkdownFormatter], and [MarkdownFileHandler]
/// for rendering GitHub-Flavored Markdown (GFM) log documents.
library;

import 'package:logd/logd.dart';

import 'src/markdown_encoder.dart';
import 'src/markdown_formatter.dart';

export 'src/markdown_encoder.dart';
export 'src/markdown_file_handler.dart';
export 'src/markdown_formatter.dart';

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
      metadata: (json['metadata'] as List<dynamic>?)
              ?.map((e) => LogMetadata.values.firstWhere(
                    (m) => m.name == e,
                    orElse: () => LogMetadata.timestamp,
                  ))
              .toSet() ??
          const {
            LogMetadata.timestamp,
            LogMetadata.logger,
            LogMetadata.origin,
          },
    ),
    toJson: (final val) => <String, dynamic>{
      'metadata': val.metadata.map((e) => e.name).toList(),
    },
  );
}
