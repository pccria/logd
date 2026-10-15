import 'dart:async';
import 'dart:collection';
import 'dart:convert' as convert;
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logd/logd.dart';
// ignore: invalid_use_of_internal_member, implementation_imports
import 'package:logd/src/logger/internal_logger.dart';
import 'package:meta/meta.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Defines the behavior when the network buffer reaches its maximum capacity.
enum DropPolicy {
  /// Discard the oldest entries in the buffer to make room for new ones.
  discardOldest,

  /// Discard the incoming entries until the buffer has space.
  discardNewest,

  /// Pause logging until the buffer has space (blocking the application).
  ///
  /// CAUTION: This can lead to performance issues if the network is down.
  @Deprecated(
    'DropPolicy.block is not supported in logd_network and will be removed in v1.0.0.',
  )
  block,
}

/// A base class for network-based sinks that require an internal buffer.
abstract base class NetworkSink extends EncodingSink {
  /// Creates a [NetworkSink].
  ///
  /// - [encoder]: The encoder used to serialize logs (default:
  ///   [PlainTextEncoder]).
  /// - [maxBufferSize]: Max entries to hold in memory (default: 1000).
  /// - [dropPolicy]: Behavior when [maxBufferSize] is reached.
  /// - [enabled]: Whether the sink is active.
  const NetworkSink({
    super.encoder = const AutoTextEncoder(),
    this.maxBufferSize = 1000,
    this.dropPolicy = DropPolicy.discardOldest,
    super.enabled,
  })  : assert(
          dropPolicy != DropPolicy.block,
          'DropPolicy.block is not supported in logd_network. '
          'Use DropPolicy.discardOldest or DropPolicy.discardNewest.',
        ),
        super(delegate: _doNothing);

  static void _doNothing(final Uint8List _) {}

  /// Max entries to hold in memory.
  final int maxBufferSize;

  /// Behavior when [maxBufferSize] is reached.
  final DropPolicy dropPolicy;

  /// Shared [Expando] to store mutable state for sink instances.
  static final Expando<_NetworkState> _states = Expando();

  _NetworkState get _state => _states[this] ??= _createState();

  /// Creates the specialized state for this sink type.
  @protected
  _NetworkState _createState();

  /// Returns `true` if the sink has been disposed.
  bool get isDisposed => _state.isDisposed;

  /// Safely adds a line to the buffer according to the [dropPolicy].
  @protected
  void enqueue(final Uint8List line) {
    final buffer = _state.buffer;
    if (buffer.length >= maxBufferSize) {
      if (dropPolicy == DropPolicy.discardOldest) {
        if (buffer.isNotEmpty) {
          buffer.removeFirst();
        }
        buffer.add(line);
      } else if (dropPolicy == DropPolicy.discardNewest) {
        return;
      } else if (dropPolicy == DropPolicy.block) {
        throw UnsupportedError(
          'DropPolicy.block is not supported in logd v0.8.7. '
          'Use discardOldest or discardNewest.',
        );
      }
    } else {
      buffer.add(line);
    }
  }

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

    // Trigger preamble if needed
    if (strategy == WrappingStrategy.document && !isPreambleWritten) {
      final context = factory.checkoutContext();
      encoder.preamble(context, level, factory, document: document);
      final preamble = context.takeBytes();
      if (preamble.isNotEmpty) {
        enqueue(preamble);
      }
      isPreambleWritten = true;
      factory.release(context);
    }

    final context = factory.checkoutContext();
    encoder.encode(
      entry,
      document,
      level,
      context,
      factory,
      width: preferredWidth,
    );

    final data = context.takeBytes();
    if (data.isNotEmpty) {
      enqueue(data);
    }
    factory.release(context);
  }

  @override
  @mustCallSuper
  Future<void> dispose() async {
    if (strategy == WrappingStrategy.document && isPreambleWritten) {
      const factory = StandardPipelineFactory();
      final context = factory.checkoutContext();
      encoder.postamble(context, LogLevel.info, factory);
      final post = context.takeBytes();
      if (post.isNotEmpty) {
        enqueue(post);
      }
      factory.release(context);
    }
    await super.dispose();
  }

  /// Returns and clears the current buffer.
  @protected
  List<Uint8List> flush() {
    final buffer = _state.buffer;
    final lines = buffer.toList();
    buffer.clear();
    return lines;
  }

  /// Returns `true` if there are logs waiting in the buffer.
  @protected
  bool get hasBufferedLogs => _state.buffer.isNotEmpty;
}

