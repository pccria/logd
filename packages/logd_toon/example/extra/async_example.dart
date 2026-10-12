import 'dart:async';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';

Future<void> main() async {
  // 1. Register TOON serializers
  // This is required so the background isolate knows how to serialize/deserialize ToonFormatter.
  registerLogdToonSerializers();

  // 2. Create a handler that writes to a file in TOON format, but delegates
  // the encoding and writing work to a background isolate (AsyncHandler).
  final asyncHandler = ToonFileHandler.async(
    path: 'logs/async_example.toon',
    dialect: ToonDialect.strict,
    explicitSchema: true,
    arrayName: 'async_logs',
  );

  // 3. Configure the logger
  Logger.configure(
    'app.async',
    handlers: [asyncHandler],
  );

  final logger = Logger.get('app.async');

  // Wait for the background isolate to be fully initialized.
  await asyncHandler.ready;

  print('Generating 100 log entries asynchronously...');

  final sw = Stopwatch()..start();

  // Push 100 logs as fast as possible. The main thread will not block
  // while the strings are serialized and written to disk.
  for (int i = 0; i < 100; i++) {
    logger.info(
      'User activity recorded',
      context: {'iteration': i, 'latency': i * 1.5},
    );
  }

  sw.stop();
  print('Pushed 100 entries to isolate in ${sw.elapsedMilliseconds} ms.');

  // Dispose ensures the isolate flushes its buffers before shutting down.
  await asyncHandler.dispose();
  print('Background isolate shutdown and files flushed.');
}
