import 'dart:io' as io;
import 'package:logd/logd.dart';

/// The ultimate showcase for Logd Handler module.
///
/// Demonstrates the full power of:
/// - Multiple backends (Console, HTML, Markdown, JSON Semantic)
/// - Fine-grained coloring and structural decoration
/// - Hierarchical context and indention
/// - Error handling and stack trace formatting
void main() async {
  print('🎭 LOGD THEATRE: Final Showcase 🎭');
  print('===================================\n');

  const basePath = 'logs/showcase';

  // Ensure directories exist
  _prepareDirectories(basePath);

  // 1. Setup the Multi-Backend Theatre
  const consoleHandler = Handler(
    formatter: StructuredFormatter(),
    decorators: [
      StyleDecorator(
        _HeaderBackgroundTheme(),
      ),
      BoxDecorator(
        borderStyle: BorderStyle.rounded,
      ),
    ],
    sink: ConsoleSink(
      lineLength: 80,
    ),
  );

  final plainFileHandler = PlainFileHandler(
    path: '$basePath/app.log',
  );

  final memoryHandler = MemoryHandler(capacity: 50);

  final semanticHandler = Handler(
    formatter: const JsonPrettyFormatter(),
    sink: FileSink('$basePath/telemetry.json'),
  );

  final structuredHandler = Handler(
    formatter: const StructuredFormatter(),
    sink: FileSink(
      '$basePath/structured.log',
      encoder: const JsonEncoder(),
    ),
  );

  // Configure everything
  Logger.configure(
    'theatre',
    handlers: [
      consoleHandler,
      plainFileHandler,
      memoryHandler,
      semanticHandler,
      structuredHandler,
    ],
    logLevel: LogLevel.trace,
  );

  final logger = Logger.get('theatre');
  final netLogger = Logger.get('theatre.network');
  final dbLogger = Logger.get('theatre.database');

  // Scene 1: System Startup
  print('🎬 Scene 1: System Startup');
  logger
    ..info('Initializing Logd Theatre Core...')
    ..debug('Loading theater scenes from assets/scripts/v1.json');

  // Scene 2: Network Activity
  print('\n🎬 Scene 2: Network Activity');
  netLogger
    ..info('Connecting to Global Backend Service...')
    ..trace('GET /api/v1/auth/tokens - 200 OK (45ms)')
    ..warning('High latency detected in us-east region: 450ms');

  // Scene 3: The Incident
  print('\n🎬 Scene 3: The Incident');
  dbLogger.info('Synchronizing actor database...');
  try {
    _performInvalidDatabaseOperation();
  } catch (e, s) {
    dbLogger.error(
      'Critical database corruption detected!',
      error: e,
      stackTrace: s,
    );
  }

  // Scene 4: Multi-line Telemetry
  print('\n🎬 Scene 4: Multi-line Telemetry');
  final buffer = logger.infoBuffer;
  buffer?.writeln('Production Report:');
  buffer?.writeln('  📊 CPU Usage: 42%');
  buffer?.writeln('  🌡️ Temperature: 68°C');
  buffer?.writeln('  💾 Available Memory: 12.4 GB');
  buffer?.sink();

  // Scene 5: Hierarchy Isolation
  print('\n🎬 Scene 5: Hierarchy Isolation');
  Logger.get('theatre.sub.deep')
      .info('This prefix should not be colored even if level is colored.');

  // Scene 6: Closing down
  print('\n🎬 Scene 6: Curtain Call');
  logger.info('Theatre closing... Writing all logs.');

  // Give some time for async loggers to finish
  await Future.delayed(const Duration(milliseconds: 500));

  // Finalize sinks
  await plainFileHandler.dispose();
  await semanticHandler.sink.dispose();
  await structuredHandler.sink.dispose();

  print('\n✅ Showcase Complete!');
  print('-----------------------------------------');
  print('Check the following files for results:');
  print('  🖥️  Terminal: Structured & Boxed output');
  print('  📄  Plain Log:      $basePath/app.log');
  print('  🧬  JSON Telemetry: $basePath/telemetry.json');
  print('  🤖  Structured Log: $basePath/structured.log');
  print(
      '  💾  In-Memory Log:  ${memoryHandler.entries.length} entries retained');
  print('-----------------------------------------');
}

void _prepareDirectories(final String path) {
  final dir = io.Directory(path);
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
  dir.createSync(recursive: true);
}

void _performInvalidDatabaseOperation() {
  throw const io.FileSystemException('Permission denied', '/var/db/actors.db');
}

class _HeaderBackgroundTheme extends LogTheme {
  const _HeaderBackgroundTheme()
      : super(colorScheme: LogColorScheme.defaultScheme);

  @override
  LogStyle getStyle(final LogLevel level, final int tags) {
    var style = super.getStyle(level, tags);
    if (((tags & LogTag.header) != 0)) {
      style = LogStyle(
        color: style.color,
        bold: style.bold,
        dim: style.dim,
        inverse: true, // Force inverse
      );
    }
    return style;
  }
}
