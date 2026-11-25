import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

void main() {
  group('ToonDecoder & ToonRecord Tests', () {
    const decoder = ToonDecoder();

    test('decodes compact single-line TOON stream into ToonDocument', () {
      const source =
          'logs[]{timestamp,logger,level,message,error,stackTrace,context}:\n'
          '2026-11-25T12:00:00.000\tapp.billing\tINFO\tServer started\t\t\t\n'
          '2026-11-25T12:00:01.000\tapp.billing\tERROR\tPayment failed\tTimeout\tstack\t{gateway:stripe,amount:49.99}\n';

      final doc = decoder.decode(source);
      expect(doc.schema.arrayName, equals('logs'));
      expect(
        doc.schema.columns,
        equals([
          'timestamp',
          'logger',
          'level',
          'message',
          'error',
          'stackTrace',
          'context',
        ]),
      );
      expect(doc.records.length, equals(2));

      final first = doc.records[0];
      expect(first.timestamp, equals('2026-11-25T12:00:00.000'));
      expect(first.logger, equals('app.billing'));
      expect(first.level, equals(LogLevel.info));
      expect(first.levelName, equals('INFO'));
      expect(first.message, equals('Server started'));
      expect(first.error, isNull);
      expect(first.stackTrace, isNull);
      expect(first.context, isNull);

      final second = doc.records[1];
      expect(second.timestamp, equals('2026-11-25T12:00:01.000'));
      expect(second.level, equals(LogLevel.error));
      expect(second.error, equals('Timeout'));
      expect(second.stackTrace, equals('stack'));

      final ctx = second.context as Map<String, Object?>?;
      expect(ctx, isNotNull);
      expect(ctx!['gateway'], equals('stripe'));
      expect(ctx['amount'], equals(49.99));
    });

    test('decodes strict dialect with comments and \\N null tokens', () {
      const source =
          '-- TOON/1.0 audit_logs\n'
          '-- DELIMITER:\\t QUOTE:" NULL:\\N\n'
          'audit_logs[]{timestamp,logger,level,message,error,stackTrace,context}:\n'
          '2026-11-25\taudit\tINFO\tUser login\t\\N\t\\N\t{ip:127.0.0.1}\n'
          '2026-11-25\taudit\tWARNING\tSuspicious activity\t\\N\t\\N\t\\N\n';

      final doc = decoder.decode(source);
      expect(doc.schema.dialect, equals(ToonDialect.strict));
      expect(doc.schema.arrayName, equals('audit_logs'));
      expect(doc.records.length, equals(2));

      final first = doc.records[0];
      expect(first.error, isNull);
      expect(first.stackTrace, isNull);
      expect(first.context, isA<Map<String, Object?>>());

      final second = doc.records[1];
      expect(second.error, isNull);
      expect(second.stackTrace, isNull);
      expect(second.context, isNull);
    });

    test('decodes quotes, escaped delimiters, and literal newlines', () {
      const source =
          'logs[]{timestamp,logger,level,message}:\n'
          '2026-11-25\tapp\tINFO\t"Hello\\tWorld with \\"quotes\\" and \\nnewlines"\n';

      final doc = decoder.decode(source);
      final record = doc.records[0];
      expect(
        record.message,
        equals('Hello\tWorld with "quotes" and \nnewlines'),
      );
    });

    test('decodes nested lists and maps recursively', () {
      const source =
          'logs[]{timestamp,message,context}:\n'
          '2026-11-25\tUpdate\t{user:101,tags:[admin,moderator],active:true,settings:{dark:true}}\n';

      final doc = decoder.decode(source);
      final ctx = doc.records[0].context as Map<String, Object?>;
      expect(ctx['user'], equals(101));
      expect(ctx['tags'], equals(['admin', 'moderator']));
      expect(ctx['active'], isTrue);

      final settings = ctx['settings'] as Map<String, Object?>;
      expect(settings['dark'], isTrue);
    });

    test('decodes stream of lines in O(1) memory', () async {
      final lines = Stream.fromIterable([
        'logs[]{timestamp,level,message}:',
        '2026-11-25\tINFO\tChunk 1',
        '',
        '2026-11-25\tWARNING\tChunk 2',
      ]);

      final records = await decoder.decodeStream(lines).toList();
      expect(records.length, equals(2));
      expect(records[0].message, equals('Chunk 1'));
      expect(records[1].message, equals('Chunk 2'));
    });

    test('round-trip encoding and decoding parity', () {
      const formatter = ToonFormatter(
        metadata: {LogMetadata.timestamp, LogMetadata.logger},
        sortKeys: true,
      );

      final entry = LogEntry(
        loggerName: 'billing',
        origin: 'main',
        level: LogLevel.info,
        message: 'Subscription created',
        timestamp: '2026-11-25T14:00:00.000',
        context: {'plan': 'pro', 'seats': 5, 'active': true},
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
      encoder.encode(
        entry,
        doc,
        LogLevel.info,
        context,
        const StandardPipelineFactory(),
      );

      final renderedToon = context.toString();
      final decodedDoc = decoder.decode(renderedToon);

      expect(decodedDoc.records.length, equals(1));
      final record = decodedDoc.records[0];
      expect(record.timestamp, equals('2026-11-25T14:00:00.000'));
      expect(record.logger, equals('billing'));
      expect(record.level, equals(LogLevel.info));
      expect(record.message, equals('Subscription created'));

      final ctx = record.context as Map<String, Object?>;
      expect(ctx['plan'], equals('pro'));
      expect(ctx['seats'], equals(5));
      expect(ctx['active'], isTrue);
    });

    test('throws FormatException on empty or invalid input', () {
      expect(() => decoder.decode(''), throwsA(isA<FormatException>()));
      expect(
        () => decoder.decode('not a toon stream\njust plain lines'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
