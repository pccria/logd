library;

import 'dart:async';

import '../handler.dart';

/// A [Handler] that directly processes logs synchronously on the main thread
/// under web/browser runtimes where standard isolates are unsupported.
///
/// ### Platform Architecture & Web Safety
/// Under browser/JS runtimes where Dart isolates are unsupported,
/// [AsyncHandler] acts as a transparent, synchronous fall-through to the base
/// [Handler] pipeline execution, running directly on the main event loop.
///
/// ### Lifecycle Management
/// Calling [dispose] on this stub disposes of the underlying [sink] cleanly.
base class AsyncHandler extends Handler {
  /// Creates an [AsyncHandler] that defaults to main-thread processing
  /// under web platforms.
  ///
  /// ### Platform behavior: Web
  /// Under web/browser runtimes where Dart isolates are unsupported,
  /// [AsyncHandler] acts as a transparent, synchronous fall-through to the base
  /// [Handler] pipeline execution, running directly on the main event loop.
  ///
  /// - [formatter]: The formatter used to translate logs into semantic
  ///   documents.
  /// - [sink]: The final output sink.
  /// - [filters]: Optional filters.
  /// - [decorators]: Optional decorators for document layout enrichment.
  /// - [engine]: The execution engine to run (defaults to [StandardEngine]).
  /// - [timeout]: Optional timeout boundary.
  /// - [maxQueueSize]: Maximum pending entries allowed in queue (defaults to
  ///   10,000).
  const AsyncHandler({
    required super.formatter,
    required super.sink,
    super.filters = const [],
    super.decorators = const [],
    super.engine = const StandardEngine(),
    super.timeout,
    this.maxQueueSize = 10000,
  });

  /// Maximum pending entries allowed in queue before drops occur.
  final int maxQueueSize;

  /// A future that completes immediately on Web as no background isolate
  /// is started.
  Future<void> get ready => Future<void>.value();

  /// Disposes of the handler resources by disposing the underlying sink.
  @override
  Future<void> dispose() async {
    await sink.dispose();
    await super.dispose();
  }

  @override
  bool operator ==(final Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}
