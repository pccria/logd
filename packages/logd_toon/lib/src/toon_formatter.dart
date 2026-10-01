import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'toon_encoder.dart';

/// A [LogFormatter] that facilitates Token-Oriented Object Notation (TOON).
///
/// TOON is a compact, token-efficient format designed for feeding logs into
/// machine parsers or Large Language Models (LLMs). It uses a header definition
/// followed by uniform rows of values separated by a delimiter (default: Tab).
@immutable
final class ToonFormatter implements LogFormatter {
  /// Creates a [ToonFormatter].
  ///
  /// - [delimiter]: The separator between values. Defaults to tab (`\t`).
  /// - [arrayName]: The name of the array in the header (e.g., 'logs').
  /// - [metadata]: Contextual metadata to include in the output columns.
  /// - [explicitSchema]: Whether to include a typed, aligned schema definition
  ///   in the header block (default: false).
  /// - [sortKeys]: Whether to sort Map keys alphabetically.
  /// - [maxDepth]: Maximum depth for recursive object serialization.
  /// - [dialect]: Controls preamble header comments and null token encoding.
  const ToonFormatter({
    this.delimiter = '\t',
    this.arrayName = 'logs',
    this.metadata = const {
      LogMetadata.timestamp,
      LogMetadata.logger,
      LogMetadata.origin,
    },
    this.explicitSchema = false,
    this.sortKeys = false,
    this.maxDepth = 5,
    this.dialect = ToonDialect.compact,
  });

  /// Whether to include an explicit schema definition in the header.
  final bool explicitSchema;

  /// The character used to separate values.
  final String delimiter;

  /// The name of the array in the header (e.g., 'logs').
  final String arrayName;

  /// Contextual metadata to include.
  @override
  final Set<LogMetadata> metadata;

  /// Whether to sort Map keys alphabetically.
  final bool sortKeys;

  /// Maximum depth for recursion.
  final int maxDepth;

  /// Controls preamble header comments and null token encoding.
  final ToonDialect dialect;

  @override
  void format(
    final LogEntry entry,
    final LogDocument document,
    final LogPipelineFactory factory,
  ) {
    final columns = <String>[];
    final schema = <String, ToonType>{};
    final messageLines = entry.message.split('\n');
    var isFirst = true;

    for (final line in messageLines) {
      final map = <String, Object?>{};

      void add(final String key, final Object? value, final ToonType type) {
        if (isFirst) {
          columns.add(key);
          schema[key] = type;
        }
        map[key] = value;
      }

      for (final meta in metadata) {
        add(meta.name, meta.getValue(entry), meta.toonType);
      }

      add(
        'level',
        entry.level.name.toUpperCase(),
        ToonType(
          'enum',
          LogLevel.values.map((final e) => e.name.toUpperCase()).join(','),
        ),
      );
      add('message', line, ToonType.markdown);
      add('error', entry.error ?? '', ToonType.string);
      add('stackTrace', entry.stackTrace ?? '', ToonType.stacktrace);
      add('context', entry.context ?? '', ToonType.string);

      document.metadataBlock(map, factory: factory);
      isFirst = false;
    }

    document
      ..metadata[AutoEncoder.encoderKey] = const ToonEncoder()
      ..metadata['toon_array'] = arrayName
      ..metadata['toon_delimiter'] = delimiter
      ..metadata['toon_columns'] = columns
      ..metadata['toon_sort_keys'] = sortKeys
      ..metadata['toon_max_depth'] = maxDepth
      ..metadata['toon_dialect'] = dialect
      ..metadata['toon_schema'] = explicitSchema ? schema : null;
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ToonFormatter &&
          runtimeType == other.runtimeType &&
          delimiter == other.delimiter &&
          arrayName == other.arrayName &&
          explicitSchema == other.explicitSchema &&
          sortKeys == other.sortKeys &&
          maxDepth == other.maxDepth &&
          dialect == other.dialect &&
          setEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        delimiter,
        arrayName,
        explicitSchema,
        sortKeys,
        maxDepth,
        dialect,
        Object.hashAll(metadata),
      );
}

