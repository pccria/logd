/// Tab-Oriented Object Notation (TOON) satellite package for logd.
///
/// Provides [ToonFormatter], [ToonEncoder], and [ToonFileHandler] for streaming
/// token-optimized, machine-readable structured logs into LLMs, DuckDB, or
/// analytical query engines.
library;

import 'package:logd/logd.dart';

import 'src/toon_formatter.dart';

export 'src/toon_encoder.dart';
export 'src/toon_file_handler.dart';
export 'src/toon_formatter.dart';

/// Registers TOON components into logd's [LoggerSerializationRegistry].
///
/// Call this during isolate setup or app bootstrapping when using isolates or
/// custom serialization pipelines:
/// ```dart
/// registerLogdToonSerializers();
/// ```
void registerLogdToonSerializers() {
  LoggerSerializationRegistry.ensureInitialized();
  LoggerSerializationRegistry.registerFormatter<ToonFormatter>(
    type: 'ToonFormatter',
    fromJson: (final json) => ToonFormatter(
      delimiter: json['delimiter'] as String? ?? '\t',
      arrayName: json['arrayName'] as String? ?? 'logs',
      explicitSchema: json['explicitSchema'] as bool? ?? false,
      sortKeys: json['sortKeys'] as bool? ?? false,
      maxDepth: json['maxDepth'] as int? ?? 5,
      dialect: ToonDialect.values.firstWhere(
        (e) => e.name == json['dialect'],
        orElse: () => ToonDialect.compact,
      ),
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
      'delimiter': val.delimiter,
      'arrayName': val.arrayName,
      'explicitSchema': val.explicitSchema,
      'sortKeys': val.sortKeys,
      'maxDepth': val.maxDepth,
      'dialect': val.dialect.name,
      'metadata': val.metadata.map((e) => e.name).toList(),
    },
  );
}
