import 'dart:async';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';

Future<void> main() async {
  // We use a tiny 10 KB max size so we can easily trigger rotation in a short loop.
  final handler = ToonFileHandler(
    path: 'logs/rotation_test.toon',
    fileRotation: SizeRotation(
      maxSize: '10 KB',
      backupCount: 2,
    ),
    formatter: const ToonFormatter(
      dialect: ToonDialect.strict,
      explicitSchema: true,
      arrayName: 'rotated_logs',
    ),
  );

  Logger.configure('app.rotation', handlers: [handler]);
  final logger = Logger.get('app.rotation');

  // Push enough data to force multiple file rotations
  print('Pushing logs to trigger 10 KB file rotations...');
  for (int i = 0; i < 300; i++) {
    logger.info(
      'Rotation test entry',
      context: {
        'iteration': i,
        'payload': 'x' * 100, // Artificially inflate row size
      },
    );
  }

  await handler.dispose();

  // Wait for FileSink async writes to fully flush
  await Future.delayed(const Duration(milliseconds: 500));

  // Validate the outputs
  final dir = Directory('logs');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.contains('rotation_test'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  print('\n--- Generated Files ---');
  for (final file in files) {
    print('${file.path} (${file.lengthSync()} bytes)');
    final lines = file.readAsLinesSync();
    if (lines.isNotEmpty) {
      print('  Header: ${lines.first}');
    } else {
      print('  Header: (Empty File)');
    }
  }
}
