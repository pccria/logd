library;

import 'package:meta/meta.dart';
import 'logger.dart';

/// Internal: The actual buffer implementation holding state.
/// This acts as the "Body" which survives the "Handle" (LogBuffer).
class _LogBuffer extends StringBuffer {
  _LogBuffer(this._logger, this.logLevel, {this.maxEntries});

  /// Internal: The logger to sync to.
  Logger _logger;

  /// The level for this buffer's log.
  LogLevel logLevel;

  /// Maximum number of entries allowed before dropping excess data.
  int? maxEntries;

  int _entryCount = 0;
  bool _warnedMaxEntries = false;

  /// Optional error associated with this log.
  Object? error;

  /// Optional stack trace associated with this log.
  StackTrace? stackTrace;

  /// Optional context associated with this log.
  Map<String, dynamic>? context;

  /// Merges key-value pairs into the current context map.
  void addContext(final Map<String, dynamic> other) {
    final current = context;
    if (current == null) {
      context = Map<String, dynamic>.from(other);
    } else {
      context = Map<String, dynamic>.from(current)..addAll(other);
    }
  }

  @override
  void writeln([final Object? obj = '']) {
    if (maxEntries != null && _entryCount >= maxEntries!) {
      if (!_warnedMaxEntries) {
        _warnedMaxEntries = true;
        InternalLogger.log(
          LogLevel.warning,
          'LogBuffer: maxEntries ($maxEntries) reached for logger'
          ' "${_logger.name}". Excess entries dropped.',
        );
      }
      return;
    }
    _entryCount++;
    super.writeln(obj);
  }

  @override
  void writeAll(final Iterable objects, [final String separator = '']) {
    for (final object in objects) {
      writeln(object);
    }
  }

  @override
  void clear() {
    error = null;
    stackTrace = null;
    context = null;
    _entryCount = 0;
    _warnedMaxEntries = false;
    super.clear();
  }

  /// Sinks the buffer and clears it.
  void sink() {
    if (isNotEmpty ||
        error != null ||
        stackTrace != null ||
        (context != null && context!.isNotEmpty)) {
      if (!_logger.isLoggable(logLevel)) {
        LoggerMetrics.incrementDrops();
        clear();
        return;
      }
      _logger
          .logInternal(logLevel, toString(), error, stackTrace, context)
          .catchError(
            (final e) => InternalLogger.log(
              LogLevel.error,
              'Error while logging from buffer.',
              error: e,
              stackTrace: StackTrace.current,
            ),
          );
      clear();
    }
  }
}

/// Efficient buffer for building multi-line log messages before syncing.
///
/// This class acts as a finite "Handle" to an internal buffer.
/// It uses composition to ensure the internal buffer can be tracked by a
/// finalizer without creating circular references that prevent garbage
/// collection.
class LogBuffer implements StringSink {
  LogBuffer._(
    final Logger logger,
    final LogLevel level, {
    final int? maxEntries,
  }) : _buffer = _LogBuffer(logger, level, maxEntries: maxEntries) {
    _finalizer.attach(this, _buffer, detach: this);
  }

  /// Internal: The inner buffer token/body.
  final _LogBuffer _buffer;

  /// Whether this buffer has been released back to the pool.
  bool _released = false;

  /// Maximum number of entries allowed before dropping excess data.
  int? get maxEntries => _released ? null : _buffer.maxEntries;

  /// Maximum number of [LogBuffer] instances held in the LIFO pool.
  ///
  /// Sized to cover typical burst scenarios (e.g., parallel request
  /// handling) without retaining excessive memory. Instances above this
  /// limit are discarded and collected by the GC.
  static const int _maxPoolSize = 32;

  /// Pool of recycled [LogBuffer] instances (LIFO).
  static final List<LogBuffer> _pool = [];

