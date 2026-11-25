import 'dart:convert' as convert;

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'markdown_dialect.dart';
import 'markdown_encoder.dart';

/// A [LogFormatter] that renders log entries as compact GitHub-Flavored
/// Markdown (GFM) table rows.
///
/// Emits a single table header via [MarkdownEncoder.preamble] (for example,
/// `| Timestamp | Level | Logger | Message | Context |`) and formats each
/// [LogEntry] as an aligned Markdown table row. Ideal for CI/CD job summaries,
/// PR comments, and compact execution digests.
@immutable
final class MarkdownTableFormatter implements LogFormatter {
  /// Creates a [MarkdownTableFormatter].
  const MarkdownTableFormatter({
    this.metadata = const {LogMetadata.timestamp, LogMetadata.logger},
    this.includeContext = true,
    this.dialect = MarkdownDialect.gfm,
  });

  @override
  final Set<LogMetadata> metadata;

  /// Whether to include a trailing `Context` column for [LogEntry.context].
  final bool includeContext;

  /// The Markdown dialect governing cell line-break and escaping behavior.
  final MarkdownDialect dialect;

  @override
  void format(
    final LogEntry entry,
    final LogDocument document,
    final LogPipelineFactory factory,
  ) {
    final columns = <String>[
      if (metadata.contains(LogMetadata.timestamp)) 'Timestamp',
      'Level',
      if (metadata.contains(LogMetadata.logger)) 'Logger',
      if (metadata.contains(LogMetadata.origin)) 'Origin',
      'Message',
      if (includeContext) 'Context',
    ];

    final messageText = entry.error != null
        ? '${entry.message}\nError: ${entry.error}'
        : entry.message;

    final cells = <String>[
      if (metadata.contains(LogMetadata.timestamp))
        _sanitizeCell(entry.timestamp),
      '${_levelEmoji(entry.level)} ${entry.level.name.toUpperCase()}',
      if (metadata.contains(LogMetadata.logger))
        _sanitizeCell(entry.loggerName),
      if (metadata.contains(LogMetadata.origin)) _sanitizeCell(entry.origin),
      _sanitizeCell(messageText),
      if (includeContext) _formatContextCell(entry.context),
    ];

    document.metadata['markdown_table_columns'] = columns;
    document.metadata['markdown_table_cells'] = cells;
    document.metadata[AutoEncoder.encoderKey] = MarkdownEncoder(
      dialect: dialect,
    );

    final row = TableRowNode(
      children: [
        for (final cell in cells)
          TableCellNode(
            children: [
              MessageNode(segments: [StyledText(cell)]),
            ],
          ),
      ],
    );
    document.writeNode(row);
  }

  String _sanitizeCell(final String raw) {
    final lineBreak = dialect == MarkdownDialect.commonmark ? ' ' : '<br>';
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('|', r'\|')
        .replaceAll('\n', lineBreak)
        .trim();
  }

  String _formatContextCell(final Map<String, Object?>? context) {
    if (context == null || context.isEmpty) {
      return '—';
    }
    try {
      final encoded = convert.jsonEncode(
        context,
        toEncodable: (final v) => v is DateTime
            ? v.toIso8601String()
            : (v is Enum ? v.name : v.toString()),
      );
      return '`${_sanitizeCell(encoded)}`';
    } on Object {
      return '`${_sanitizeCell(context.toString())}`';
    }
  }

  String _levelEmoji(final LogLevel level) => switch (level) {
    LogLevel.trace => '🧬',
    LogLevel.debug => '🔍',
    LogLevel.info => 'ℹ️',
    LogLevel.warning => '⚠️',
    LogLevel.error => '❌',
  };

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is MarkdownTableFormatter &&
          runtimeType == other.runtimeType &&
          includeContext == other.includeContext &&
          dialect == other.dialect &&
          _setEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
    runtimeType,
    includeContext,
    dialect,
    Object.hashAll(metadata),
  );

  static bool _setEquals<T>(final Set<T> a, final Set<T> b) =>
      a.length == b.length && a.containsAll(b);
}
