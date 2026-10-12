library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/context/io/io_stub.dart'
    if (dart.library.io) '../../core/context/io/io_native.dart' as io;
import '../../core/utils/utils.dart';
import '../../logger/logger.dart';
import '../document/document.dart';
import '../encoder/encoder.dart';
import '../engine/engine.dart';

part 'console_sink.dart';
part 'encoding_sink.dart';
part 'memory_sink.dart';
part 'multi_sink.dart';
part 'print_sink.dart';

/// Abstract base class for outputting logs to a destination.
///
/// Sinks define the final destination of log data, such as the system console,
/// a local file, or a remote network endpoint.
abstract base class LogSink<T> {
  /// Creates a [LogSink].
  ///
  /// If [enabled] is `false`, the [output] method
  /// should not perform any action.
  const LogSink({
    this.enabled = true,
  });

  /// Whether this sink is currently active.
  final bool enabled;

  /// Outputs the [data] to the destination.
  ///
  /// The [entry] is the original log entry that produced this data.
  ///
  /// The [level] indicates the severity of the log entry that produced this
  /// data, which can be used by the sink for destination-specific logic (e.g.,
  /// using different output streams for errors).
  Future<void> output(
    final T data,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  );

  /// Performs cleanup, such as closing file handles or network connections.
  ///
  /// This should be called when the sink is no longer needed.
  Future<void> dispose() async {}
}
