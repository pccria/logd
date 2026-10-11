import 'dart:async';

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

/// This example serves as a comprehensive tutorial for [logd].
/// It covers everything from basic usage to advanced hierarchical configuration,
/// custom pipelines, and multi-column terminal layouts.
void main() async {
  print('================================================');
  print('          LOGD: COMPREHENSIVE SHOWCASE          ');
  print('================================================');
  print('Welcome to the logd tutorial. Follow the console');
  print('output to see how to master the logging engine.');
  print('');

  await runZonedGuarded(
    () async {
      _showcaseBasics();
      _showcaseHierarchy();
      await _showcaseTargetHandlers();
      await _showcaseStructuredContext();
      _showcasePipelines();
      _showcaseTimeAndLocalization();
      _showcaseAdvancedLayouts();
      _showcaseGridLayouts();

      print('\n\x1B[1mTutorial Complete!\x1B[0m');
      print('Check the source code in `example/main.dart` to learn more.');
    },
    (final error, final stack) {
      Logger.get().error(
        'Caught unexpected error in demo zone',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

/// 1. The Basics: Getting Started
/// logd uses a hierarchical naming system. The root logger is accessed via
/// Logger.get(), or you can specify a name.
void _showcaseBasics() {
  _section('1. The Basics');

  // By default, logd is configured with a ConsoleSink and StructuredFormatter.
  final logger = Logger.get('app')
    ..info('Welcome to Logd!')
    ..debug('Debug messages are hidden by default if level is higher.')
    ..warning('This is a warning message.')
    ..trace('Trace messages are not visible, right now.');

  // You can check and change the log level globally or per logger.
  Logger.configure('app', logLevel: LogLevel.trace);
  logger.trace('Now trace messages are visible.');
}

/// 2. Hierarchical Logging
/// Loggers inherit configuration from their parents. Overriding a parent's
/// config allows for fine-grained control over specific modules.
void _showcaseHierarchy() {
  _section('2. Hierarchical Logging');

  // We'll configure a decorator to visually show the depth.
  final hierarchicalHandler = Handler(
    formatter: const StructuredFormatter(),
    decorators: [
      const StyleDecorator(),
      const HierarchyDepthPrefixDecorator(indent: '  │ '),
    ],
    sink: const ConsoleSink(),
  );

  Logger.configure('app.services', handlers: [hierarchicalHandler]);

  final authService = Logger.get('app.services.auth');
  final database = Logger.get('app.services.database');

  authService.info('User "admin" logged in.');
  database.debug('Starting transaction...');

  // Overriding a sub-logger's level doesn't affect the parent.
  Logger.configure('app.services.database', logLevel: LogLevel.error);
  database.info('This will NOT be printed.');
  database.error('Critical database failure!');

  // --- Dynamic Wildcard Pattern Matching (v0.8.7+) ---
  // You can also match loggers dynamically by pattern.
  // Overwrite any *.database loggers with a warning level threshold.
  Logger.configurePattern('*.database', logLevel: LogLevel.warning);
  database.info('Pattern Override: Database info log (will not print).');
  database.warning('Pattern Override: Database warning log (WILL print!).');

  // Clean up pattern rule to restore default inheritance
  Logger.removePattern('*.database');
}

/// 3. Pre-Wired Target Handlers & Dual-Mode .async() (v0.9.3+)
/// logd provides zero-config TargetHandlers for common output destinations,
/// with .async() factories for unblocked background isolate offloading.
Future<void> _showcaseTargetHandlers() async {
  _section('3. Pre-Wired Target Handlers (v0.9.3+)');

  // ConsoleHandler with customized theme
  final console = ConsoleHandler(
    theme: const LogTheme.dark(),
  );

  // In-memory ring-buffer with direct programmatic inspection
  final memory = MemoryHandler(capacity: 10);

  Logger.configure('app.target_demo', handlers: [console, memory]);

  final logger = Logger.get('app.target_demo');
  logger.info('Event dispatched to ConsoleHandler and MemoryHandler');
  logger.warning('Second event captured in memory ring-buffer');

  // Yield to allow non-blocking async pipeline dispatch to complete
  await Future<void>.delayed(Duration.zero);

  print(
    'Inspect MemoryHandler entries: ${memory.entries.length} logs captured.',
  );
}

/// 4. Ambient Structured Context (MDC) (v0.9.4+)
/// LogContext.run allows attaching request, user, or trace metadata to all logs
/// in an asynchronous execution scope without passing maps through function parameters.
Future<void> _showcaseStructuredContext() async {
  _section('4. Ambient Structured Context (v0.9.4+)');

  final logger = Logger.get('app.order');

  await LogContext.run({'requestId': 'req-9812', 'tenant': 'eu-central'},
      () async {
    logger.info('Processing incoming order submission');

    await Future<void>.delayed(const Duration(milliseconds: 10));
    logger.info(
      'Payment verified',
      context: {'amount': 120.50, 'currency': 'EUR'},
    );
  });
}

/// 5. Pipeline Architecture: Handlers, Formatters, & Decorators
/// logd pipelines are modular. A Handler composes a Formatter (what it says),
/// a sequence of Decorators (how it looks), and a Sink (where it goes).
void _showcasePipelines() {
  _section('5. Pipeline Architecture');

  const prettyHandler = Handler(
    formatter: JsonPrettyFormatter(),
    decorators: [
      BoxDecorator(borderStyle: BorderStyle.double),
      StyleDecorator(),
    ],
    sink: ConsoleSink(
      lineLength: 60,
    ),
  );

  Logger.configure('app.api', handlers: [prettyHandler]);
  Logger.get('app.api').info('Received GET /users/123');

  // Multi-Sink: Send logs to multiple places (e.g., Console + File)
  final multiHandler = Handler(
    formatter: const PlainFormatter(),
    sink: MultiSink([
      const ConsoleSink(),
      FileSink('logs/demo.log'),
    ]),
  );

  Logger.configure('app.audit', handlers: [multiHandler]);
  Logger.get('app.audit').info('Audit log saved to file (logs/) and console.');
}

/// 6. Time & Localization
/// You can configure how timestamps appear globally or per handler.
/// Timezones are fully supported (UTC, Local, or Fixed offsets).
void _showcaseTimeAndLocalization() {
  _section('6. Time & Localization');

  // Global Timestamp configuration via Logger.configure
  Logger.configure(
    'global',
    timestamp: Timestamp(
      formatter: 'yyyy-MM-dd HH:mm:ss.SSS',
      timezone: Timezone.utc(),
    ),
  );
  Logger.get('app').info('This log is in UTC.');

  // Reset to Local time
  Logger.configure(
    'global',
    timestamp: Timestamp(
      formatter: 'HH:mm:ss',
      timezone: Timezone.local(),
    ),
  );
  Logger.get('app').info('Now we are back to Local time.');

  // Named Timezone (e.g., Asia/Tehran)
  Logger.configure(
    'global',
    timestamp: Timestamp(
      formatter: 'HH:mm:ss ZZZ',
      timezone: Timezone.named('Asia/Tehran'),
    ),
  );
  Logger.get('app').info('Log from a specific named timezone.');

  // Reset to default for the rest of the demo
  Logger.configure(
    'global',
    timestamp: Timestamp(
      formatter: 'HH:mm:ss',
      timezone: Timezone.local(),
    ),
  );
}

/// 7. Advanced Layouts: Structured & JSON
/// Specialized formatters provide unique visual styles for different use cases.
void _showcaseAdvancedLayouts() {
  _section('7. Advanced Layouts');

  // Comic-style structured logs (with explicit schema for machine parsing)
  Logger.configure('app.structured', handlers: [
    const Handler(
      formatter: StructuredFormatter(),
      sink: ConsoleSink(),
    )
  ]);
  Logger.get('app.structured')
      .warning('Something unusual happened in the story!');

  // Vibrant JSON for deep inspection
  Logger.configure('app.vibrant', handlers: [
    const Handler(
      formatter: JsonPrettyFormatter(),
      sink: ConsoleSink(),
    )
  ]);
  Logger.get('app.vibrant').info('Inspection of complex data.');
}

/// 8. Grid Layouts: Tables & Columns
/// One of the most powerful features of logd is its ability to render true
/// multi-column grids in the terminal.
void _showcaseGridLayouts() {
  _section('8. Grid Layouts');

  final gridHandler = Handler(
    formatter: const TableExampleFormatter(),
    sink: const ConsoleSink(),
  );

  Logger.configure('app.grid', handlers: [gridHandler]);
  Logger.get('app.grid').info('Rendering a professional report...');
}

@immutable
class TableExampleFormatter implements LogFormatter {
  const TableExampleFormatter();

  @override
  Set<LogMetadata> get metadata => {};

  @override
  void format(
    final LogEntry entry,
    final LogDocument document,
    final LogPipelineFactory factory,
  ) {
    document.startBox(tags: LogTag.header);
    document.startAlignment(LogAlignment.center);
    document.text('SYSTEM HEALTH REPORT', style: const LogStyle(bold: true));
    document.endAlignment();
    document.endBox();

    document.startTable(columnWidths: [16, 12, 12]);

    document.startRow();
    document.startCell();
    document.text('SUBSYSTEM', style: const LogStyle(bold: true));
    document.endCell();
    document.startCell();
    document.text('STATUS', style: const LogStyle(bold: true));
    document.endCell();
    document.startCell();
    document.text('LATENCY', style: const LogStyle(bold: true));
    document.endCell();
    document.endRow();

    document.startRow();
    document.startCell();
    document.text('Authentication');
    document.endCell();
    document.startCell();
    document.text('ONLINE', style: const LogStyle(color: LogColor.green));
    document.endCell();
    document.startCell();
    document.text('12ms');
    document.endCell();
    document.endRow();

    document.startRow();
    document.startCell();
    document.text('Payment Gateway');
    document.endCell();
    document.startCell();
    document.text('DEGRADED', style: const LogStyle(color: LogColor.yellow));
    document.endCell();
    document.startCell();
    document.text('185ms');
    document.endCell();
    document.endRow();

    document.startRow();
    document.startCell();
    document.text('Database Pool');
    document.endCell();
    document.startCell();
    document.text('ONLINE', style: const LogStyle(color: LogColor.green));
    document.endCell();
    document.startCell();
    document.text('3ms');
    document.endCell();
    document.endRow();

    document.endTable();
  }
}

/// Helper to print section headers
void _section(final String title) {
  print('\n\x1B[1m--- $title ---\x1B[0m');
}
