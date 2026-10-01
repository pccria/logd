import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

void main() {
  group('TOON Schema Maturity', () {
    test('ToonFormatter produces legacy header by default', () async {
      const formatter = ToonFormatter(
        metadata: {LogMetadata.timestamp},
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
    test('ToonPrettyFormatter produces explicit schema when requested',
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
    });

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
    });
  });
}
