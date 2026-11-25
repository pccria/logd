import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

/// A structured schema definition governing a TOON stream or document.
///
/// Encapsulates the table array name, column headers, delimiter character,
/// dialect conventions, and optional explicit column types.
@immutable
final class ToonSchema {
  /// Creates a [ToonSchema] definition.
  const ToonSchema({
    required this.arrayName,
    required this.columns,
    this.delimiter = '\t',
    this.dialect = ToonDialect.compact,
    this.columnTypes = const {},
  });

  /// Creates a [ToonSchema] from a JSON-safe map.
  factory ToonSchema.fromJson(final Map<String, dynamic> json) => ToonSchema(
    arrayName: json['arrayName'] as String? ?? 'logs',
    columns: List.unmodifiable(
      (json['columns'] as List<dynamic>).cast<String>(),
    ),
    delimiter: json['delimiter'] as String? ?? '\t',
    dialect: ToonDialect.values.firstWhere(
      (final e) => e.name == json['dialect'],
      orElse: () => ToonDialect.compact,
    ),
    columnTypes: Map.unmodifiable(
      (json['columnTypes'] as Map<String, dynamic>?)?.map(
            (final k, final v) =>
                MapEntry(k, _parseToonType(v?.toString() ?? 'string')),
          ) ??
          const {},
    ),
  );

  /// The root array or dataset name declared in the preamble (e.g. `'logs'`).
  final String arrayName;

  /// The ordered column names declared for each data row.
  final List<String> columns;

  /// The character used to separate values within rows (defaults to `\t`).
  final String delimiter;

  /// The dialect governing null tokens and preamble comment headers.
  final ToonDialect dialect;

  /// Optional semantic column types mapped by column name.
  final Map<String, ToonType> columnTypes;

  /// Parses a [ToonSchema] from a string source containing a TOON stream.
  ///
  /// Returns `null` if no valid TOON preamble header can be detected.
  static ToonSchema? parse(final String source) {
    if (source.isEmpty) {
      return null;
    }

    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    var dialect = ToonDialect.compact;
    var delimiter = '\t';
    String? arrayName;
    int? headerLineIndex;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        continue;
      }

