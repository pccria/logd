import 'package:logd/logd.dart';

void main() async {
  print('\x1B[1m\x1B[96mlogd\x1B[0m | Native Engine (B-IR / FFI) Showcase');
  print(
    '\x1B[2m─────────────────────────────────────────────────────────────\x1B[0m',
  );

  print('\x1B[1m=== DEMO 1: Native Engine Basic Execution ===\x1B[0m');
  print('Executing logs using NativeEngine with Binary IR serialization...');

  final nativeHandler = Handler(
    formatter: const PlainFormatter(
      metadata: {
        LogMetadata.timestamp,
        LogMetadata.logger,
      },
    ),
    decorators: const [
      StyleDecorator(),
      BoxDecorator(borderStyle: BorderStyle.rounded),
    ],
    sink: ConsoleSink(lineLength: 100),
    engine: NativeEngine(),
  );

  Logger.configure(
    'sys.native',
    timestamp: Timestamp(formatter: 'HH:mm:ss.SSS'),
    handlers: [nativeHandler],
  );
  final logger = Logger.get('sys.native');

  logger.info('Native Engine initialized successfully with B-IR v2.');
  logger.warning('Decorated box layout rendered via native pipeline.');

  print('\n\x1B[1m=== DEMO 2: Multi-Line Payload & Spacious Layout ===\x1B[0m');
  print('Rendering multi-line log with balanced metadata width...');

  final buffer = StringBuffer();
  for (int i = 0; i < 5; i++) {
    buffer.writeln('Entry #$i: batch processing chunk of metrics data');
  }
  logger.info('Processed batch:\n$buffer');

  print(
      '\n\x1B[1m=== DEMO 3: High-Volume Payload (>64KB Dynamic Expansion) ===\x1B[0m');
  print('Generating an 80KB payload to exercise dynamic slab expansion...');

  final largeBuffer = StringBuffer();
  for (int i = 0; i < 1500; i++) {
    largeBuffer.writeln('TelemetryChunk #$i: status=OK throughput=19.4k ops/s');
  }
  final largePayload = largeBuffer.toString();
  print(
      'Payload generated: ${largePayload.length} bytes (exceeds 64KB initial slab).');

  var totalBytes = 0;
  final countingSink = EncodingSink(
    encoder: const AnsiEncoder(),
    delegate: (final data) {
      totalBytes += data.length;
    },
  );
  final largeHandler = Handler(
    formatter: const PlainFormatter(metadata: {}),
    sink: countingSink,
    engine: NativeEngine(),
  );
  Logger.configure('sys.large', handlers: [largeHandler]);
  Logger.get('sys.large').info(largePayload);

  print('NativeEngine successfully processed and encoded $totalBytes bytes.');
  print(
      '\x1B[32m✔ NativeEngine completed execution cleanly without memory faults.\x1B[0m');
}
