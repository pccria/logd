// ignore_for_file: experimental_member_use

import 'dart:convert';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

import '../../test_helpers.dart';

void main() {
  group('ToonFormatter Edge Cases', () {
    test('strict mode emits \\N for absent fields', () {
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2026-01-01',
        error: null,
      );

      const formatter = ToonFormatter(dialect: ToonDialect.strict);
      final doc = formatDoc(formatter, entry);

      final context = HandlerContext();
      const encoder = ToonEncoder();
      encoder.encode(
          entry, doc, LogLevel.info, context, const StandardPipelineFactory());

      final output = utf8.decode(context.takeBytes());
      expect(output, contains('\\N'));

      doc.releaseRecursive(Arena.instance);
    });

    test('compact mode emits empty string for absent fields', () {
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2026-01-01',
        error: null,
      );

      const formatter = ToonFormatter(dialect: ToonDialect.compact);
      final doc = formatDoc(formatter, entry);

      final context = HandlerContext();
      const encoder = ToonEncoder();
      encoder.encode(
          entry, doc, LogLevel.info, context, const StandardPipelineFactory());

      final output = utf8.decode(context.takeBytes());
      expect(output, isNot(contains('\\N')));
      expect(output, contains('\t\t'));

      doc.releaseRecursive(Arena.instance);
    });

    test('custom metadata sets', () {
      final entry = LogEntry(
        loggerName: 'test',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'hello',
        timestamp: '2026-01-01',
      );

      const emptyMetaFormatter = ToonFormatter(metadata: {});
      final doc1 = formatDoc(emptyMetaFormatter, entry);
      final cols1 = doc1.metadata['toon_columns'] as List<String>;
      expect(cols1,
          equals(['level', 'message', 'error', 'stackTrace', 'context']));
      doc1.releaseRecursive(Arena.instance);

      const customMetaFormatter = ToonFormatter(metadata: {LogMetadata.origin});
      final doc2 = formatDoc(customMetaFormatter, entry);
      final cols2 = doc2.metadata['toon_columns'] as List<String>;
      expect(
          cols2,
          equals([
            'origin',
            'level',
            'message',
            'error',
            'stackTrace',
            'context'
          ]));
      doc2.releaseRecursive(Arena.instance);

      const namedFormatter =
          ToonFormatter(arrayName: 'custom_arr', delimiter: '|');
      final doc3 = formatDoc(namedFormatter, entry);

      final context = HandlerContext();
      const encoder = ToonEncoder();
      encoder.preamble(context, LogLevel.info, const StandardPipelineFactory(),
          document: doc3);
      final header = utf8.decode(context.takeBytes());
      expect(header, startsWith('custom_arr[]{'));

      encoder.encode(
          entry, doc3, LogLevel.info, context, const StandardPipelineFactory());
      final row = utf8.decode(context.takeBytes());
      expect(row, contains('|'));

      doc3.releaseRecursive(Arena.instance);
    });

    test('context field behavior', () {
      final mapEntry = LogEntry(
        loggerName: 'test',
        level: LogLevel.info,
        message: 'msg',
        timestamp: '2026-01-01',
        origin: 'main.dart',
        context: {'key': 'value'},
      );

      const formatter = ToonFormatter();
      final doc1 = formatDoc(formatter, mapEntry);

      final ctx1 = HandlerContext();
      const encoder = ToonEncoder();
      encoder.encode(
          mapEntry, doc1, LogLevel.info, ctx1, const StandardPipelineFactory());
      expect(utf8.decode(ctx1.takeBytes()), contains('{key:value}'));
      doc1.releaseRecursive(Arena.instance);

      final strEntry = LogEntry(
        loggerName: 'test',
        level: LogLevel.info,
        message: 'msg',
        timestamp: '2026-01-01',
        origin: 'main.dart',
        context: {'data': 'plain string'},
      );

      final doc2 = formatDoc(formatter, strEntry);
      encoder.encode(
          strEntry, doc2, LogLevel.info, ctx1, const StandardPipelineFactory());
      expect(utf8.decode(ctx1.takeBytes()), contains('plain string'));
      doc2.releaseRecursive(Arena.instance);

      final objEntry = LogEntry(
        loggerName: 'test',
        level: LogLevel.info,
        message: 'msg',
        timestamp: '2026-01-01',
        origin: 'main.dart',
        context: {'uri': Uri.parse('https://example.com:8080/path')},
      );

      final doc3 = formatDoc(formatter, objEntry);
      encoder.encode(
          objEntry, doc3, LogLevel.info, ctx1, const StandardPipelineFactory());
      expect(utf8.decode(ctx1.takeBytes()),
          contains('"https://example.com:8080/path"'));
      doc3.releaseRecursive(Arena.instance);
    });
  });
}
