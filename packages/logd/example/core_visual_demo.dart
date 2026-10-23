import 'package:logd/logd.dart';

Future<void> main() async {
  // 1. Configure hierarchical logging with depth prefixes
  final hierHandler = Handler(
    formatter: const StructuredFormatter(),
    decorators: const [
      StyleDecorator(DarkTheme()),
      HierarchyDepthPrefixDecorator(indent: '  │ '),
    ],
    sink: const ConsoleSink(
      lineLength: 80,
      encoder: AnsiEncoder(),
    ),
  );

  Logger.configure('pipeline', handlers: [hierHandler]);

  final pipeline = Logger.get('pipeline');
  final authService = Logger.get('pipeline.auth');
  final syncService = Logger.get('pipeline.sync');
  final buildService = Logger.get('pipeline.build');

  pipeline.info('Initiating distributed build pipeline...');
  authService.info('OAuth2 session validated for [pooria] (tenant: us-east-1)');
  syncService
      .info('Resolving remote dependencies (14 packages, 0 cache misses)');
  buildService.info('Bundling native assets and compiling Dart AOT snapshot');

  // 2. Table Example
  final tableHandler = Handler(
    formatter: const _HealthTableFormatter(),
    sink: const ConsoleSink(
      lineLength: 80,
      encoder: AnsiEncoder(),
    ),
  );

  Logger.configure('metrics', handlers: [tableHandler]);
  Logger.get('metrics').info('');
}

class _HealthTableFormatter implements LogFormatter {
  const _HealthTableFormatter();

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
    document.text('SYSTEM SERVICE METRICS', style: const LogStyle(bold: true));
    document.endAlignment();
    document.endBox();

    document.startTable(columnWidths: [22, 14, 12]);

    document.startRow();
    document.startCell();
    document.text('SERVICE', style: const LogStyle(bold: true));
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
    document.text('Authentication API');
    document.endCell();
    document.startCell();
    document.text('ONLINE',
        style: const LogStyle(color: LogColor.green, bold: true));
    document.endCell();
    document.startCell();
    document.text('12ms');
    document.endCell();
    document.endRow();

    document.startRow();
    document.startCell();
    document.text('SQLite WAL Engine');
    document.endCell();
    document.startCell();
    document.text('ONLINE',
        style: const LogStyle(color: LogColor.green, bold: true));
    document.endCell();
    document.startCell();
    document.text('2ms');
    document.endCell();
    document.endRow();

    document.startRow();
    document.startCell();
    document.text('Payment Gateway');
    document.endCell();
    document.startCell();
    document.text('DEGRADED',
        style: const LogStyle(color: LogColor.yellow, bold: true));
    document.endCell();
    document.startCell();
    document.text('185ms');
    document.endCell();
    document.endRow();

    document.endTable();
  }
}