/// Internal state for a [NetworkSink].
class _NetworkState {
  final Queue<Uint8List> buffer = Queue<Uint8List>();
  bool isDisposed = false;
}

/// A [NetworkSink] that transmits logs via HTTP POST.
base class HttpSink extends NetworkSink {
  /// Creates an [HttpSink].
  ///
  /// - [url]: The destination endpoint.
  /// - [encoder]: The encoder used to serialize logs (default:
  ///   [PlainTextEncoder]).
  /// - [headers]: Custom headers to include in the request.
  /// - [batchSize]: Sink when this many logs are accumulated (default: 50).
  /// - [flushInterval]: Sink interval (default: 60s).
  /// - [maxRetries]: Max attempts for a single batch (default: 5).
  /// - [client]: Optional external [http.Client].
  /// - [maxBufferSize]: Max entries to hold in memory.
  /// - [dropPolicy]: Behavior when [maxBufferSize] is reached.
  /// - [enabled]: Whether the sink is active.
  const HttpSink({
    required this.url,
    super.encoder = const AutoTextEncoder(),
    this.headers = const {},
    this.batchSize = 50,
    this.flushInterval = const Duration(seconds: 60),
    this.maxRetries = 5,
    this.client,
    super.maxBufferSize = 1000,
    super.dropPolicy = DropPolicy.discardOldest,
    super.enabled,
    this.onDropped,
  });

  /// Optional callback invoked when a batch of logs is dropped due to
  /// persistent network errors.
  final void Function(List<Uint8List> batch, Object error)? onDropped;

  /// The destination endpoint URL.
  final String url;

  /// Custom headers to include in the request.
  final Map<String, String> headers;

  /// Sink when this many logs are accumulated.
  final int batchSize;

  /// Sink interval.
  final Duration flushInterval;

  /// Max attempts for a single batch.
  final int maxRetries;

  /// Optional external [http.Client].
  final http.Client? client;

  @override
  _NetworkState _createState() => _HttpState();

  _HttpState get _httpState => _state as _HttpState;

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    if (!enabled || isDisposed) {
      return;
    }

    _ensureActive();

    // Use parent's output logic which calls enqueue
    await super.output(document, entry, level, factory);

    if (_state.buffer.length >= batchSize) {
      _triggerFlush();
    }
  }

  void _ensureActive() {
    if (_httpState.timer == null && !isDisposed) {
      _httpState.timer = Timer.periodic(flushInterval, (final _) => _flush());
    }
  }

  /// Triggers an asynchronous flush of the current buffer.
  void _triggerFlush() {
    scheduleMicrotask(_flush);
  }

  Future<void> _flush() async {
    if (!hasBufferedLogs || isDisposed) {
      return;
    }

    final batch = flush();
    await _pushWithRetry(batch);
  }

  Future<void> _pushWithRetry(final List<Uint8List> batch) async {
    final httpClient = client ?? (_httpState.internalClient ??= http.Client());
    final uri = _httpState.uri ??= Uri.parse(url);

    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await httpClient.post(
          uri,
          headers: {'Content-Type': 'application/json', ...headers},
          body: convert.jsonEncode(
            batch.map((final b) => convert.utf8.decode(b)).toList(),
          ),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return;
        }

        throw http.ClientException('HTTP Error ${response.statusCode}', uri);
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          _handleFailure(batch, e);
          return;
        }
        final delay = Duration(milliseconds: pow(2, attempts).toInt() * 100);
        await Future.delayed(delay);
      }
    }
  }

  void _handleFailure(final List<Uint8List> batch, final Object error) {
    // ignore: invalid_use_of_internal_member
    LoggerMetrics.incrementDroppedBatches();
    if (onDropped != null) {
      try {
        onDropped!(batch, error);
      } catch (e, s) {
        // ignore: invalid_use_of_internal_member
        InternalLogger.log(
          LogLevel.error,
          'HttpSink onDropped callback threw an error',
          error: e,
          stackTrace: s,
        );
      }
    }
    // ignore: invalid_use_of_internal_member
    InternalLogger.log(
      LogLevel.error,
      'HttpSink failed to send batch of ${batch.length} logs after '
      '$maxRetries attempts',
      error: error,
    );
  }

  @override
  Future<void> dispose() async {
    _httpState.timer?.cancel();
    await super.dispose();
    await _flush(); // Final drain before marking disposed (includes postamble)
    _httpState.internalClient?.close();
    _state.isDisposed = true;
  }
}

