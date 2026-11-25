import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

void main() {
  group('TOON Schema Maturity', () {
    test('ToonFormatter produces legacy header by default', () async {
      const formatter = ToonFormatter(metadata: {LogMetadata.timestamp});
      final entry = LogEntry(
        loggerName: 'test',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2026-04-28',
        origin: 'main',
      );
      final doc = StandardDocument();
      formatter.format(entry, doc, const StandardPipelineFactory());

      const encoder = ToonEncoder();
      final context = HandlerContext();
      encoder.preamble(
        context,
        LogLevel.info,
        const StandardPipelineFactory(),
        document: doc,
      );

      expect(
        context.toString(),
        contains('logs[]{timestamp,level,message,error,stackTrace,context}:'),
      );
    });

    test('ToonFormatter produces explicit schema when requested', () async {
      const formatter = ToonFormatter(
        metadata: {LogMetadata.timestamp},
        explicitSchema: true,
      );
      final entry = LogEntry(
        loggerName: 'test',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2026-04-28',
        origin: 'main',
      );
      final doc = StandardDocument();
      formatter.format(entry, doc, const StandardPipelineFactory());

      const encoder = ToonEncoder();
      final context = HandlerContext();
      encoder.preamble(
        context,
        LogLevel.info,
        const StandardPipelineFactory(),
        document: doc,
      );

      final output = context.toString();
      expect(output, contains('logs[]{'));
      expect(output, contains('  timestamp'));
      expect(output, contains(': iso8601;'));
      expect(output, contains('  level'));
      expect(output, contains(': enum'));
      expect(output, contains('  message'));
      expect(output, contains(': markdown;'));
      expect(output, contains('}:'));
    });

    // ignore: deprecated_member_use
    test(
      'ToonPrettyFormatter produces explicit schema when requested',
      () async {
        // ignore: deprecated_member_use
        const formatter = ToonPrettyFormatter(
          metadata: {LogMetadata.logger},
          explicitSchema: true,
        );
        final entry = LogEntry(
          loggerName: 'test',
          level: LogLevel.debug,
          message: 'pretty',
          timestamp: '2026-04-28',
          origin: 'main',
        );
        final doc = StandardDocument();
        formatter.format(entry, doc, const StandardPipelineFactory());

        const encoder = ToonEncoder();
        final context = HandlerContext();
        encoder.preamble(
          context,
          LogLevel.debug,
          const StandardPipelineFactory(),
          document: doc,
        );

        final output = context.toString();
        expect(output, contains('logs[]{'));
        expect(output, contains('  logger'));
        expect(output, contains(': string;'));
        expect(output, contains('  level'));
        expect(output, contains(': enum'));
        expect(output, contains('}:'));
      },
    );

    test(
      'ToonFormatter with ToonDialect.strict includes version comment and emits \\N for nulls',
      () async {
        const formatter = ToonFormatter(
          metadata: {LogMetadata.timestamp},
          dialect: ToonDialect.strict,
        );
        final entry = LogEntry(
          loggerName: 'test',
          origin: 'main',
          level: LogLevel.info,
          message: 'strict test',
          timestamp: '2026-07-30',
          error: null,
        );
        final doc = StandardDocument();
        formatter.format(entry, doc, const StandardPipelineFactory());

        const encoder = ToonEncoder();
        final context = HandlerContext();
        encoder.preamble(
          context,
          LogLevel.info,
          const StandardPipelineFactory(),
          document: doc,
        );

        final preambleOutput = context.toString();
        expect(preambleOutput, contains('-- TOON/1.0 logs'));
        expect(preambleOutput, contains('-- DELIMITER:\\t QUOTE:" NULL:\\N'));

        context.takeBytes(); // Clear preamble
        encoder.encode(
          entry,
          doc,
          LogLevel.info,
          context,
          const StandardPipelineFactory(),
        );

        final rowOutput = context.toString();
        // Absent error, stackTrace, context fields should be \N
        expect(rowOutput, contains(r'\N'));
      },
    );

    test('ToonSchema.parse parses compact single-line preambles', () {
      const source =
          'metrics[]{timestamp,metricName,value,unit}:\n'
          '2026-11-25\tcpu_usage\t42.5\tpercent\n';

      final schema = ToonSchema.parse(source);
      expect(schema, isNotNull);
      expect(schema!.arrayName, equals('metrics'));
      expect(
        schema.columns,
        equals(['timestamp', 'metricName', 'value', 'unit']),
      );
      expect(schema.delimiter, equals('\t'));
      expect(schema.dialect, equals(ToonDialect.compact));
    });

    test('ToonSchema.parse parses strict multi-line typed preambles', () {
      const source =
          '-- TOON/1.0 events\n'
          '-- DELIMITER:\\t QUOTE:" NULL:\\N\n'
          'events[]{\n'
          '  timestamp : iso8601;\n'
          '  event_id  : string;\n'
          '  level     : enum(TRACE,DEBUG,INFO);\n'
          '  payload   : object;\n'
          '}:\n'
          '2026-11-25\tev-101\tINFO\t{status:ok}\n';

      final schema = ToonSchema.parse(source);
      expect(schema, isNotNull);
      expect(schema!.arrayName, equals('events'));
      expect(schema.dialect, equals(ToonDialect.strict));
      expect(
        schema.columns,
        equals(['timestamp', 'event_id', 'level', 'payload']),
      );
      expect(schema.columnTypes['timestamp'], equals(ToonType.iso8601));
      expect(schema.columnTypes['payload'], equals(ToonType.object));

      final preamble = schema.toPreamble(explicit: true);
      expect(preamble, contains('-- TOON/1.0 events'));
      expect(preamble, contains('events[]{\n'));
      expect(preamble, contains('timestamp'));
      expect(preamble, contains('}:\n'));
    });

    test('ToonSchema serialization round-trip and equality', () {
      const original = ToonSchema(
        arrayName: 'custom_data',
        columns: ['colA', 'colB'],
        delimiter: '|',
        dialect: ToonDialect.strict,
        columnTypes: {'colA': ToonType.string, 'colB': ToonType.iso8601},
      );

      final json = original.toJson();
      final fromJson = ToonSchema.fromJson(json);

      expect(fromJson, equals(original));
      expect(fromJson.hashCode, equals(original.hashCode));
      expect(fromJson.columns, equals(original.columns));
      expect(fromJson.columnTypes, equals(original.columnTypes));
    });
  });
}
