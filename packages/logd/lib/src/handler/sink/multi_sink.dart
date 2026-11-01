part of 'sink.dart';

/// A [LogSink] that broadcasts logs to multiple child [LogSink]s.
///
/// MultiSink allows you to easily output logs to several destinations at once
/// (e.g., both the console and a file). It ensures robustness by catching and
/// reporting failures from individual child sinks via the `InternalLogger`.
///
/// **Constraints**: Recursive `MultiSink` usage
/// (a `MultiSink` containing another`MultiSink`) is not allowed
/// to prevent potential infinite loops or excessive overhead.
@immutable
base class MultiSink extends LogSink<LogDocument> {
  /// Creates a [MultiSink] with the provided list of [sinks].
  ///
  /// Throws an [ArgumentError] if the list is empty or contains another
  /// [MultiSink].
  MultiSink(this.sinks, {super.enabled}) {
    if (sinks.isEmpty) {
      throw ArgumentError('MultiSink must have at least one sink.');
    }
    if (sinks.any((final sink) => sink is MultiSink)) {
      throw ArgumentError(
        'Recursive MultiSink is not allowed.',
      );
    }
  }

  /// The list of child sinks to which logs is broadcast.
  final List<LogSink<LogDocument>> sinks;

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    if (!enabled) {
      return;
    }

    if (document.nodes.isEmpty) {
      return;
    }

    final activeSinks = sinks.where((final sink) => sink.enabled).toList();
    if (activeSinks.isEmpty) {
      return;
    }

    final errors = <Object>[];
    await Future.wait(
      activeSinks.map(
        (final sink) async {
          try {
            await sink.output(document, entry, level, factory);
          } catch (e, s) {
            errors.add(e);
            InternalLogger.log(
              LogLevel.error,
              'MultiSink child failure: ${sink.runtimeType}',
              error: e,
              stackTrace: s,
            );
          }
        },
      ),
    );

    if (errors.length == activeSinks.length) {
      final firstError = errors.first;
      if (firstError is Error) {
        throw firstError;
      }
      if (firstError is Exception) {
        throw firstError;
      }
      throw Exception(firstError.toString());
    }
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is MultiSink &&
          runtimeType == other.runtimeType &&
          listEquals(sinks, other.sinks) &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(Object.hashAll(sinks), enabled);

  @override
  Future<void> dispose() async {
    await Future.wait(sinks.map((final sink) => sink.dispose()));
  }
}
