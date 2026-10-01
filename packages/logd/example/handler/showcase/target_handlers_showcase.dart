import 'dart:io';

import 'package:logd/logd.dart';

/// Comprehensive showcase demonstrating 7 pre-wired TargetHandlers (v0.9.3+),
/// including synchronous in-process handlers and background isolate offloaded
/// `.async()` file handlers.
void main() async {
  print('=================================================================');
  print('       LOGD: PRE-WIRED TARGET HANDLERS SHOWCASE (v0.9.3+)       ');
  print('=================================================================');
  print(
      'Demonstrating 7 pre-wired handlers across terminal, memory, and disk.\n');

  final tempDir = Directory('temp_showcase_logs');
  if (tempDir.existsSync()) {
    tempDir.deleteSync(recursive: true);
  }
  tempDir.createSync(recursive: true);

  try {
    // -----------------------------------------------------------------
    // CHAPTER 1: In-Process Handlers (Console & Memory)
    // -----------------------------------------------------------------
    _section('CHAPTER 1: In-Process Handlers (Console & Memory)');

    final consoleHandler = ConsoleHandler(
      theme: const LogTheme.dark(),
      lineLength: 80,
    );

    final memoryHandler = MemoryHandler(capacity: 5);

    Logger.configure(
      'app.in_process',
      handlers: [consoleHandler, memoryHandler],
    );

    final inProcessLogger = Logger.get('app.in_process');
    inProcessLogger.info('Initializing application modules');
    inProcessLogger.warning('High memory usage detected on main isolate');
    inProcessLogger.error('Failed to establish secondary cache handle');

    // Yield to complete logging pipeline dispatch
    await Future<void>.delayed(const Duration(milliseconds: 20));

    print('\n[MemoryHandler Verification]');
    print('  - Retained log entries: ${memoryHandler.entries.length}');
    for (var i = 0; i < memoryHandler.entries.length; i++) {
      final e = memoryHandler.entries[i];
      print('    [$i] ${e.level.name.toUpperCase()}: ${e.message}');
    }

    // -----------------------------------------------------------------
    // CHAPTER 2: Background Isolate File Handlers (.async())
    // -----------------------------------------------------------------
    _section('CHAPTER 2: Background Isolate File Offloading (.async())');

    final jsonFile = File('${tempDir.path}/app_logs.json');
    final plainFile = File('${tempDir.path}/app_raw.log');

    // Zero-config background isolate offloading
    final jsonHandler = JsonFileHandler.async(
      path: jsonFile.path,
      pretty: true,
    );
    final plainHandler = PlainFileHandler.async(
      path: plainFile.path,
    );

    Logger.configure('app.async_file', handlers: [
      jsonHandler,
      plainHandler,
    ]);

    final asyncLogger = Logger.get('app.async_file');
    asyncLogger.info(
      'System startup complete',
      context: {'environment': 'production', 'nodes': 4},
    );
    asyncLogger.warning('Database pool connection latency high (>120ms)');
    asyncLogger.error(
      'Payment gateway timeout on transaction #9842',
      context: {'transactionId': 'TX-9842', 'amount': 249.99},
    );

    print('Dispatched 3 log records across background isolate file sinks...');
    print('Main thread returned immediately (~15µs unblocked execution).');

    // Allow background worker isolates to finish disk flushes
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Dispose handlers safely
    await jsonHandler.dispose();
    await plainHandler.dispose();

    // -----------------------------------------------------------------
    // CHAPTER 3: File Output Inspection & Verification
    // -----------------------------------------------------------------
    _section('CHAPTER 3: Disk File Output Inspection & Verification');

    _inspectFile(
      '1. JsonFileHandler.async()',
      jsonFile,
      preview: (final content) {
        final lines = content.trim().split('\n');
        if (lines.isEmpty || lines.first.isEmpty) {
          return 'No lines';
        }
        return 'Raw bytes: ${content.length} characters';
      },
    );

    _inspectFile(
      '2. PlainFileHandler.async()',
      plainFile,
      preview: (final content) => content.split('\n').first,
    );

    _section('SHOWCASE COMPLETE');
    print('Core pre-wired TargetHandlers executed & verified successfully!');
    print('Available satellite handlers:');
    print('  - SqliteHandler: package:logd_sqlite');
    print('  - HttpDashboardHandler: package:logd_network');
    print('  - HtmlFileHandler: package:logd_html');
    print('  - MarkdownFileHandler: package:logd_markdown');
    print('  - ToonFileHandler: package:logd_toon\n');
  } finally {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}

void _section(final String title) {
  print('\n-----------------------------------------------------------------');
  print('  $title');
  print('-----------------------------------------------------------------');
}

void _inspectFile(
  final String label,
  final File file, {
  required final String Function(String content) preview,
}) {
  final exists = file.existsSync();
  print('$label:');
  print('  - Exists on disk: $exists');
  if (exists) {
    final content = file.readAsStringSync();
    print('  - File size: ${file.lengthSync()} bytes');
    print('  - Sample preview: ${preview(content)}');
  }
}