/// A [LogFormatter] for TOON with "Wise" object representation.
///
/// TOON-Pretty enhances basic TOON by recursively formatting complex objects
/// (Maps and Lists) inside columns using a compact, token-efficient notation.
@Deprecated(
  'ToonPrettyFormatter will be removed in v1.0. '
  'TOON is a machine-only format; color tags serve no real consumer. '
  'Migrate to ToonFormatter(sortKeys: ..., maxDepth: ...) instead.',
)
@immutable
final class ToonPrettyFormatter implements LogFormatter {
  /// Creates a [ToonPrettyFormatter].
  ///
  /// - [delimiter]: The separator between values. Defaults to tab (`\t`).
  /// - [arrayName]: The name of the array in the header (e.g., 'logs').
  /// - [color]: Whether to emit semantic tags for coloring.
  /// - [metadata]: Contextual metadata to include.
  /// - [sortKeys]: Whether to sort Map keys alphabetically.
  /// - [maxDepth]: Maximum depth for recursive object serialization.
  /// - [explicitSchema]: Whether to include a typed, aligned schema definition
  ///   in the header block (default: false).
  const ToonPrettyFormatter({
    this.delimiter = '\t',
    this.arrayName = 'logs',
    this.color = true,
    this.metadata = const {
      LogMetadata.timestamp,
      LogMetadata.logger,
      LogMetadata.origin,
    },
    this.sortKeys = false,
    this.maxDepth = 5,
    this.explicitSchema = false,
  });

  /// Whether to include an explicit schema definition in the header.
  final bool explicitSchema;

  /// The character used to separate values.
  final String delimiter;

  /// The name of the array in the header.
  final String arrayName;

  /// Whether to emit semantic tags for coloring.
  final bool color;

  /// Metadata to include.
  @override
  final Set<LogMetadata> metadata;

  /// Whether to sort Map keys alphabetically.
  final bool sortKeys;

  /// Maximum depth for recursion.
  final int maxDepth;

  @override
  void format(
    final LogEntry entry,
    final LogDocument document,
    final LogPipelineFactory factory,
  ) {
    final columns = <String>[];
    final tags = <String, int>{};
    final schema = <String, ToonType>{};
    final messageLines = entry.message.split('\n');
    var isFirst = true;

    for (final line in messageLines) {
      final map = <String, Object?>{};

      void add(
        final String key,
        final Object? value,
        final int tag,
        final ToonType type,
      ) {
        if (isFirst) {
          columns.add(key);
          tags[key] = tag;
          schema[key] = type;
        }
        map[key] = value;
      }

      for (final meta in metadata) {
        add(meta.name, meta.getValue(entry), meta.tag, meta.toonType);
      }

      add(
        'level',
        entry.level.name.toUpperCase(),
        LogTag.level,
        ToonType(
          'enum',
          LogLevel.values.map((final e) => e.name.toUpperCase()).join(','),
        ),
      );
      add('message', line, LogTag.message, ToonType.markdown);
      add('error', entry.error ?? '', LogTag.error, ToonType.string);
      add(
        'stackTrace',
        entry.stackTrace ?? '',
        LogTag.stackFrame,
        ToonType.stacktrace,
      );
      add('context', entry.context ?? '', LogTag.preview, ToonType.string);

      document.metadataBlock(
        map,
        tags: color ? LogTag.message : LogTag.none,
        factory: factory,
      );
      isFirst = false;
    }

    document
      ..metadata[AutoEncoder.encoderKey] = const ToonEncoder()
      ..metadata['toon_array'] = arrayName
      ..metadata['toon_delimiter'] = delimiter
      ..metadata['toon_columns'] = columns
      ..metadata['toon_tags'] = tags
      ..metadata['toon_sort_keys'] = sortKeys
      ..metadata['toon_max_depth'] = maxDepth
      ..metadata['toon_color'] = color
      ..metadata['toon_schema'] = explicitSchema ? schema : null;
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ToonPrettyFormatter &&
          runtimeType == other.runtimeType &&
          delimiter == other.delimiter &&
          arrayName == other.arrayName &&
          color == other.color &&
          sortKeys == other.sortKeys &&
          maxDepth == other.maxDepth &&
          setEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        delimiter,
        arrayName,
        color,
        sortKeys,
        maxDepth,
        Object.hashAll(metadata),
      );
}
