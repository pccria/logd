import 'package:meta/meta.dart';

import 'package:logd/logd.dart';

/// A [LogSink] that throws under browser/web environments as HTTP servers are
/// unsupported.
@experimental
base class HttpServerSink extends EncodingSink {
  /// Creates an [HttpServerSink] stub that throws [UnsupportedError].
  HttpServerSink({
    this.address = 'localhost',
    this.port = 8080,
    super.encoder = const AutoTextEncoder(),
    final int? lineLength,
    super.enabled = true,
    this.bufferCapacity = 100,
  }) : super(preferredWidth: lineLength ?? 120, delegate: _unsupported) {
    throw UnsupportedError(
      'HttpServerSink is not supported on web platforms. '
      'Please use ConsoleSink, HttpSink, or standard output delegation.',
    );
  }

  /// The local interface address (unsupported on web).
  final String address;

  /// The local port number (unsupported on web).
  final int port;

  /// Maximum number of historical log entries to buffer (unsupported on web).
  final int bufferCapacity;

  /// The actual bound port (unsupported on web).
  int get boundPort => port;

  /// A future that completes when the server is ready (completed immediately
  /// on web stub).
  Future<void> get ready => Future<void>.value();

  static void _unsupported(final dynamic _) {}

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    // No-op on web
  }
}
