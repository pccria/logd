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

import '../compression/gzip_compressor.dart';

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

/// Defines the operational state of the circuit breaker in [HttpSink].
enum CircuitState {
  /// Normal operation: outgoing requests are dispatched to the active endpoint.
  closed,

  /// Failing fast: outgoing requests are blocked without network I/O during
  /// the recovery window.
  open,

  /// Probing: a single trial request is permitted to test endpoint health.
  halfOpen,
}

const _months = <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// Parses a `Retry-After` HTTP header value into a [Duration].
///
/// Supports:
/// 1. Delay seconds (e.g. `"120"`).
/// 2. HTTP-date in RFC 1123 / RFC 850 / asctime format (e.g. `"Sun, 06 Nov 1994 08:49:37 GMT"`).
///
/// Returns `null` if the header is missing, empty, or unparseable.
Duration? parseRetryAfter(final String? headerValue,
    {final DateTime Function()? clock}) {
  if (headerValue == null) {
    return null;
  }
  final trimmed = headerValue.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  // 1. Try delay in seconds (integer)
  final seconds = int.tryParse(trimmed);
  if (seconds != null) {
    return Duration(seconds: max(0, seconds));
  }

  // 2. Try HTTP-date
  final date = parseHttpDate(trimmed);
  if (date != null) {
    final now = (clock != null ? clock() : DateTime.now()).toUtc();
    final diff = date.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  return null;
}

/// Parses an HTTP-date string (RFC 1123 / RFC 850 / asctime) into a UTC [DateTime].
DateTime? parseHttpDate(final String dateString) {
  final trimmed = dateString.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  // Format 1: RFC 1123 / RFC 7231 (e.g., "Sun, 06 Nov 1994 08:49:37 GMT" or "06 Nov 1994 08:49:37 GMT")
  final rfc1123Regex = RegExp(
    r'^(?:[A-Za-z]{3},\s+)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})(?:\s+GMT)?$',
  );
  var match = rfc1123Regex.firstMatch(trimmed);
  if (match != null) {
    final day = int.parse(match.group(1)!);
    final monthStr = match.group(2)!.toLowerCase();
    final month = _months[monthStr];
    final year = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    if (month != null) {
      return DateTime.utc(year, month, day, hour, minute, second);
    }
  }

  // Format 2: RFC 850 (e.g., "Sunday, 06-Nov-94 08:49:37 GMT")
  final rfc850Regex = RegExp(
    r'^(?:[A-Za-z]+,\s+)?(\d{2})-([A-Za-z]{3})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})(?:\s+GMT)?$',
  );
  match = rfc850Regex.firstMatch(trimmed);
  if (match != null) {
    final day = int.parse(match.group(1)!);
    final monthStr = match.group(2)!.toLowerCase();
    final month = _months[monthStr];
    var year = int.parse(match.group(3)!);
    year += (year < 70) ? 2000 : 1900;
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    if (month != null) {
      return DateTime.utc(year, month, day, hour, minute, second);
    }
  }

  // Format 3: asctime (e.g., "Sun Nov  6 08:49:37 1994")
  final asctimeRegex = RegExp(
    r'^[A-Za-z]{3}\s+([A-Za-z]{3})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})$',
  );
  match = asctimeRegex.firstMatch(trimmed);
  if (match != null) {
    final monthStr = match.group(1)!.toLowerCase();
    final month = _months[monthStr];
    final day = int.parse(match.group(2)!);
    final hour = int.parse(match.group(3)!);
    final minute = int.parse(match.group(4)!);
    final second = int.parse(match.group(5)!);
    final year = int.parse(match.group(6)!);
    if (month != null) {
      return DateTime.utc(year, month, day, hour, minute, second);
    }
  }

  return null;
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

/// A [NetworkSink] that transmits logs via HTTP POST with integrated circuit
/// breaker, failover endpoints, and backpressure rate-limiting support.
base class HttpSink extends NetworkSink {
  /// Creates an [HttpSink].
  ///
  /// - [url]: The destination endpoint URL.
  /// - [failoverUrls]: Optional fallback endpoints to cycle through if [url]
  ///   experiences persistent failures.
  /// - [failureThreshold]: The consecutive failure count required to trip
  ///   the circuit breaker to [CircuitState.open] (default: 5).
  /// - [recoveryTimeout]: The duration the circuit breaker remains in
  ///   [CircuitState.open] before probing recovery in [CircuitState.halfOpen]
  ///   (default: 60s).
  /// - [encoder]: The encoder used to serialize logs (default:
  ///   [PlainTextEncoder]).
  /// - [headers]: Custom headers to include in the request.
  /// - [headersProvider]: Dynamic header provider callback invoked before each
  ///   batch POST (e.g. for OAuth2 refresh tokens or rotating HMAC signatures).
  ///   Results are merged on top of [headers]. Note: this is a transient field
  ///   and is not serialized across isolates.
  /// - [batchSize]: Sink when this many logs are accumulated (default: 50).
  /// - [flushInterval]: Sink interval (default: 60s).
  /// - [compress]: Whether to compress the batch JSON body with GZip before
  ///   transmission, attaching `Content-Encoding: gzip` (default: false).
  ///   On platforms where GZip is unavailable (e.g. Web/WASM), payloads are
  ///   transmitted uncompressed.
  /// - [client]: Optional external [http.Client].
  /// - [maxBufferSize]: Max entries to hold in memory.
  /// - [dropPolicy]: Behavior when [maxBufferSize] is reached.
  /// - [enabled]: Whether the sink is active.
  /// - [onDropped]: Callback invoked when a batch cannot be delivered.
  const HttpSink({
    required this.url,
    this.failoverUrls = const [],
    this.failureThreshold = 5,
    this.recoveryTimeout = const Duration(seconds: 60),
    super.encoder = const AutoTextEncoder(),
    this.headers = const {},
    this.headersProvider,
    this.batchSize = 50,
    this.flushInterval = const Duration(seconds: 60),
    this.maxRetries = 5,
    this.compress = false,
    this.client,
    super.maxBufferSize = 1000,
    super.dropPolicy = DropPolicy.discardOldest,
    super.enabled,
    this.onDropped,
  }) : assert(failureThreshold > 0, 'failureThreshold must be greater than 0');

  /// Optional callback invoked when a batch of logs is dropped due to
  /// persistent network errors.
  final void Function(List<Uint8List> batch, Object error)? onDropped;

  /// The primary destination endpoint URL.
  final String url;

  /// Optional fallback endpoints to cycle through if [url] fails.
  final List<String> failoverUrls;

  /// The consecutive failure count required to trip the circuit breaker.
  final int failureThreshold;

  /// The duration the circuit breaker remains in [CircuitState.open].
  final Duration recoveryTimeout;

  /// Custom headers to include in the request.
  final Map<String, String> headers;

  /// Optional dynamic header provider callback invoked before each batch POST.
  ///
  /// Useful for rotating credentials, HMAC signatures, or refreshing OAuth2
  /// bearer tokens. When provided, this callback is evaluated before each HTTP
  /// transmission attempt and its returned key-value pairs are merged on top
  /// of the static [headers] map.
  ///
  /// **Note**: This callback is transient and is not transferred across isolates
  /// via [registerLogdNetworkSerializers].
  final FutureOr<Map<String, String>> Function()? headersProvider;

  /// Sink when this many logs are accumulated.
  final int batchSize;

  /// Sink interval.
  final Duration flushInterval;

  /// Max attempts for a single batch.
  final int maxRetries;

  /// Whether to compress batch payloads with GZip before sending.
  final bool compress;

  /// Optional external [http.Client].
  final http.Client? client;

  @override
  _NetworkState _createState() => _HttpState();

  _HttpState get _httpState => _state as _HttpState;

  /// The current state of the circuit breaker.
  CircuitState get circuitState => _httpState.circuitState;

  /// The number of consecutive batch failures accumulated on the active endpoint.
  int get consecutiveFailures => _httpState.consecutiveFailures;

  /// The currently active destination endpoint URL.
  String get currentUrl {
    final all = [url, ...failoverUrls];
    final idx = _httpState.currentUrlIndex;
    if (idx >= 0 && idx < all.length) {
      return all[idx];
    }
    return url;
  }

  /// Resets the circuit breaker to [CircuitState.closed] and re-points the
  /// sink to the primary [url].
  void resetCircuit() {
    _httpState.circuitState = CircuitState.closed;
    _httpState.consecutiveFailures = 0;
    _httpState.currentUrlIndex = 0;
    _httpState.lastStateChange = null;
    _httpState.backpressureUntil = null;
  }

  /// Resets failover cycling back to the primary [url].
  void resetFailover() {
    _httpState.currentUrlIndex = 0;
    _httpState.consecutiveFailures = 0;
  }

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
    if (_httpState.isFlushing || !hasBufferedLogs || isDisposed) {
      return;
    }

    _httpState.isFlushing = true;
    final completer = Completer<void>();
    _httpState.activeFlushCompleter = completer;

    try {
      while (hasBufferedLogs && !isDisposed) {
        // 1. Evaluate Circuit Breaker state
        if (_httpState.circuitState == CircuitState.open) {
          final now = DateTime.now();
          final stateChange = _httpState.lastStateChange;
          if (stateChange != null &&
              now.difference(stateChange) >= recoveryTimeout) {
            _httpState.circuitState = CircuitState.halfOpen;
            _httpState.lastStateChange = now;
            _httpState.currentUrlIndex = 0;
          } else {
            // Fail fast: do not attempt network I/O
            break;
          }
        }

        // 2. Evaluate HTTP Backpressure (from Retry-After)
        if (_httpState.backpressureUntil != null) {
          final now = DateTime.now();
          if (now.isBefore(_httpState.backpressureUntil!)) {
            // Backpressure active: pause draining until expiration
            break;
          } else {
            _httpState.backpressureUntil = null;
          }
        }

        final batch = flush();
        if (batch.isEmpty) {
          break;
        }

        final isProbe = _httpState.circuitState == CircuitState.halfOpen;
        final success = await _pushWithRetry(batch);

        if (isProbe) {
          if (success) {
            _httpState.circuitState = CircuitState.closed;
            _httpState.consecutiveFailures = 0;
            _httpState.lastStateChange = DateTime.now();
          } else {
            // Probe failed: trip immediately back to open
            _httpState.circuitState = CircuitState.open;
            _httpState.lastStateChange = DateTime.now();
            break;
          }
        } else if (!success && _httpState.circuitState == CircuitState.open) {
          // Circuit opened as a result of failures, stop draining
          break;
        }
      }
    } finally {
      _httpState.isFlushing = false;
      _httpState.activeFlushCompleter = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<bool> _pushWithRetry(final List<Uint8List> batch) async {
    final allUrls = [url, ...failoverUrls];
    final httpClient = client ?? (_httpState.internalClient ??= http.Client());

    Object? lastError;

    while (_httpState.currentUrlIndex < allUrls.length) {
      final targetUrl = allUrls[_httpState.currentUrlIndex];
      final uri = _httpState.cachedUris.putIfAbsent(
        targetUrl,
        () => Uri.parse(targetUrl),
      );

      int attempts = 0;

      while (attempts < maxRetries) {
        try {
          final resolvedHeaders = <String, String>{
            'Content-Type': 'application/json',
            ...headers,
          };

          if (headersProvider != null) {
            final dynamicHeaders = await headersProvider!();
            resolvedHeaders.addAll(dynamicHeaders);
          }

          final jsonString = convert.jsonEncode(
            batch.map((final b) => convert.utf8.decode(b)).toList(),
          );

          Object body = jsonString;
          if (compress && isGzipSupported) {
            final compressed = gzipCompress(convert.utf8.encode(jsonString));
            if (compressed != null) {
              body = compressed;
              resolvedHeaders['Content-Encoding'] = 'gzip';
            }
          }

          final response = await httpClient.post(
            uri,
            headers: resolvedHeaders,
            body: body,
          );

          if (response.statusCode >= 200 && response.statusCode < 300) {
            _httpState.consecutiveFailures = 0;
            return true;
          }

          // Check for Retry-After backpressure (429 or 503)
          if (response.statusCode == 429 || response.statusCode == 503) {
            final retryHeader = response.headers['retry-after'];
            final delay = parseRetryAfter(retryHeader);
            if (delay != null) {
              _httpState.backpressureUntil = DateTime.now().add(delay);
              if (delay <= const Duration(seconds: 5)) {
                attempts++;
                if (attempts < maxRetries) {
                  await Future.delayed(delay);
                  continue;
                }
              }
            }
          }

          throw http.ClientException('HTTP Error ${response.statusCode}', uri);
        } catch (e) {
          if (isDisposed) {
            return false;
          }
          lastError = e;
          attempts++;
          if (attempts >= maxRetries) {
            break;
          }
          final delay = Duration(milliseconds: pow(2, attempts).toInt() * 100);
          await Future.delayed(delay);
        }
      }

      // Endpoint failed after maxRetries attempts
      _httpState.consecutiveFailures++;

      // Failover if another URL is available
      if (_httpState.currentUrlIndex + 1 < allUrls.length) {
        final previousUrl = targetUrl;
        _httpState.currentUrlIndex++;
        final nextUrl = allUrls[_httpState.currentUrlIndex];
        // ignore: invalid_use_of_internal_member
        InternalLogger.log(
          LogLevel.warning,
          'HttpSink endpoint $previousUrl failed. Failing over to $nextUrl.',
        );
        continue;
      }

      break;
    }

    // All available endpoints failed
    if (_httpState.consecutiveFailures >= failureThreshold) {
      _httpState.circuitState = CircuitState.open;
      _httpState.lastStateChange = DateTime.now();
      // ignore: invalid_use_of_internal_member
      InternalLogger.log(
        LogLevel.error,
        'HttpSink circuit breaker tripped to open after '
        '${_httpState.consecutiveFailures} consecutive failures. '
        'Failing fast for ${recoveryTimeout.inSeconds}s.',
      );
    }

    _handleFailure(batch, lastError ?? StateError('Unknown HTTP error'));
    return false;
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

    // If an active flush is in flight, wait for it to complete cleanly
    if (_httpState.activeFlushCompleter != null) {
      await _httpState.activeFlushCompleter!.future;
    }

    await _flush(); // Final drain before marking disposed (includes postamble)
    _state.isDisposed = true;
    _httpState.internalClient?.close();
  }
}

class _HttpState extends _NetworkState {
  Timer? timer;
  http.Client? internalClient;
  final Map<String, Uri> cachedUris = {};
  bool isFlushing = false;
  Completer<void>? activeFlushCompleter;

  CircuitState circuitState = CircuitState.closed;
  int consecutiveFailures = 0;
  DateTime? lastStateChange;
  DateTime? backpressureUntil;
  int currentUrlIndex = 0;
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
