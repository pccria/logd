import 'dart:convert' as convert;

import 'package:meta/meta.dart';

import 'toon_decoder.dart';
import 'toon_record.dart';

/// Performance and token-budget metrics comparing TOON against JSON.
///
/// Captures estimated BPE token counts, payload byte footprints, and the
/// calculated token savings percentage achieved by TOON's schema preamble.
@immutable
final class ToonTokenMetrics {
  /// Creates a [ToonTokenMetrics] snapshot.
  const ToonTokenMetrics({
    required this.toonTokens,
    required this.jsonTokens,
    required this.toonBytes,
    required this.jsonBytes,
    required this.rowCount,
  });

  /// Estimated BPE token count of the TOON representation.
  final int toonTokens;

  /// Estimated BPE token count of the equivalent compact JSON representation.
  final int jsonTokens;

  /// UTF-8 byte length of the TOON representation.
  final int toonBytes;

  /// UTF-8 byte length of the equivalent compact JSON representation.
  final int jsonBytes;

  /// The number of log data rows analyzed.
  final int rowCount;

  /// Absolute number of tokens saved by using TOON instead of JSON.
  int get savedTokens => jsonTokens - toonTokens;

  /// Percentage reduction in token consumption achieved by TOON (`0.0` to `100.0`).
  double get savingsPercent {
    if (jsonTokens <= 0) {
      return 0.0;
    }
    final raw = (savedTokens / jsonTokens) * 100.0;
    return raw > 0.0 ? double.parse(raw.toStringAsFixed(1)) : 0.0;
  }

  /// Absolute byte savings compared to JSON.
  int get savedBytes => jsonBytes - toonBytes;

  /// Serializes into a JSON-safe map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'toonTokens': toonTokens,
    'jsonTokens': jsonTokens,
    'savedTokens': savedTokens,
    'savingsPercent': savingsPercent,
    'toonBytes': toonBytes,
    'jsonBytes': jsonBytes,
    'savedBytes': savedBytes,
    'rowCount': rowCount,
  };

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ToonTokenMetrics &&
          runtimeType == other.runtimeType &&
          toonTokens == other.toonTokens &&
          jsonTokens == other.jsonTokens &&
          toonBytes == other.toonBytes &&
          jsonBytes == other.jsonBytes &&
          rowCount == other.rowCount;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    toonTokens,
    jsonTokens,
    toonBytes,
    jsonBytes,
    rowCount,
  );

  @override
  String toString() =>
      'ToonTokenMetrics(TOON: $toonTokens tokens, JSON: $jsonTokens tokens, saved: $savingsPercent%, rows: $rowCount)';
}

/// A lightweight token budget estimator for Large Language Model (LLM) prompts.
///
/// Provides heuristic BPE token approximations calibrated against standard
/// subword tokenizers (such as `cl100k_base` and Claude tokenizers) with zero
/// external dependencies or dictionary assets.
@immutable
final class ToonTokenEstimator {
  /// Const constructor for [ToonTokenEstimator].
  const ToonTokenEstimator();

  /// Estimates the number of BPE tokens in a given [text] string.
  ///
  /// Uses a subword segmentation heuristic that accounts for word boundaries,
  /// numeric sequences, punctuation tokens, and indentation whitespace.
  static int estimateTokens(final String text) {
    if (text.isEmpty) {
      return 0;
    }

    var tokens = 0;
    var currentLength = 0;
    _CharType? previousType;

    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      final type = _classify(code);

      if (type == _CharType.whitespace) {
        if (previousType != _CharType.whitespace && currentLength > 0) {
          tokens += _tokensForLength(currentLength);
          currentLength = 0;
        }
        tokens++;
        previousType = type;
        continue;
      }

      if (type == _CharType.punctuation) {
        if (currentLength > 0) {
          tokens += _tokensForLength(currentLength);
          currentLength = 0;
        }
        tokens++;
        previousType = type;
        continue;
      }

      if (previousType != null &&
          previousType != type &&
          previousType != _CharType.whitespace) {
        tokens += _tokensForLength(currentLength);
        currentLength = 0;
      }

      currentLength++;
      previousType = type;
    }

    if (currentLength > 0) {
      tokens += _tokensForLength(currentLength);
    }

    return tokens > 0 ? tokens : 1;
  }

  /// Analyzes a raw TOON stream and computes token metrics against equivalent JSON.
  static ToonTokenMetrics analyze(final String toonSource) {
    final decoder = const ToonDecoder();
    final document = decoder.decode(toonSource);
    return analyzeDocument(document, toonSource: toonSource);
  }

  /// Analyzes a parsed [ToonDocument] and computes token metrics against equivalent JSON.
  static ToonTokenMetrics analyzeDocument(
    final ToonDocument document, {
    final String? toonSource,
  }) {
    final effectiveToon =
        toonSource ??
        (StringBuffer()
              ..write(document.schema.toPreamble())
              ..writeAll(
                document.records.map((final r) {
                  return document.schema.columns
                      .map((final col) => r.fields[col]?.toString() ?? '')
                      .join(document.schema.delimiter);
                }),
                '\n',
              ))
            .toString();

    final jsonPayload = document.records.map((final r) => r.toMap()).toList();
    final jsonString = convert.jsonEncode(jsonPayload);

    final toonBytes = convert.utf8.encode(effectiveToon).length;
    final jsonBytes = convert.utf8.encode(jsonString).length;

    final toonTokens = estimateTokens(effectiveToon);
    final jsonTokens = estimateTokens(jsonString);

    return ToonTokenMetrics(
      toonTokens: toonTokens,
      jsonTokens: jsonTokens,
      toonBytes: toonBytes,
      jsonBytes: jsonBytes,
      rowCount: document.records.length,
    );
  }

  static int _tokensForLength(final int length) {
    if (length <= 4) {
      return 1;
    }
    return (length / 3.8).ceil();
  }

  static _CharType _classify(final int code) {
    if (code <= 32) {
      return _CharType.whitespace;
    }
    if ((code >= 48 && code <= 57)) {
      return _CharType.digit;
    }
    if ((code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        code == 95) {
      return _CharType.letter;
    }
    return _CharType.punctuation;
  }
}

enum _CharType { whitespace, letter, digit, punctuation }
