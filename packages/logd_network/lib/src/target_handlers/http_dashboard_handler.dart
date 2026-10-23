// ignore_for_file: comment_references

library;

import 'package:meta/meta.dart';

import 'package:logd/logd.dart';
import '../sink/http_server_sink.dart';
import '../sink/network_sink.dart';
import 'http_dashboard_isolate_handler.dart';

/// A pre-wired [Handler] that hosts a real-time web dashboard over HTTP/WS.
///
/// Pre-wires [StructuredFormatter] and an [HttpServerSink]
/// binding to [address] and [port].
///
/// ### Platform Support
/// Supported on VM runtimes (Android, iOS, macOS, Windows, Linux).
/// Throws [UnsupportedError] on Web platforms where binding local HTTP servers
/// is not supported. For Web applications, use [HttpSink] or [SocketSink] to
/// ship logs to a remote collector.
@immutable
class HttpDashboardHandler extends Handler {
  /// Creates an [HttpDashboardHandler].
  ///
  /// Throws [UnsupportedError] on Web platforms.
  HttpDashboardHandler({
    final String address = 'localhost',
    final int port = 8080,
    final String? title,
    final int bufferCapacity = 100,
    final int? lineLength,
    final int maxConnections = 32,
    final Set<String> allowedOrigins = const {},
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : super(
          formatter: formatter ?? const StructuredFormatter(),
          sink: HttpServerSink(
            address: address,
            port: port,
            encoder: const AutoTextEncoder(),
            bufferCapacity: bufferCapacity,
            lineLength: lineLength,
            maxConnections: maxConnections,
            allowedOrigins: allowedOrigins,
          ),
          decorators: decorators ?? const [],
        );

  /// The actual bound port of the running dashboard server.
  int get boundPort {
    final currentSink = sink;
    if (currentSink is HttpServerSink) {
      return currentSink.boundPort;
    }
    return 0;
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    await sink.dispose();
  }

  /// Creates an asynchronous [HttpDashboardHandler] offloaded to a background
  /// isolate.
  ///
  /// The [HttpServerSink] is constructed entirely inside the background isolate
  /// from the supplied config. This avoids isolate boundary transfer errors
  /// that arise with active HTTP servers and [Completer] instances.
  ///
  /// Make sure to call [registerLogdNetworkSerializers] in your application
  /// bootstrap phase before using async handlers.
  ///
  /// ### Platform Support
  /// Supported on VM runtimes (Android, iOS, macOS, Windows, Linux).
  /// Throws [UnsupportedError] on Web platforms where background isolates and
  /// local HTTP servers are unsupported.
  static Handler async({
    final String address = 'localhost',
    final int port = 8080,
    final String? title,
    final int bufferCapacity = 100,
    final int? lineLength,
    final int maxConnections = 32,
    final Set<String> allowedOrigins = const {},
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final List<LogFilter> filters = const [],
    final Duration? timeout,
  }) =>
      HttpDashboardIsolateHandler(
        address: address,
        port: port,
        bufferCapacity: bufferCapacity,
        lineLength: lineLength,
        maxConnections: maxConnections,
        allowedOrigins: allowedOrigins,
        formatter: formatter ?? const StructuredFormatter(),
        decorators: decorators ?? const [],
        filters: filters,
        timeout: timeout,
      );
}
