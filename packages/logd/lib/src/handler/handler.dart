/// The orchestration layer for the Logd pipeline.
///
/// This library defines the [Handler] and the core models for processing
/// logs. It uses a structured [LogDocument] as the intermediate representation.
///
library;

import 'dart:async';

import 'package:meta/meta.dart';

import '../core/utils/utils.dart';
import '../logger/logger.dart';
import 'decorator/decorator.dart';
import 'document/document.dart';
import 'engine/engine.dart';
import 'filter/filter.dart';
import 'formatter/formatter.dart';
import 'sink/sink.dart';

export 'decorator/decorator.dart';
export 'document/document.dart';
export 'encoder/encoder.dart';
export 'engine/engine.dart';
export 'filter/filter.dart';
export 'formatter/formatter.dart';
export 'layout/layout.dart';
export 'sink/sink.dart';
export 'target_handlers/target_handlers.dart';

/// Composes a [LogFormatter], a [LogSink], and optional filters and decorators.
///
/// The [Handler] is the central orchestration unit in the logging pipeline. It
/// filters incoming [LogEntry]s, transforms them using a [LogFormatter],
/// applies a sequence of [LogDecorator]s, and finally sends the results to a
/// [LogSink].
@immutable
class Handler {
  /// Creates a [Handler].
  const Handler({
    required this.formatter,
    required this.sink,
    this.filters = const [],
    this.decorators = const [],
    this.engine = const StandardEngine(),
    this.timeout,
  });

  /// The [LogFormatter] used to transform an incoming [LogEntry] into a
  /// semantic [LogDocument] (Semantic IR).
  ///
  /// Formatting takes place after all [filters] pass. The formatter maps
  /// raw log fields, timestamps, metadata, and messages into structured
  /// [LogNode]s without performing terminal rendering or physical layout.
  final LogFormatter formatter;

  /// The target destination where formatted and decorated log output is
  /// written.
  ///
  /// The sink represents the final I/O stage of the pipeline (such as
  /// stdout, stderr, a file handle, or a network endpoint). It receives
  /// processed output once the log entry has passed filtering, formatting,
  /// decoration, and physical encoding.
  final LogSink sink;

  /// A list of [LogFilter]s evaluated sequentially before formatting
  /// or decorating.
  ///
  /// Filters act as a logical **AND** conjunction chain. Every filter
  /// in this list must pass (i.e., [LogFilter.shouldLog] returns `true`)
  /// for the [LogEntry] to be processed by this [Handler]. If any filter
  /// returns `false`, processing is immediately short-circuited and the
  /// log entry is discarded.
  ///
  /// Common built-in filters include [LevelFilter], [RegexFilter],
  /// and [ContextFilter].
  final List<LogFilter> filters;

  /// The execution strategy and scheduling model for the log pipeline.
  ///
  /// The engine orchestrates how [formatter], [decorators], and [sink]
  /// are invoked for each entry. It determines whether processing occurs
  /// synchronously on the calling thread or asynchronously (e.g., via
  /// a background buffer or isolate boundary). Defaults to [StandardEngine].
  final LogEngine engine;

  /// A list of [LogDecorator]s applied sequentially to the intermediate
  /// [LogDocument].
  ///
  /// Decorators operate strictly on the semantic IR tree after formatting
  /// and before physical layout encoding. They enrich or transform the
  /// document (e.g., adding visual borders, headers, or contextual tags)
  /// in the exact order specified.
  final List<LogDecorator> decorators;

  /// The maximum duration permitted for processing a single log entry.
  ///
  /// If specified, caps the time spent executing [LogEngine.execute] to
  /// prevent slow I/O or stalled sinks from hanging the caller. If null,
  /// execution runs to completion without a timeout constraint. Must not
  /// be negative.
  final Duration? timeout;

  /// Process the entry: filter, format, decorate, output.
  @internal
  Future<void> log(final LogEntry entry) async {
    assert(
      timeout == null || !timeout!.isNegative,
      'timeout must not be negative',
    );

    if (filters.any((final filter) => !filter.shouldLog(entry))) {
      return;
    }

    if (timeout != null) {
      await engine
          .execute(entry, formatter, decorators, sink)
          .timeout(timeout!);
    } else {
      await engine.execute(entry, formatter, decorators, sink);
    }
  }

  /// Flushes any pending log operations in this handler's pipeline and sink.
  @mustCallSuper
  Future<void> flush() async {
    await sink.flush();
  }

  /// Disposes of any resources held by this handler.
  ///
  /// Subclasses that manage stateful resources (such as background isolates
  /// or file handles) should override this method to clean up resources.
  @mustCallSuper
  Future<void> dispose() async {}

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is Handler &&
          runtimeType == other.runtimeType &&
          formatter == other.formatter &&
          sink == other.sink &&
          engine == other.engine &&
          timeout == other.timeout &&
          listEquals(filters, other.filters) &&
          listEquals(decorators, other.decorators);

  @override
  int get hashCode =>
      formatter.hashCode ^
      sink.hashCode ^
      engine.hashCode ^
      timeout.hashCode ^
      Object.hashAll(filters) ^
      Object.hashAll(decorators);
}