  /// Finalizer for auto-sinking abandoned buffers.
  static final Finalizer<_LogBuffer> _finalizer =
      Finalizer<_LogBuffer>((final buffer) {
    LoggerMetrics.incrementBufferLeaks();
    if (buffer.isNotEmpty ||
        buffer.error != null ||
        buffer.stackTrace != null ||
        (buffer.context != null && buffer.context!.isNotEmpty)) {
      // Log leak warning
      if (buffer._logger.autoSinkBuffer) {
        // Auto-sink the content
        buffer._logger
            .logInternal(
              buffer.logLevel,
              buffer.toString(),
              buffer.error,
              buffer.stackTrace,
              buffer.context,
            )
            .catchError(
              (final e) => InternalLogger.log(
                LogLevel.error,
                'Error while auto-sinking buffer.',
                error: e,
                stackTrace: StackTrace.current,
              ),
            );

        InternalLogger.log(
          LogLevel.warning,
          'LogBuffer leak detected! '
          'Content was automatically logged to prevent data loss. '
          'Logger: "${buffer._logger.name}", Level: ${buffer.logLevel.name}. '
          'Call .sink() explicitly to ensure immediate logging and avoid this'
          ' warning.',
          stackTrace: StackTrace.current,
        );
      } else {
        InternalLogger.log(
          LogLevel.warning,
          'LogBuffer leak detected! '
          'Auto-sink is disabled, so data was LOST. '
          'Logger: "${buffer._logger.name}", Level: ${buffer.logLevel.name}. '
          'Call .sink() explicitly to avoid this warning and ensure data is '
          'logged.',
          stackTrace: StackTrace.current,
        );
      }
    }
  });

  /// Internal: Checks out a [LogBuffer] from the pool, or creates a new one.
  @internal
  static LogBuffer checkout(
    final Logger logger,
    final LogLevel level, {
    final int? maxEntries,
  }) {
    LoggerMetrics.incrementBufferAllocations();
    if (_pool.isNotEmpty) {
      final buffer = _pool.removeLast()
        .._reset(logger, level, maxEntries: maxEntries);
      return buffer;
    }
    return LogBuffer._(logger, level, maxEntries: maxEntries);
  }

  /// Resets this buffer's state for reuse.
  void _reset(
    final Logger logger,
    final LogLevel level, {
    final int? maxEntries,
  }) {
    _released = false;
    _buffer._logger = logger;
    _buffer.logLevel = level;
    _buffer.maxEntries = maxEntries;
    _buffer.clear();
    _finalizer.attach(this, _buffer, detach: this);
  }

  /// Recycles this buffer back to the pool.
  void _recycle() {
    if (_released) {
      return;
    }
    _released = true;
    LoggerMetrics.incrementBufferReleases();
    _finalizer.detach(this);
    _buffer.clear();
    if (_pool.length < _maxPoolSize) {
      _pool.add(this);
    }
  }

  /// Throws a [StateError] if this buffer has already been sunk/released.
  void _checkReleased() {
    if (_released) {
      throw StateError('LogBuffer has already been sunk/released.');
    }
  }

  /// Sets the error object for this log message.
  set error(final Object? value) {
    _checkReleased();
    _buffer.error = value;
  }

  /// Gets the current error object.
  Object? get error {
    if (_released) {
      return null;
    }
    return _buffer.error;
  }

  /// Sets the stack trace for this log message.
  set stackTrace(final StackTrace? value) {
    _checkReleased();
    _buffer.stackTrace = value;
  }

  /// Gets the current stack trace.
  StackTrace? get stackTrace {
    if (_released) {
      return null;
    }
    return _buffer.stackTrace;
  }

  /// Sets the context map for this log message.
  set context(final Map<String, dynamic>? value) {
    _checkReleased();
    _buffer.context = value;
  }

  /// Gets the current context map.
  Map<String, dynamic>? get context {
    if (_released) {
      return null;
    }
    return _buffer.context;
  }

  /// Merges key-value pairs into the current context map.
  void addContext(final Map<String, dynamic> other) {
    _checkReleased();
    _buffer.addContext(other);
  }

  int get length {
    if (_released) {
      return 0;
    }
    return _buffer.length;
  }

  bool get isEmpty {
    if (_released) {
      return true;
    }
    return _buffer.isEmpty;
  }

  bool get isNotEmpty {
    if (_released) {
      return false;
    }
    return _buffer.isNotEmpty;
  }

  @override
  void write(final Object? object) {
    _checkReleased();
    _buffer.write(object);
  }

  @override
  void writeln([final Object? object = '']) {
    _checkReleased();
    _buffer.writeln(object);
  }

  @override
  void writeAll(final Iterable objects, [final String separator = '']) {
    _checkReleased();
    _buffer.writeAll(objects, separator);
  }

  @override
  void writeCharCode(final int charCode) {
    _checkReleased();
    _buffer.writeCharCode(charCode);
  }

  void clear() {
    _checkReleased();
    _buffer.clear();
  }

  @override
  String toString() {
    if (_released) {
      return '';
    }
    return _buffer.toString();
  }

  /// Sinks the buffer and clears it.
  void sink() {
    if (_released) {
      return;
    }
    if (isNotEmpty ||
        error != null ||
        stackTrace != null ||
        (context != null && context!.isNotEmpty)) {
      _buffer.sink();
    }
    _recycle();
  }
}
