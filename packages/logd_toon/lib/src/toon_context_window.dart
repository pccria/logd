import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'toon_schema.dart';
import 'toon_token_estimator.dart';

/// The result of a sliding-window truncation performed by [ToonContextWindow].
///
/// Contains the preamble-preserved TOON string snippet, row statistics, and
/// the estimated token count of the resulting window.
@immutable
final class ToonWindowSlice {
  /// Creates a [ToonWindowSlice].
  const ToonWindowSlice({
    required this.content,
    required this.schema,
    required this.includedRows,
    required this.droppedRows,
    required this.estimatedTokens,
  });

  /// The formatted TOON content containing the schema preamble and sliced rows.
  final String content;

  /// The schema governing the columns of this slice.
  final ToonSchema schema;

  /// The number of recent log data rows retained in this window.
  final int includedRows;

  /// The number of older historical log data rows dropped to satisfy budget limits.
  final int droppedRows;

  /// The estimated token count of [content].
  final int estimatedTokens;

  /// Whether any historical rows were dropped to satisfy budget limits.
  bool get isTruncated => droppedRows > 0;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ToonWindowSlice &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          schema == other.schema &&
          includedRows == other.includedRows &&
          droppedRows == other.droppedRows &&
          estimatedTokens == other.estimatedTokens;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    content,
    schema,
    includedRows,
    droppedRows,
    estimatedTokens,
  );

  @override
  String toString() =>
      'ToonWindowSlice(included: $includedRows, dropped: $droppedRows, tokens: $estimatedTokens)';
}

/// A token-aware sliding-window tail slicer for Large Language Model (LLM) prompts.
///
/// Truncates voluminous TOON logs to fit within strict prompt token budgets while
/// strictly guaranteeing that the column schema preamble is preserved at line 1.
@immutable
final class ToonContextWindow {
  /// Const constructor for [ToonContextWindow].
  const ToonContextWindow();

  /// Slices a TOON string from the tail (newest rows first) up to [maxTokens] or [maxRows].
  ///
  /// Guarantees that the preamble header remains on line 1 so LLMs and parsers
  /// retain column semantics regardless of how many historical rows are dropped.
  ///
  /// If rows are dropped, an optional [truncationIndicator] notice is inserted
  /// immediately beneath the preamble header.
  static ToonWindowSlice slice(
    final String toonSource, {
    final int? maxTokens,
    final int? maxRows,
    final String? truncationIndicator =
        '... [earlier rows truncated for context budget] ...',
  }) {
    if (toonSource.isEmpty) {
      throw const FormatException('Cannot slice empty TOON source.');
    }

    final schema = ToonSchema.parse(toonSource);
    if (schema == null) {
      throw const FormatException('No valid TOON schema found in source.');
    }

    final normalized = toonSource
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    final dataRows = <String>[];
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
      if (trimmed.isNotEmpty) {
        dataRows.add(line);
      }
    }

    final preamble = schema.toPreamble();
    final preambleTokens = ToonTokenEstimator.estimateTokens(preamble);

    final indicator = truncationIndicator ?? '';
    final indicatorTokens = indicator.isNotEmpty
        ? ToonTokenEstimator.estimateTokens(indicator)
        : 0;

    final effectiveTokenCeiling = maxTokens != null
        ? (maxTokens - preambleTokens - indicatorTokens)
        : null;

    final keptRows = <String>[];
    var currentTokenTally = 0;

    // Walk backwards from newest rows to oldest
    for (var i = dataRows.length - 1; i >= 0; i--) {
      if (maxRows != null && keptRows.length >= maxRows) {
        break;
      }

      final row = dataRows[i];
      final rowTokens =
          ToonTokenEstimator.estimateTokens(row) + 1; // +1 for newline

      if (effectiveTokenCeiling != null &&
          (currentTokenTally + rowTokens) > effectiveTokenCeiling) {
        break;
      }

      keptRows.add(row);
      currentTokenTally += rowTokens;
    }

    final includedRows = keptRows.length;
    final droppedRows = dataRows.length - includedRows;

    final buffer = StringBuffer()..write(preamble);

    if (droppedRows > 0 && indicator.isNotEmpty) {
      buffer.writeln(indicator);
    }

    for (var i = keptRows.length - 1; i >= 0; i--) {
      buffer.writeln(keptRows[i]);
    }

    final content = buffer.toString().trimRight();
    final totalTokens = ToonTokenEstimator.estimateTokens(content);

    return ToonWindowSlice(
      content: content,
      schema: schema,
      includedRows: includedRows,
      droppedRows: droppedRows,
      estimatedTokens: totalTokens,
    );
  }

  /// Slices a TOON byte buffer from the tail up to [maxTokens] or [maxRows].
  static ToonWindowSlice sliceBytes(
    final Uint8List bytes, {
    final int? maxTokens,
    final int? maxRows,
    final String? truncationIndicator =
        '... [earlier rows truncated for context budget] ...',
  }) {
    final str = convert.utf8.decode(bytes, allowMalformed: true);
    return slice(
      str,
      maxTokens: maxTokens,
      maxRows: maxRows,
      truncationIndicator: truncationIndicator,
    );
  }
}
