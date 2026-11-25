import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'toon_encoder.dart';

/// A [LogFormatter] that facilitates Token-Oriented Object Notation (TOON).
///
/// TOON is a compact, token-efficient format designed for feeding logs into
/// machine parsers, analytical query engines, or Large Language Models (LLMs).
/// It outputs a column schema definition once in a preamble header followed by
/// uniform, tab-delimited rows of values.
@immutable
final class ToonFormatter implements LogFormatter {
  /// Creates a [ToonFormatter].
  ///
  /// The [delimiter] specifies the separator between column values (defaults to `\t`).
  ///
  /// The [arrayName] defines the root dataset identifier in the preamble header (e.g. `'logs'`).
  ///
  /// Contextual [metadata] defines which standard log attributes to include as columns.
  ///
  /// When [explicitSchema] is `true`, an aligned, type-annotated schema block is emitted.
  ///
  /// If [sortKeys] is `true`, nested map keys are sorted alphabetically.
  ///
  /// The [maxDepth] bounds recursive serialization for deeply nested objects (defaults to 5).
  ///
  /// The [dialect] specifies whether to emit compact headers or strict SQL/DuckDB parser comments.
  ///
  /// The [contextColumns] specifies top-level keys from [LogEntry.context] to promote to
  /// dedicated first-class TOON columns placed immediately before the catch-all `context` column.
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
    this.contextColumns = const [],
  }) : assert(maxDepth >= 1, 'maxDepth must be >= 1');

  /// Whether to include an explicit schema definition in the header.
  final bool explicitSchema;

  /// The character used to separate values within rows.
  final String delimiter;

  /// The name of the array in the header (e.g., `'logs'`).
  final String arrayName;

  /// Contextual metadata to include as leading columns.
  @override
  final Set<LogMetadata> metadata;

  /// Whether to sort Map keys alphabetically.
  final bool sortKeys;

  /// Maximum depth for recursive object serialization.
  final int maxDepth;

  /// Controls preamble header comments and null token encoding.
  final ToonDialect dialect;

  /// Specific context map keys to extract as dedicated first-class TOON columns.
  ///
  /// Promoted context keys are placed immediately before the catch-all `context`
  /// column, strictly preserving column invariance across all rows.
  final List<String> contextColumns;

  @override
  void format(
    final LogEntry entry,
    final LogDocument document,
    final LogPipelineFactory factory,
  ) {
    if (delimiter.isEmpty ||
        delimiter.contains('\n') ||
        delimiter.contains('\r')) {
      throw ArgumentError.value(
        delimiter,
        'delimiter',
        'Delimiter cannot be empty or contain newline characters.',
      );
    }

    final columns = <String>[];
    final schema = <String, ToonType>{};
    final normalized = entry.message
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final messageLines = normalized.split('\n');
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

      // Promoted context columns
      final entryContext = entry.context;
      final contextMap = entryContext is Map
          ? (entryContext as Map).cast<String, Object?>()
          : null;

      for (final ctxCol in contextColumns) {
        final val = contextMap?[ctxCol];
        add(ctxCol, val ?? '', ToonType.string);
      }

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
          _listEquals(contextColumns, other.contextColumns) &&
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
    Object.hashAll(contextColumns),
    Object.hashAll(metadata),
  );

  static bool _listEquals(final List<String> a, final List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
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
    if (delimiter.isEmpty ||
        delimiter.contains('\n') ||
        delimiter.contains('\r')) {
      throw ArgumentError.value(
        delimiter,
        'delimiter',
        'Delimiter cannot be empty or contain newline characters.',
      );
    }

    final columns = <String>[];
    final tags = <String, int>{};
    final schema = <String, ToonType>{};
    final normalized = entry.message
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final messageLines = normalized.split('\n');
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
