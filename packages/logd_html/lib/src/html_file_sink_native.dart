import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:logd/logd.dart';
// ignore: implementation_imports
import 'package:logd/src/logger/internal_logger.dart';

import 'html_encoder.dart';
import 'html_view.dart';

/// Supported open modes for HTML log files.
enum HtmlFileMode {
  /// Always truncates the target file, creating a fresh HTML document.
  overwrite,

  /// Appends to an existing HTML document if present, safely stripping closing
  /// tags and inserting a session divider, or creates a new document if absent.
  appendSession,

  /// Emits an embeddable HTML fragment without document shells.
  fragment,
}

/// A specialized [LogSink] that guarantees single HTML document integrity on
/// disk.
///
/// Features:
/// - **Smart Postamble Rewind**: Safely resumes existing HTML files across
///   restarts by stripping previous closing tags and inserting a session
///   divider.
/// - **Multi-Logger Coordination**: Multiple loggers targeting the same path
///   share a single file coordinator, preventing duplicate `<!DOCTYPE html>`
///   and footers.
/// - **Rotation Resilience**: Cleanly closes old files before rotation and
///   opens new files with the active view preamble.
base class HtmlFileSink extends LogSink<LogDocument> {
  /// Creates an [HtmlFileSink].
  HtmlFileSink(
    this.path, {
    this.encoder = const HtmlEncoder(),
    this.mode = HtmlFileMode.appendSession,
    this.fileRotation,
    this.lineLength = 120,
    this.sessionLabel,
    super.enabled,
  }) {
    _coordinator.refCount++;
  }

  /// The path to the output file.
  final String path;

  /// The HTML encoder used.
  final HtmlEncoder encoder;

  /// The file open mode.
  final HtmlFileMode mode;

  /// The rotation policy applied to this sink.
  final FileRotation? fileRotation;

  /// The preferred line length.
  final int? lineLength;

  /// An optional custom label displayed in the session resumption delimiter.
  ///
  /// If `null`, defaults to `'Run PID: ${io.pid}'`.
  final String? sessionLabel;

  bool _isDisposed = false;

  String get _canonicalPath => io.File(path).absolute.path;

  _SharedHtmlFileCoordinator get _coordinator => _coordinators.putIfAbsent(
    _canonicalPath,
    () => _SharedHtmlFileCoordinator(
      path: path,
      mode: mode,
      fileRotation: fileRotation,
      encoder: encoder,
      view: encoder.effectiveView,
      sessionLabel: sessionLabel,
    ),
  );

  static final Map<String, _SharedHtmlFileCoordinator> _coordinators = {};

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

    final effectiveEncoder =
        (document.metadata[AutoEncoder.encoderKey] as HtmlEncoder?) ?? encoder;

    final context = factory.checkoutContext();
    try {
      effectiveEncoder.encode(
        entry,
        document,
        level,
        context,
        factory,
        width: lineLength,
      );

      if (context.length > 0) {
        context.addByte(0x0A);
      }

      final data = context.takeBytes();
      if (data.isNotEmpty) {
        await _coordinator.write(data, level, factory, document: document);
      }
    } finally {
      factory.release(context);
    }
  }

  @override
  Future<void> flush() => _coordinator.flush();

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await flush();
    const factory = StandardPipelineFactory();
    final c = _coordinator;
    await c.release(factory);
    if (c.refCount <= 0) {
      _coordinators.remove(_canonicalPath);
    }
    await super.dispose();
  }
}

class _SharedHtmlFileCoordinator {
  _SharedHtmlFileCoordinator({
    required this.path,
    required this.mode,
    required this.fileRotation,
    required this.encoder,
    required this.view,
    this.sessionLabel,
  });

  final String path;
  final HtmlFileMode mode;
  final FileRotation? fileRotation;
  final HtmlEncoder encoder;
  final HtmlView view;
  final String? sessionLabel;

  int refCount = 0;
  bool isPreambleWritten = false;
  bool isPostambleWritten = false;
  Future<void> _lock = Future<void>.value();

