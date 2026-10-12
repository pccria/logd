import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:logd/logd.dart';

/// An encoder that serializes [LogDocument]s into Token-Oriented Object
/// Notation (TOON).
///
/// It uses the configuration (delimiter, columns, sortKeys, etc.) stored in the
/// document's metadata to produce headers and delimited rows. It handles
/// recursive formatting for nested Maps and Lists within the TOON rows.
class ToonEncoder implements LogEncoder {
  /// Creates a [ToonEncoder].
  const ToonEncoder();
  @override
  WrappingStrategy get wrappingStrategy => WrappingStrategy.document;

  @override
  void preamble(
    final HandlerContext context,
    final LogLevel level,
    final LogPipelineFactory factory, {
    final LogDocument? document,
  }) {
    if (document == null) {
      return;
    }
    final arrayName = document.metadata['toon_array'] as String? ?? 'logs';
    final delimiter = document.metadata['toon_delimiter'] as String? ?? '\t';
    final columns = document.metadata['toon_columns'] as List<String>?;
    final schema = document.metadata['toon_schema'] as Map<String, ToonType>?;
    final dialect = document.metadata['toon_dialect'] as ToonDialect? ??
        ToonDialect.compact;

    if (columns == null) {
      return;
    }

    if (dialect == ToonDialect.strict) {
      final delimDisplay = delimiter == '\t' ? r'\t' : delimiter;
      context.writeString(
        '-- TOON/1.0 $arrayName\n-- DELIMITER:$delimDisplay QUOTE:" NULL:\\N\n',
      );
    }

    if (schema != null) {
      int maxColLen = 0;
      for (final col in columns) {
        if (col.length > maxColLen) {
          maxColLen = col.length;
        }
      }

      context.writeString('$arrayName[]{\n');
      for (final col in columns) {
        final type = schema[col];
        if (type != null) {
          final padding = ' ' * (maxColLen - col.length);
          context.writeString('  $col$padding : $type;\n');
        }
      }
      context.writeString('}:\n');
    } else {
      final columnStr = columns.join(',');
      context.writeString('$arrayName[]{$columnStr}:\n');
    }
  }

  /// Extracts the TOON preamble (schema header line) from a TOON byte buffer.
  ///
  /// Returns the header string (e.g., `logs[]{timestamp,logger,...}:`) or
  /// `null` if no valid TOON preamble is found.
  ///
  /// Use this when slicing a TOON stream for LLM context injection:
  /// ```dart
  /// final schema = ToonEncoder.extractPreamble(await file.readAsBytes());
  /// final chunk = [schema, ...windowLines].join('\n');
  /// ```
  static String? extractPreamble(final Uint8List bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    final str = convert.utf8.decode(bytes, allowMalformed: true);
    final endMarker = str.indexOf('}:\n');
    if (endMarker != -1) {
      return str.substring(0, endMarker + 3);
    }
    final endMarkerFallback = str.indexOf('}:');
    if (endMarkerFallback != -1) {
      return str.substring(0, endMarkerFallback + 2);
    }
    return null;
  }

  @override
  void postamble(
    final HandlerContext context,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) {}

  @override
  void encode(
    final LogEntry entry,
    final LogDocument document,
    final LogLevel level,
    final HandlerContext context,
    final LogPipelineFactory factory, {
    final int? width,
  }) {
    final delimiter = document.metadata['toon_delimiter'] as String? ?? '\t';
    final columns = document.metadata['toon_columns'] as List<String>?;
    final sortKeys = document.metadata['toon_sort_keys'] as bool? ?? false;
    final maxDepth = document.metadata['toon_max_depth'] as int? ?? 5;
    final dialect = document.metadata['toon_dialect'] as ToonDialect? ??
        ToonDialect.compact;

    final nodes = document.nodes;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is MapNode) {
        if (columns != null) {
          final row = columns.map((final col) {
            final val = node.map[col];
            var serialized = _formatValue(
              val,
              0,
              delimiter: delimiter,
              sortKeys: sortKeys,
              maxDepth: maxDepth,
            );

            if (dialect == ToonDialect.strict && serialized.isEmpty) {
              serialized = r'\N';
            }

            // Optional truncation if width is provided.
            // In TOON, we only truncate if a width is specified, and we
            // do it per-field to maintain row integrity.
            if (width != null && serialized.length > width) {
              serialized = '${serialized.substring(0, width - 3)}...';
            }

            return serialized;
          }).join(delimiter);
          context.writeString(row);
        } else {
          context.writeString(node.map.toString());
        }
      } else {
        context.writeString(node.toString());
      }

      // In TOON, we only add a newline if there's more content.
      // Formatters that split multiline messages will produce multiple nodes.
      if (i < nodes.length - 1) {
        context.addByte(0x0A); // '\n'
      }
    }
  }

  String _formatValue(
    final Object? value,
    final int depth, {
    required final String delimiter,
    required final bool sortKeys,
    required final int maxDepth,
  }) {
    if (value == null) {
      return '';
    }
    if (depth >= maxDepth && (value is Map || value is List)) {
      return '...';
    }

    if (value is Map) {
      final entries = value.entries.toList();
      if (sortKeys) {
        entries.sort(
          (final a, final b) => a.key.toString().compareTo(b.key.toString()),
        );
      }
      final items = entries
          .map(
            (final e) => '${_formatValue(
              e.key,
              depth + 1,
              delimiter: delimiter,
              sortKeys: sortKeys,
              maxDepth: maxDepth,
            )}:'
                '${_formatValue(
              e.value,
              depth + 1,
              delimiter: delimiter,
              sortKeys: sortKeys,
              maxDepth: maxDepth,
            )}',
          )
          .join(',');
      return '{$items}';
    } else if (value is List) {
      final items = value
          .map(
            (final e) => _formatValue(
              e,
              depth + 1,
              delimiter: delimiter,
              sortKeys: sortKeys,
              maxDepth: maxDepth,
            ),
          )
          .join(',');
      return '[$items]';
    }

    return _escape(
      value.toString(),
      delimiter,
    );
  }

  String _escape(final String value, final String delimiter) {
    if (value.isEmpty) {
      return '';
    }
    final hasDelimiter = value.contains(delimiter);
    final hasNewline = value.contains('\n') || value.contains('\r');
    final hasSpecial = value.contains('{') ||
        value.contains('}') ||
        value.contains('[') ||
        value.contains(']') ||
        value.contains(':') ||
        value.contains(',');

    if (!hasDelimiter && !hasNewline && !hasSpecial && !value.contains('"')) {
      return value;
    }

    return '"${value.replaceAll('"', r'\"').replaceAll(
          '\n',
          r'\n',
        ).replaceAll(
          '\r',
          r'\r',
        )}"';
  }
}