      if (line.startsWith('-- TOON/')) {
        dialect = ToonDialect.strict;
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          arrayName = parts[2];
        }
        continue;
      }

      if (line.startsWith('-- DELIMITER:')) {
        dialect = ToonDialect.strict;
        final delimMatch = RegExp(
          r'-- DELIMITER:(\S+)\s+QUOTE:',
        ).firstMatch(line);
        if (delimMatch != null) {
          final rawDelim = delimMatch.group(1);
          delimiter = rawDelim == r'\t' ? '\t' : (rawDelim ?? '\t');
        }
        continue;
      }

      if (line.contains('[]{')) {
        headerLineIndex = i;
        break;
      }
    }

    if (headerLineIndex == null) {
      return null;
    }

    final headerStartLine = lines[headerLineIndex].trim();
    final openBracketIndex = headerStartLine.indexOf('[]{');
    if (openBracketIndex == -1) {
      return null;
    }

    arrayName ??= headerStartLine.substring(0, openBracketIndex).trim();

    // Check for single-line compact header: name[]{col1,col2,...}:
    if (headerStartLine.endsWith('}:')) {
      final inside = headerStartLine.substring(
        openBracketIndex + 3,
        headerStartLine.length - 2,
      );
      final columns = inside
          .split(',')
          .map((final c) => c.trim())
          .where((final c) => c.isNotEmpty)
          .toList();

      return ToonSchema(
        arrayName: arrayName,
        columns: List.unmodifiable(columns),
        delimiter: delimiter,
        dialect: dialect,
      );
    }

    // Multi-line explicit typed schema: name[]{\n  col : type;\n}:
    final columns = <String>[];
    final types = <String, ToonType>{};

    for (var i = headerLineIndex + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('}:')) {
        return ToonSchema(
          arrayName: arrayName,
          columns: List.unmodifiable(columns),
          delimiter: delimiter,
          dialect: dialect,
          columnTypes: Map.unmodifiable(types),
        );
      }

      if (line.endsWith(';')) {
        final content = line.substring(0, line.length - 1);
        final colonIdx = content.indexOf(':');
        if (colonIdx != -1) {
          final col = content.substring(0, colonIdx).trim();
          final typeStr = content.substring(colonIdx + 1).trim();
          if (col.isNotEmpty) {
            columns.add(col);
            types[col] = _parseToonType(typeStr);
          }
        }
      }
    }

    return null;
  }

  /// Scans a byte buffer window and extracts a parsed [ToonSchema].
  ///
  /// Limits decoding to an initial 8 KB window to guarantee $O(1)$ memory
  /// allocation overhead even on multi-gigabyte log streams.
  static ToonSchema? parseBytes(final Uint8List bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    final scanLength = bytes.length > 8192 ? 8192 : bytes.length;
    final scanBytes = Uint8List.sublistView(bytes, 0, scanLength);
    final str = convert.utf8.decode(scanBytes, allowMalformed: true);
    return parse(str);
  }

  /// Formats the preamble header string corresponding to this schema.
  ///
  /// When [explicit] is true or [columnTypes] is populated with explicit types,
  /// formats a multi-line type-annotated block. Otherwise formats a single-line
  /// compact column list.
  String toPreamble({final bool explicit = false}) {
    final buffer = StringBuffer();

    if (dialect == ToonDialect.strict) {
      final delimDisplay = delimiter == '\t' ? r'\t' : delimiter;
      buffer.write(
        '-- TOON/1.0 $arrayName\n-- DELIMITER:$delimDisplay QUOTE:" NULL:\\N\n',
      );
    }

    if (explicit && columnTypes.isNotEmpty) {
      var maxColLen = 0;
      for (final col in columns) {
        if (col.length > maxColLen) {
          maxColLen = col.length;
        }
      }

      buffer.write('$arrayName[]{\n');
      for (final col in columns) {
        final type = columnTypes[col] ?? ToonType.string;
        final padding = ' ' * (maxColLen - col.length);
        buffer.write('  $col$padding : $type;\n');
      }
      buffer.write('}:\n');
    } else {
      buffer.write('$arrayName[]{${columns.join(',')}}:\n');
    }

    return buffer.toString();
  }

  /// Serializes into a JSON-safe map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'arrayName': arrayName,
    'columns': columns,
    'delimiter': delimiter,
    'dialect': dialect.name,
    'columnTypes': columnTypes.map(
      (final k, final v) => MapEntry(k, v.toString()),
    ),
  };

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ToonSchema &&
          runtimeType == other.runtimeType &&
          arrayName == other.arrayName &&
          delimiter == other.delimiter &&
          dialect == other.dialect &&
          _listEquals(columns, other.columns) &&
          _mapEquals(columnTypes, other.columnTypes);

  @override
  int get hashCode => Object.hash(
    runtimeType,
    arrayName,
    delimiter,
    dialect,
    Object.hashAll(columns),
    Object.hashAll(columnTypes.keys),
    Object.hashAll(columnTypes.values.map((final v) => v.toString())),
  );

  @override
  String toString() =>
      'ToonSchema(arrayName: $arrayName, columns: $columns, dialect: ${dialect.name})';

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

  static bool _mapEquals(
    final Map<String, ToonType> a,
    final Map<String, ToonType> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key]?.toString() != entry.value.toString()) {
        return false;
      }
    }
    return true;
  }

  static ToonType _parseToonType(final String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('enum(') && trimmed.endsWith(')')) {
      final param = trimmed.substring(5, trimmed.length - 1);
      return ToonType('enum', param);
    }
    switch (trimmed) {
      case 'iso8601':
        return ToonType.iso8601;
      case 'string':
        return ToonType.string;
      case 'markdown':
        return ToonType.markdown;
      case 'stacktrace':
        return ToonType.stacktrace;
      case 'object':
        return ToonType.object;
      default:
        return ToonType(trimmed);
    }
  }
}