class _HttpState extends _NetworkState {
  Timer? timer;
  http.Client? internalClient;
  Uri? uri;
}

/// A [NetworkSink] that transmits logs via a client WebSocket connection.
///
/// Functions as an outgoing client to stream log frames to a remote WebSocket
/// server. Compatible across all platforms including Web and WASM via
/// `package:web_socket_channel`.
base class SocketSink extends NetworkSink {
  /// Creates a [SocketSink].
  ///
  /// - [url]: The WebSocket server URL.
  /// - [headers]: Optional protocols/headers for the connection.
  /// - [reconnectInterval]: Delay before attempting reconnection
  /// (default: 15s).
  /// - [channel]: Optional external WebSocketChannel.
  /// - [encoder]: The encoder used to serialize logs (default:
  ///   [PlainTextEncoder]).
  /// - [maxBufferSize]: Max entries to hold in memory.
  /// - [dropPolicy]: Behavior when [maxBufferSize] is reached.
  /// - [enabled]: Whether the sink is active.
  const SocketSink({
    required this.url,
    this.headers = const {},
    this.reconnectInterval = const Duration(seconds: 15),
    this.channel,
    super.encoder = const AutoTextEncoder(),
    super.maxBufferSize = 1000,
    super.dropPolicy = DropPolicy.discardOldest,
    super.enabled,
  });

  /// The WebSocket server URL.
  final String url;

  /// Optional protocols/headers for the connection.
  final Map<String, String> headers;

  /// Delay before attempting reconnection.
  final Duration reconnectInterval;

  /// Optional external [WebSocketChannel].
  final WebSocketChannel? channel;

  @override
  _NetworkState _createState() => _SocketState();

  _SocketState get _socketState => _state as _SocketState;

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    if (!enabled || isDisposed) {
      return;
    }

    // Use parent logic to get encoded data and put in buffer
    await super.output(document, entry, level, factory);

    if (_socketState.isConnected) {
      _drainBuffer();
    } else if (!_socketState.isConnecting) {
      unawaited(_connect());
    }
  }

  void _send(final Uint8List line) {
    try {
      _socketState.channel?.sink.add(convert.utf8.decode(line));
    } catch (e) {
      _handleFailure(e);
      _socketState.isConnected = false;
      enqueue(line);
      unawaited(_connect());
    }
  }

  void _drainBuffer() {
    if (!hasBufferedLogs) {
      return;
    }
    final batch = flush();
    for (final line in batch) {
      _send(line);
    }
  }

  Future<void> _connect() async {
    if (_socketState.isConnecting || isDisposed) {
      return;
    }

    _socketState.isConnecting = true;
    try {
      final uri = _socketState.uri ??= Uri.parse(url);
      _socketState.channel = channel ??
          WebSocketChannel.connect(uri, protocols: headers.keys.toList());
      await _socketState.channel?.ready;
      _socketState.isConnected = true;
      _socketState.isConnecting = false;
      _socketState.retryAttempts = 0;

      _drainBuffer();
    } catch (e) {
      _socketState.isConnecting = false;
      _socketState.isConnected = false;
      if (!isDisposed) {
        _socketState.retryAttempts++;
        final factor = pow(2, min(_socketState.retryAttempts, 8)).toInt();
        final backoffMs = min(
          reconnectInterval.inMilliseconds * factor,
          300000,
        );
        final delay = Duration(milliseconds: backoffMs);
        // ignore: invalid_use_of_internal_member
        InternalLogger.log(
          LogLevel.warning,
          'SocketSink reconnection failed. Retrying in '
          '${delay.inSeconds}s (attempt ${_socketState.retryAttempts})',
        );
        _socketState.reconnectTimer = Timer(delay, _connect);
      }
    }
  }

  void _handleFailure(final Object error) {
    // ignore: invalid_use_of_internal_member
    InternalLogger.log(
      LogLevel.error,
      'SocketSink connection error',
      error: error,
    );
  }

  @override
  @mustCallSuper
  Future<void> dispose() async {
    _socketState.reconnectTimer?.cancel();
    _socketState.reconnectTimer = null;
    await super.dispose();
    if (_socketState.isConnected) {
      _drainBuffer();
    }
    _state.isDisposed = true;
    _socketState.isConnected = false;
    await _socketState.channel?.sink.close();
  }
}

class _SocketState extends _NetworkState {
  WebSocketChannel? channel;
  Uri? uri;
  bool isConnected = false;
  bool isConnecting = false;
  int retryAttempts = 0;
  Timer? reconnectTimer;
}
