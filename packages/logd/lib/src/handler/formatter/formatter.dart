library;

import 'dart:convert' as convert;
import 'package:characters/characters.dart';
import 'package:meta/meta.dart';
import '../../core/theme/log_theme.dart';
import '../../core/utils/utils.dart';
import '../../logger/logger.dart';
import '../decorator/decorator.dart';
import '../document/document.dart';
import '../encoder/encoder.dart';
import '../engine/engine.dart';
import '../layout/layout.dart';

part 'plain_formatter.dart';
part 'json_formatter.dart';
part 'structured_formatter.dart';

/// Abstract interface for transforming a [LogEntry] into a semantic
/// [LogDocument].
///
/// Formatters are responsible for the structural representation of a log entry,
/// such as producing a hierarchical data structure or an unadorned structural
/// payload, decoupled from specific serialization.
abstract interface class LogFormatter {
  const LogFormatter({required this.metadata});

  /// Contextual metadata to include in the output.
  final Set<LogMetadata> metadata;

  /// Formats [entry] into the provided [document], using [factory] to check out
  /// new nodes.
  ///
  /// The [document] and all nodes created by the [factory] are pool-managed.
  /// The orchestrator is responsible for releasing the document after the
  /// pipeline completes.
  void format(
    final LogEntry entry,
    final LogDocument document,
    final LogPipelineFactory factory,
  );
}
