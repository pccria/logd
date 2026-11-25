import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';

void main() {
  print('================================================================');
  print('         logd_toon v0.2.0 Interactive Showcase Gallery          ');
  print('================================================================\n');

  _demo1CompactAndStrictDialect();
  _demo2PromotedContextColumns();
  _demo3BidirectionalDecoding();
  _demo4TokenBudgetingAndMetrics();
  _demo5ContextWindowSlicing();
  _demo6DuckDbAnalyticalBridge();

  print('\nAll showcase scenarios executed successfully.');
}

void _demo1CompactAndStrictDialect() {
  print('--- Scenario 1: Compact vs Strict TOON Dialects ---');

  const compactFormatter = ToonFormatter(
    metadata: {LogMetadata.timestamp, LogMetadata.logger},
    dialect: ToonDialect.compact,
  );

  const strictFormatter = ToonFormatter(
    metadata: {LogMetadata.timestamp, LogMetadata.logger},
    dialect: ToonDialect.strict,
    explicitSchema: true,
  );

  final entry = LogEntry(
    loggerName: 'orders',
    origin: 'checkout.dart:42',
    level: LogLevel.info,
    message: 'Cart checkout initiated',
    timestamp: '2026-11-25T15:00:00.000',
    context: {'cartId': 'c-8821'},
  );

  final compactDoc = StandardDocument();
  compactFormatter.format(entry, compactDoc, const StandardPipelineFactory());

  const encoder = ToonEncoder();
  final compactCtx = HandlerContext();
  encoder.preamble(
    compactCtx,
    LogLevel.info,
    const StandardPipelineFactory(),
    document: compactDoc,
  );
  encoder.encode(
    entry,
    compactDoc,
    LogLevel.info,
    compactCtx,
    const StandardPipelineFactory(),
  );

  print('[Compact Dialect Output]:');
  print(compactCtx.toString().trim());

  final strictDoc = StandardDocument();
  strictFormatter.format(entry, strictDoc, const StandardPipelineFactory());

  final strictCtx = HandlerContext();
  encoder.preamble(
    strictCtx,
    LogLevel.info,
    const StandardPipelineFactory(),
    document: strictDoc,
  );
  encoder.encode(
    entry,
    strictDoc,
    LogLevel.info,
    strictCtx,
    const StandardPipelineFactory(),
  );

  print('\n[Strict Dialect Output]:');
  print(strictCtx.toString().trim());
  print('');
}

void _demo2PromotedContextColumns() {
  print('--- Scenario 2: Promoted contextColumns (Column Invariance) ---');

  const formatter = ToonFormatter(
    metadata: {LogMetadata.timestamp},
    contextColumns: ['traceId', 'userId', 'tier'],
  );

  final entry = LogEntry(
    loggerName: 'billing',
    origin: 'payment.dart:18',
    level: LogLevel.info,
    message: 'Invoice generated',
    timestamp: '2026-11-25T15:01:00.000',
    context: {
      'traceId': 'tr-7719-ab',
      'userId': 'usr-552',
      'tier': 'enterprise',
      'amount': 249.00,
    },
  );

  final doc = StandardDocument();
  formatter.format(entry, doc, const StandardPipelineFactory());

  const encoder = ToonEncoder();
  final ctx = HandlerContext();
  encoder.preamble(
    ctx,
    LogLevel.info,
    const StandardPipelineFactory(),
    document: doc,
  );
  encoder.encode(
    entry,
    doc,
    LogLevel.info,
    ctx,
    const StandardPipelineFactory(),
  );

  print('[Promoted Columns Output]:');
  print(ctx.toString().trim());
  print('');
}

void _demo3BidirectionalDecoding() {
  print('--- Scenario 3: Bidirectional Decoding with ToonDecoder ---');

  const rawToon =
      'logs[]{timestamp,logger,level,message,error,stackTrace,context}:\n'
      '2026-11-25T15:02:00.000\tapi\tINFO\tRequest received\t\t\t{route:"/users",method:"GET"}\n'
      '2026-11-25T15:02:01.000\tapi\tERROR\tDatabase timeout\tConnectionTimeout\tat pool.dart:10\t{retry:3}\n';

  const decoder = ToonDecoder();
  final document = decoder.decode(rawToon);

  print(
    'Decoded Schema: ${document.schema.arrayName} [${document.schema.columns.join(', ')}]',
  );
  print('Parsed Records (${document.records.length}):');

  for (final record in document.records) {
    print(
      ' - [${record.levelName}] ${record.message} (Context: ${record.context})',
    );
  }
  print('');
}

void _demo4TokenBudgetingAndMetrics() {
  print('--- Scenario 4: Token Budget Profiling (ToonTokenEstimator) ---');

  const stream =
      'logs[]{timestamp,logger,level,message,context}:\n'
      '2026-11-25T15:03:00.000\tworker\tINFO\tBatch job 1 complete\t{processed:100,errors:0}\n'
      '2026-11-25T15:03:01.000\tworker\tINFO\tBatch job 2 complete\t{processed:150,errors:1}\n'
      '2026-11-25T15:03:02.000\tworker\tINFO\tBatch job 3 complete\t{processed:200,errors:0}\n'
      '2026-11-25T15:03:03.000\tworker\tWARNING\tQueue threshold reached\t{queueSize:850}\n';

  final metrics = ToonTokenEstimator.analyze(stream);

  print(
    'TOON Tokens  : ${metrics.toonTokens} tokens (${metrics.toonBytes} bytes)',
  );
  print(
    'JSON Tokens  : ${metrics.jsonTokens} tokens (${metrics.jsonBytes} bytes)',
  );
  print(
    'Tokens Saved : ${metrics.savedTokens} tokens (${metrics.savingsPercent}% reduction)',
  );
  print('');
}

void _demo5ContextWindowSlicing() {
  print(
    '--- Scenario 5: Token-Aware Context Window Slicing (ToonContextWindow) ---',
  );

  final buffer = StringBuffer()
    ..writeln('logs[]{timestamp,logger,level,message}:');
  for (var i = 1; i <= 20; i++) {
    buffer.writeln(
      '2026-11-25T15:04:$i\tservice\tINFO\tHistorical cycle iteration $i',
    );
  }

  final fullContent = buffer.toString();
  final slice = ToonContextWindow.slice(
    fullContent,
    maxRows: 4,
    truncationIndicator:
        '... [16 historical entries trimmed for LLM context budget] ...',
  );

  print(
    'Slice Result (Included: ${slice.includedRows}, Dropped: ${slice.droppedRows}):',
  );
  print(slice.content);
  print('');
}

void _demo6DuckDbAnalyticalBridge() {
  print('--- Scenario 6: Analytical DuckDB SQL Bridge (ToonDuckDb) ---');

  const schema = ToonSchema(
    arrayName: 'telemetry_events',
    columns: ['timestamp', 'logger', 'level', 'message', 'traceId', 'context'],
    columnTypes: {
      'timestamp': ToonType.iso8601,
      'logger': ToonType.string,
      'level': ToonType('enum', 'INFO,WARNING,ERROR'),
      'message': ToonType.markdown,
      'traceId': ToonType.string,
      'context': ToonType.object,
    },
  );

  final selectSql = ToonDuckDb.selectQuery(
    schema,
    filePath: 'logs/telemetry.toon',
    whereClause: "level = 'ERROR'",
    limit: 50,
  );

  final ddlSql = ToonDuckDb.createTableSql(schema);

  print('[DuckDB Direct Query]:');
  print(selectSql);
  print('\n[DuckDB Table DDL]:');
  print(ddlSql);
  print('');
}
