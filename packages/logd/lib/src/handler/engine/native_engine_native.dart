library;

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../../logger/logger.dart';
import '../decorator/decorator.dart';
import '../document/binary_ir_native.dart';
import '../document/document.dart';
import '../encoder/encoder.dart';
import '../engine/engine.dart';
import '../formatter/formatter.dart';
import '../sink/isolate_sink_native.dart';
import '../sink/sink.dart';
import 'arena_native.dart';
import 'isolate_protocol.dart';

/// A [LogEngine] that targets native platforms via FFI.
///
/// [NativeEngine] standardizes the [LogDocument] into a [BinaryIR] instruction
/// stream before passing it to a native shared library for high-performance
/// rendering.
@experimental
class NativeEngine implements LogEngine {
  /// Creates a [NativeEngine].
  NativeEngine();

  bool _warnedAboutFallback = false;

  @override
  LogPipelineFactory get factory => Arena.instance;

  @override
  Future<void> execute(
    final LogEntry entry,
    final LogFormatter formatter,
    final List<LogDecorator> decorators,
    final LogSink sink,
  ) async {
    final arena = Arena.instance;
    final document = arena.checkoutDocument() as ArenaDocument;

    try {
      // 1. Determine Execution Mode
      // If no decorators are present, we use "Streaming Mode" to bypass
      // object allocation entirely.
      if (decorators.isEmpty) {
        document.enableStreaming();
      }

      // 2. Format
      formatter.format(entry, document, arena);

      // 3. Finalize/Standardize
      final ffi.Pointer<ffi.Uint8> irPtr;
      if (document.isStreaming) {
        irPtr = document.writer.finalize();
      } else {
        // Standard Path: Apply decorators to the object tree
        if (decorators.isNotEmpty) {
          DecoratorPipeline(decorators).apply(document, entry, arena);
        }
        irPtr = document.writer.write(document);
      }

      // 4. Output
      if (sink is NativeIsolateSink && document.isStreaming) {
        // 4a. Backpressure: Wait for pool capacity if needed
        await arena.waitForPoolCapacity();

        // THE FAST PATH: Offload EVERYTHING (Rendering + I/O) to the isolate
        final width = sink.target.preferredWidth ?? 80;
        final packet =
            arena.checkoutNativePacket(document, terminalWidth: width);
        sink.dispatchPacket(packet);
        arena.resetNative(document); // Buffer already moved to in-flight
      } else if (sink is EncodingSink &&
          (sink.encoder is AnsiEncoder || sink.encoder is AutoConsoleEncoder)) {
        // Standard Path: Render locally and delegate to sink
        const binaryEncoder = BinaryAnsiEncoder();
        final output = binaryEncoder.encode(
          irPtr,
          terminalWidth: sink.preferredWidth ?? 80,
          level: entry.level,
        );
        final data = convert.utf8.encode(output);
        await sink.delegate(data);
      } else {
        // Fallback to standard engine for any other sink types
        if (!_warnedAboutFallback) {
          _warnedAboutFallback = true;
          InternalLogger.log(
            LogLevel.warning,
            'NativeEngine fallback: Bypassing native execution path and '
            'falling back to StandardEngine because the formatter/sink '
            'combination is not native-compatible (e.g. TOON formats or '
            'custom sinks).',
          );
        }
        await const StandardEngine()
            .execute(entry, formatter, decorators, sink);
      }
    } finally {
      // 5. Release
      document.releaseRecursive(arena);
    }
  }
}

/// A [LogEngine] that utilizes LIFO object pooling via [Arena].
///
/// This implementation is designed for high-throughput, low-latency
/// environments. By reusing objects across log cycles, it significantly
/// reduces allocation overhead and main-thread GC pressure.
///
/// **Constraints**:
/// - [LogDocument]s must not be retained beyond the log cycle.
/// - Sinks should ideally be [IsolateSink]s to maximize the benefit of
///   asynchronous I/O.
@experimental
class ArenaEngine implements LogEngine {
  const ArenaEngine();

  @override
  LogPipelineFactory get factory => Arena.instance;

  @override
  Future<void> execute(
    final LogEntry entry,
    final LogFormatter formatter,
    final List<LogDecorator> decorators,
    final LogSink sink,
  ) async {
    final arena = Arena.instance;
    final document = arena.checkoutDocument();

    try {
      // 1. Format: Populate the document using arena as factory
      formatter.format(entry, document, arena);

      // 2. Decorate: Transform document in-place
      if (decorators.isNotEmpty) {
        DecoratorPipeline(decorators).apply(document, entry, arena);
      }

      // 3. Output: Emission
      if (document.nodes.isNotEmpty) {
        await sink.output(document, entry, entry.level, factory);
      }
    } finally {
      // 4. Deterministic release: Always return entire tree to pool
      document.releaseRecursive(arena);
    }
  }
}

/// The entry point for the background isolate worker.
///
/// This worker performs the following tasks:
/// 1. Receives a [NativePacket] from the main isolate.
/// 2. Decodes the Binary IR using [BinaryAnsiEncoder].
/// 3. Serializes the output to bytes.
/// 4. Dispatches the bytes to the underlying [LogSink].
/// 5. Signals completion to recycle the native buffer.
@internal
void spawnNativeWorker(final List<dynamic> args) {
  final sendPort = args[0] as SendPort;
  final target = args[1] as EncodingSink;

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((final message) async {
    if (message is NativePacket) {
      try {
        const encoder = BinaryAnsiEncoder();
        final String output = encoder.encode(
          message.pointer,
          terminalWidth: message.terminalWidth,
          length: message.length,
        );

        // 2. Encode to UTF-8 bytes
        final data = convert.utf8.encode(output);

        // 3. Dispatch to Sink Delegate
        await target.delegate(data);
      } finally {
        // 4. Signal completion to recycle the buffer
        message.completionPort.send(message.address);
      }
    } else if (message is IsolateCommand) {
      if (message.type == IsolateCommandType.stop) {
        await target.dispose();
        message.replyPort?.send(null);
        receivePort.close();
      }
    } else if (message is IsolateLog) {
      final data = message.data.materialize().asUint8List();
      await target.delegate(data);
    }
  });
}
