import 'dart:convert';
import 'dart:typed_data';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

import '../../test_helpers.dart';

void main() {
  group('ToonEncoder', () {
    const factory = StandardPipelineFactory();

    test('escaping rules', () {
      final doc = createTestDocument(['msg'], factory: factory);
      doc.metadata['toon_columns'] = ['test_col'];
      doc.metadata['toon_delimiter'] = '\t';

      final entry = LogEntry(
        loggerName: 'test',
        level: LogLevel.info,
        message: 'msg',
        timestamp: '2026-01-01',
        origin: 'main',
      );

      String encodeValue(Object? value) {
        doc.nodes.clear();
        doc.nodes.add(MapNode({'test_col': value}));

        final context = HandlerContext();
        const encoder = ToonEncoder();
        encoder.encode(entry, doc, LogLevel.info, context, factory);
        return utf8.decode(context.takeBytes());
      }

      // Plain text (unquoted)
      expect(encodeValue('hello'), equals('hello'));

      // Empty string
      expect(encodeValue(''), equals(''));

      // Contains delimiter
      expect(encodeValue('foo\tbar'), equals('"foo\tbar"'));

      // Contains quote
      expect(encodeValue('say "hi"'), equals('"say \\"hi\\""'));

      // Contains newline
      expect(encodeValue('line 1\nline 2'), equals('"line 1\\nline 2"'));

      // Contains special characters
      expect(encodeValue('status: ok'), equals('"status: ok"'));
      expect(encodeValue('{a}'), equals('"{a}"'));
      expect(encodeValue('[a]'), equals('"[a]"'));
      expect(encodeValue('a,b'), equals('"a,b"'));
    });

    test('list rendering', () {
      final doc = createTestDocument(['msg'], factory: factory);
      doc.metadata['toon_columns'] = ['test_col'];
      doc.metadata['toon_delimiter'] = '\t';

      final entry = LogEntry(
        loggerName: 'test',
        level: LogLevel.info,
        message: 'msg',
        timestamp: '2026-01-01',
        origin: 'main',
      );

      final context = HandlerContext();
      const encoder = ToonEncoder();

      doc.nodes.clear();
      doc.nodes.add(MapNode({
        'test_col': ['a', 'b', 'c']
      }));

      encoder.encode(entry, doc, LogLevel.info, context, factory);
      expect(utf8.decode(context.takeBytes()), equals('[a,b,c]'));
    });

    test('preamble with explicit schema and strict dialect', () {
      final doc = createTestDocument(['msg'], factory: factory);
      doc.metadata['toon_columns'] = ['col1', 'col2'];
      doc.metadata['toon_schema'] = {
        'col1': ToonType.string,
        'col2': ToonType.object
      };
      doc.metadata['toon_dialect'] = ToonDialect.strict;

      final context = HandlerContext();
      const encoder = ToonEncoder();

      encoder.preamble(context, LogLevel.info, factory, document: doc);
      final output = utf8.decode(context.takeBytes());

      expect(output, contains('-- TOON/1.0 logs'));
      expect(output, contains('logs[]{'));
      expect(output, contains('  col1 : string;'));
      expect(output, contains('  col2 : object;'));
      expect(output, contains('}:\n'));

      final preamble =
          ToonEncoder.extractPreamble(Uint8List.fromList(utf8.encode(output)));
      expect(preamble, isNotNull);
      expect(preamble, contains('}:\n'));
    });

    test('preamble returns silently if columns are missing', () {
      final doc = createTestDocument(['msg'], factory: factory);

      final context = HandlerContext();
      const encoder = ToonEncoder();

      encoder.preamble(context, LogLevel.info, factory, document: doc);
      expect(context.length, equals(0));
    });
  });
}
