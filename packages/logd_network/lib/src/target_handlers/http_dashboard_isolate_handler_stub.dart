library;

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

/// A web/browser stub for [HttpDashboardIsolateHandler] where isolates
/// and HTTP servers are unsupported.
@internal
base class HttpDashboardIsolateHandler extends Handler {
  /// Creates an [HttpDashboardIsolateHandler] stub that throws [UnsupportedError].
  HttpDashboardIsolateHandler({
    final String address = 'localhost',
    final int port = 8080,
    final int bufferCapacity = 100,
    final int? lineLength,
    super.formatter = const StructuredFormatter(),
    super.decorators,
    super.filters,
    super.timeout,
  }) : super(
          sink: _NoOpSink(),
          engine: const StandardEngine(),
        ) {
    throw UnsupportedError(
      'HttpDashboardHandler.async is not supported on web platforms. '
      'Please use ConsoleSink, HttpSink, or standard output delegation.',
    );
  }

  /// A future that completes immediately on Web as background isolates are unsupported.
  Future<void> get ready => Future<void>.value();
}

/// A no-op [LogSink] used as a placeholder in [HttpDashboardIsolateHandler]'s
/// [Handler] superclass constructor on web.
base class _NoOpSink extends LogSink<LogDocument> {
  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {}
}
