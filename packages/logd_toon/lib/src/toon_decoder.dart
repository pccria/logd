import 'dart:async';
import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'toon_record.dart';
import 'toon_schema.dart';

/// A streaming-capable decoder for Token-Oriented Object Notation (TOON).
///
/// Deserializes TOON strings, byte buffers, or line streams into structured
/// [ToonDocument] and [ToonRecord] instances while preserving column alignment,
/// dialect conventions, and nested map/list structures.
@immutable
final class ToonDecoder {
  /// Creates a [ToonDecoder].
  ///
  /// Set [parseNested] to `false` if nested `{k:v}` map and `[a,b]` list strings
  /// should be preserved as raw unparsed strings rather than converted into
  /// Dart [Map] and [List] objects.
  const ToonDecoder({this.parseNested = true});

  /// Whether to recursively parse nested map and list column strings.
  final bool parseNested;

  /// Decodes a complete TOON string source into a [ToonDocument].
  ///
  /// Throws a [FormatException] if the source does not contain a valid
  /// TOON preamble schema or if row column counts violate schema invariance.
  ToonDocument decode(final String source) {
    if (source.isEmpty) {
      throw const FormatException('Cannot decode empty TOON source.');
    }

    final schema = ToonSchema.parse(source);
    if (schema == null) {
      throw const FormatException(
        'No valid TOON preamble schema found in source.',
      );
    }

    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    final records = <ToonRecord>[];
    var inBody = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (!inBody) {
        if (trimmed.endsWith('}:') ||
            (trimmed.contains('[]{') && trimmed.endsWith(':'))) {
          inBody = true;
        }
        continue;
      }

      if (trimmed.isEmpty) {
        continue;
      }

      records.add(decodeRow(line, schema));
    }

