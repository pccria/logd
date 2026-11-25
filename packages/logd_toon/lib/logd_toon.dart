/// Tab-Oriented Object Notation (TOON) satellite package for logd.
///
/// Provides [ToonFormatter], [ToonEncoder], [ToonDecoder], [ToonSchema],
/// [ToonRecord], [ToonTokenEstimator], [ToonContextWindow], [ToonDuckDb], and
/// [ToonFileHandler] for token-optimized, bidirectional structured logging,
/// LLM prompt context injection, and analytical query engines.
library;

import 'package:logd/logd.dart';

import 'src/toon_formatter.dart';

export 'src/toon_context_window.dart';
export 'src/toon_decoder.dart';
export 'src/toon_duckdb.dart';
export 'src/toon_encoder.dart';
export 'src/toon_file_handler.dart';
export 'src/toon_formatter.dart';
export 'src/toon_record.dart';
export 'src/toon_schema.dart';
export 'src/toon_token_estimator.dart';

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
        (final e) => e.name == json['dialect'],
        orElse: () => ToonDialect.compact,
      ),
      contextColumns:
          (json['contextColumns'] as List<dynamic>?)?.cast<String>().toList() ??
          const [],
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
      'delimiter': val.delimiter,
      'arrayName': val.arrayName,
      'explicitSchema': val.explicitSchema,
      'sortKeys': val.sortKeys,
      'maxDepth': val.maxDepth,
      'dialect': val.dialect.name,
      'contextColumns': val.contextColumns,
      'metadata': val.metadata.map((final e) => e.name).toList(),
    },
  );
}
