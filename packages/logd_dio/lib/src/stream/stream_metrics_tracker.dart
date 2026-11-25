import 'dart:async';
import 'dart:typed_data';

/// Callback invoked when a tracked HTTP response stream finishes or terminates.
typedef StreamTelemetryCallback =
    void Function(
      int chunkCount,
      int totalBytes,
      Duration elapsed,
      Object? error,
    );

/// Utility for transparent, non-blocking telemetry tracking on HTTP response streams.
///
/// Wraps [Stream<Uint8List>] without buffering chunks in memory, measuring total
/// transferred bytes, chunk count, and throughput for chunked downloads and SSE.
abstract final class StreamMetricsTracker {
  /// Wraps [source] with a streaming listener that forwards chunks downstream immediately.
  static Stream<Uint8List> wrap({
    required final Stream<Uint8List> source,
    required final StreamTelemetryCallback onComplete,
  }) {
    late StreamController<Uint8List> controller;
    StreamSubscription<Uint8List>? subscription;
    final sw = Stopwatch()..start();
    var chunkCount = 0;
    var totalBytes = 0;
    var completed = false;

    void notify(final Object? error) {
      if (completed) return;
      completed = true;
      sw.stop();
      onComplete(chunkCount, totalBytes, sw.elapsed, error);
    }

    controller = StreamController<Uint8List>(
      onListen: () {
        subscription = source.listen(
          (final chunk) {
            chunkCount++;
            totalBytes += chunk.length;
            controller.add(chunk);
          },
          onError: (final Object error, final StackTrace stack) {
            notify(error);
            controller.addError(error, stack);
          },
          onDone: () {
            notify(null);
            controller.close();
          },
          cancelOnError: false,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        notify('Stream cancelled by consumer');
        return subscription?.cancel();
      },
    );

    return controller.stream;
  }
}