    return ToonDocument(schema: schema, records: records);
  }

  /// Decodes a UTF-8 byte buffer into a [ToonDocument].
  ToonDocument decodeBytes(final Uint8List bytes) {
    final str = convert.utf8.decode(bytes, allowMalformed: true);
    return decode(str);
  }

  /// Parses a single data row against a known [ToonSchema].
  ///
  /// Tokenizes the delimited columns, decodes quotes and escape sequences,
  /// maps absent or `\N` values to `null`, and recursively unpacks nested
  /// objects when [parseNested] is `true`.
  ToonRecord decodeRow(final String line, final ToonSchema schema) {
    final rawTokens = _tokenizeRow(line, schema.delimiter);
    final fields = <String, Object?>{};

    for (var i = 0; i < schema.columns.length; i++) {
      final col = schema.columns[i];
      if (i < rawTokens.length) {
        final token = rawTokens[i];
        fields[col] = _parseFieldValue(token, schema.dialect);
      } else {
        fields[col] = null;
      }
    }

    return ToonRecord(fields: fields, schema: schema);
  }

  /// Decodes an asynchronous stream of TOON lines in $O(1)$ memory.
  ///
  /// If [schema] is omitted, the preamble is automatically parsed from the
  /// initial stream lines before data records are emitted.
  Stream<ToonRecord> decodeStream(
    final Stream<String> lines, {
    final ToonSchema? schema,
  }) async* {
    ToonSchema? activeSchema = schema;
    final preambleLines = <String>[];
    var inBody = schema != null;

    await for (final line in lines) {
      final trimmed = line.trim();
      if (!inBody) {
        preambleLines.add(line);
        if (trimmed.endsWith('}:') ||
            (trimmed.contains('[]{') && trimmed.endsWith(':'))) {
          activeSchema = ToonSchema.parse(preambleLines.join('\n'));
          if (activeSchema == null) {
            throw const FormatException(
              'Failed to parse preamble from TOON line stream.',
            );
          }
          inBody = true;
        }
        continue;
      }

      if (trimmed.isEmpty) {
        continue;
      }

      yield decodeRow(line, activeSchema!);
    }
  }

  List<_Token> _tokenizeRow(final String line, final String delimiter) {
    final tokens = <_Token>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var wasQuoted = false;
    var i = 0;

    while (i < line.length) {
      if (!inQuotes && line.startsWith(delimiter, i)) {
        tokens.add(_Token(buffer.toString(), wasQuoted: wasQuoted));
        buffer.clear();
        wasQuoted = false;
        i += delimiter.length;
        continue;
      }

      final char = line[i];

      if (char == '"') {
        if (!inQuotes) {
          inQuotes = true;
          wasQuoted = true;
        } else {
          // Check for trailing escaped quote or end of quote
          inQuotes = false;
        }
        i++;
        continue;
      }

      if (char == r'\' && inQuotes && i + 1 < line.length) {
        final next = line[i + 1];
        if (next == '"') {
          buffer.write('"');
          i += 2;
          continue;
        } else if (next == r'\') {
          buffer.write(r'\');
          i += 2;
          continue;
        } else if (next == 'n') {
          buffer.write('\n');
          i += 2;
          continue;
        } else if (next == 'r') {
          buffer.write('\r');
          i += 2;
          continue;
        } else if (next == 't') {
          buffer.write('\t');
          i += 2;
          continue;
        }
      }

      buffer.write(char);
      i++;
    }

    tokens.add(_Token(buffer.toString(), wasQuoted: wasQuoted));
    return tokens;
  }

  Object? _parseFieldValue(final _Token token, final ToonDialect dialect) {
    if (!token.wasQuoted) {
      if (token.value == r'\N') {
        return null;
      }
      if (token.value.isEmpty) {
        return null;
      }
    }

    final raw = token.value;
    if (parseNested) {
      if (raw.startsWith('{') && raw.endsWith('}')) {
        return _parseNestedMap(raw);
      }
      if (raw.startsWith('[') && raw.endsWith(']')) {
        return _parseNestedList(raw);
      }
    }

    return raw;
  }

  Map<String, Object?> _parseNestedMap(final String raw) {
    final inner = raw.substring(1, raw.length - 1).trim();
    if (inner.isEmpty) {
      return {};
    }

    final entries = _splitRespectingQuotes(inner, ',');
    final map = <String, Object?>{};

    for (final entry in entries) {
      final kv = _splitRespectingQuotes(entry, ':', limit: 2);
      if (kv.isNotEmpty) {
        final key = _stripOptionalQuotes(kv[0].trim());
        final valStr = kv.length > 1 ? kv[1].trim() : '';
        map[key] = _parseScalarOrNested(valStr);
      }
    }

    return map;
  }

  List<Object?> _parseNestedList(final String raw) {
    final inner = raw.substring(1, raw.length - 1).trim();
    if (inner.isEmpty) {
      return [];
    }

    final items = _splitRespectingQuotes(inner, ',');
    return items
        .map((final item) => _parseScalarOrNested(item.trim()))
        .toList();
  }

  Object? _parseScalarOrNested(final String raw) {
    if (raw.isEmpty) {
      return '';
    }
    if (raw == r'\N' || raw == 'null') {
      return null;
    }
    if (raw.startsWith('"') && raw.endsWith('"') && raw.length >= 2) {
      return _unescapeString(raw.substring(1, raw.length - 1));
    }
    if (raw.startsWith('{') && raw.endsWith('}')) {
      return _parseNestedMap(raw);
    }
    if (raw.startsWith('[') && raw.endsWith(']')) {
      return _parseNestedList(raw);
    }
    if (raw == 'true') {
      return true;
    }
    if (raw == 'false') {
      return false;
    }

    final intVal = int.tryParse(raw);
    if (intVal != null) {
      return intVal;
    }

    final doubleVal = double.tryParse(raw);
    if (doubleVal != null && raw.contains('.')) {
      return doubleVal;
    }

    return raw;
  }

  static List<String> _splitRespectingQuotes(
    final String input,
    final String delimiter, {
    final int? limit,
  }) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var depthBraces = 0;
    var depthBrackets = 0;

    for (var i = 0; i < input.length; i++) {
      if (limit != null && parts.length == limit - 1) {
        buffer.write(input.substring(i));
        break;
      }

      final char = input[i];

      if (char == '"' && (i == 0 || input[i - 1] != r'\')) {
        inQuotes = !inQuotes;
        buffer.write(char);
        continue;
      }

      if (!inQuotes) {
        if (char == '{') {
          depthBraces++;
        } else if (char == '}') {
          depthBraces--;
        } else if (char == '[') {
          depthBrackets++;
        } else if (char == ']') {
          depthBrackets--;
        }

        if (depthBraces == 0 &&
            depthBrackets == 0 &&
            input.startsWith(delimiter, i)) {
          parts.add(buffer.toString());
          buffer.clear();
          i += delimiter.length - 1;
          continue;
        }
      }

      buffer.write(char);
    }

    parts.add(buffer.toString());
    return parts;
  }

  static String _stripOptionalQuotes(final String value) {
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      return _unescapeString(value.substring(1, value.length - 1));
    }
    return value;
  }

  static String _unescapeString(final String s) => s
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', r'\')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\t', '\t');
}

final class _Token {
  const _Token(this.value, {required this.wasQuoted});
  final String value;
  final bool wasQuoted;
}