  Future<void> write(
    final Uint8List data,
    final LogLevel level,
    final LogPipelineFactory factory, {
    final LogDocument? document,
  }) {
    final completer = Completer<void>();
    final prevLock = _lock;
    _lock = completer.future;

    return prevLock.then((_) async {
      try {
        final file = io.File(path);
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }

        // Check file rotation
        if (fileRotation != null &&
            file.existsSync() &&
            await fileRotation!.checkNeedsRotation(path, data)) {
          try {
            if (isPreambleWritten && view.isStandalone) {
              final postContext = factory.checkoutContext();
              try {
                encoder.postamble(
                  postContext,
                  LogLevel.info,
                  factory,
                  document: document,
                );
                final postBytes = postContext.takeBytes();
                if (postBytes.isNotEmpty) {
                  final raf = file.openSync(mode: io.FileMode.append);
                  try {
                    raf.writeFromSync(postBytes);
                  } finally {
                    raf.closeSync();
                  }
                }
              } finally {
                factory.release(postContext);
              }
            }

            await fileRotation!.rotate(path);
            isPreambleWritten = false;
          } catch (rotationError, rotationStack) {
            // ignore: invalid_use_of_internal_member
            InternalLogger.log(
              LogLevel.warning,
              'HTML file rotation failed, continuing with write to '
              'original file',
              error: rotationError,
              stackTrace: rotationStack,
            );
          }
        }

        // Initialize preamble / rewind if needed
        if (!isPreambleWritten) {
          _initializeFile(file, factory, level, document);
          isPreambleWritten = true;
        }

        // Append log entry
        final raf = file.openSync(mode: io.FileMode.append);
        try {
          raf.writeFromSync(data);
        } finally {
          raf.closeSync();
        }
      } finally {
        completer.complete();
      }
    });
  }

  void _initializeFile(
    final io.File file,
    final LogPipelineFactory factory,
    final LogLevel level,
    final LogDocument? document,
  ) {
    isPostambleWritten = false;
    final fileExists = file.existsSync();
    final fileLength = fileExists ? file.lengthSync() : 0;

    if (mode == HtmlFileMode.fragment) {
      return;
    }

    if (mode == HtmlFileMode.overwrite || !fileExists || fileLength == 0) {
      if (fileExists && fileLength > 0) {
        file.writeAsBytesSync(const []);
      }
      final preContext = factory.checkoutContext();
      try {
        encoder.preamble(preContext, level, factory, document: document);
        final preBytes = preContext.takeBytes();
        if (preBytes.isNotEmpty) {
          file.writeAsBytesSync(preBytes, mode: io.FileMode.append);
        }
      } finally {
        factory.release(preContext);
      }
      return;
    }

    if (mode == HtmlFileMode.appendSession) {
      final raf = file.openSync(mode: io.FileMode.append);
      try {
        // Inspect up to the last 64 KB where document postamble and closing
        // tags reside.
        final readLen = fileLength > 65536 ? 65536 : fileLength;
        final seekStart = fileLength - readLen;
        raf.setPositionSync(seekStart);
        final tailBytes = raf.readSync(readLen);
        final tailStr = String.fromCharCodes(tailBytes);

        final markerIdx = tailStr.lastIndexOf(HtmlEncoder.documentCloseMarker);
        if (markerIdx != -1) {
          final truncateOffset = seekStart + markerIdx;
          raf
            ..truncateSync(truncateOffset)
            ..setPositionSync(truncateOffset);
        } else {
          final closeIdx = tailStr.lastIndexOf('</body>');
          if (closeIdx != -1) {
            final divIdx = tailStr.lastIndexOf('</div>', closeIdx);
            if (divIdx != -1) {
              final truncateOffset = seekStart + divIdx;
              raf
                ..truncateSync(truncateOffset)
                ..setPositionSync(truncateOffset);
            }
          }
        }

        final divContext = factory.checkoutContext();
        try {
          HtmlEncoder.writeSessionDelimiter(
            divContext,
            timestamp: DateTime.now(),
            label: sessionLabel ?? 'Run PID: ${io.pid}',
          );
          final divBytes = divContext.takeBytes();
          if (divBytes.isNotEmpty) {
            raf.writeFromSync(divBytes);
          }
        } finally {
          factory.release(divContext);
        }
      } finally {
        raf.closeSync();
      }
    }
  }

  Future<void> flush() => _lock;

  Future<void> release(final LogPipelineFactory factory) {
    refCount--;
    if (refCount <= 0 && !isPostambleWritten) {
      if (mode == HtmlFileMode.fragment) {
        return Future<void>.value();
      }

      final completer = Completer<void>();
      final prevLock = _lock;
      _lock = completer.future;

      return prevLock.then((_) async {
        try {
          final file = io.File(path);
          if (file.existsSync() && isPreambleWritten && !isPostambleWritten) {
            isPostambleWritten = true;
            final postContext = factory.checkoutContext();
            try {
              encoder.postamble(postContext, LogLevel.info, factory);
              final postBytes = postContext.takeBytes();
              if (postBytes.isNotEmpty) {
                final raf = file.openSync(mode: io.FileMode.append);
                try {
                  raf.writeFromSync(postBytes);
                } finally {
                  raf.closeSync();
                }
              }
            } finally {
              factory.release(postContext);
            }
          }
        } finally {
          completer.complete();
        }
      });
    }
    return Future<void>.value();
  }
}
