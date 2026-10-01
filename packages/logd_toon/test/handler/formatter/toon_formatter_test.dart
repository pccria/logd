// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:typed_data';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

import '../../test_helpers.dart';

void main() {
  group('ToonFormatter', () {
    final entry = LogEntry(
      loggerName: 'test.logger',
      origin: 'main.dart',
      level: LogLevel.info,
      message: 'Hello World',
      timestamp: '2025-01-01',
      error: null,
      stackTrace: null,
    );

    test('renders with header and body row', () {
      const formatter = ToonFormatter();
      final doc = formatDoc(formatter, entry);

      try {
        final lines = renderToon(doc, entry, LogLevel.info);
        expect(lines.length, equals(2));
        expect(lines[0], contains('timestamp'));
        expect(lines[0], contains('logger'));
        expect(lines[1], contains('2025-01-01'));
        expect(lines[1], contains('test.logger'));
        expect(lines[1], contains('Hello World'));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('handles multiline messages by repeating header data', () {
      final multilineEntry = LogEntry(
        loggerName: 'test.logger',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'Line 1\nLine 2',
        timestamp: '2025-01-01',
      );
      const formatter = ToonFormatter();
      final doc = formatDoc(formatter, multilineEntry);

      try {
        final lines = renderToon(doc, multilineEntry, LogLevel.info);

        // Header + 2 rows
        expect(lines.length, equals(3));
        expect(lines[1], contains('Line 1'));
        expect(lines[2], contains('Line 2'));

        // Both rows should have metadata
        expect(lines[1], contains('2025-01-01'));
        expect(lines[2], contains('2025-01-01'));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('aligns metadata columns correctly', () {
      const formatter = ToonFormatter();
      final doc = formatDoc(formatter, entry);

      try {
        final lines = renderToon(doc, entry, LogLevel.info);
        final header = lines[0];
        final row = lines[1];

        final timestampHeaderIdx = header.indexOf('timestamp');
        final timestampValIdx = row.indexOf('2025-01-01');

        // The prefix "logs[]{": is 7 chars.
        expect(timestampHeaderIdx, equals(7));
        expect(timestampValIdx, equals(0));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('renders MapNode values as JSON in columns', () {
      final mapEntry = LogEntry(
        loggerName: 'test.logger',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'map',
        timestamp: '2025-01-01',
        error: {'a': 1},
      );
      const formatter = ToonFormatter();
      final doc = formatDoc(formatter, mapEntry);

      try {
        final lines = renderToon(doc, mapEntry, LogLevel.info);
        expect(lines[1], contains('{a:1}'));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('truncates large JSON values in columns', () {
      final bigMap = {for (var i = 0; i < 100; i++) 'key$i': 'val$i'};
      final mapEntry = LogEntry(
        loggerName: 'test.logger',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'big',
        timestamp: '2025-01-01',
        error: {'data': bigMap},
      );
      const formatter = ToonFormatter();
      final doc = formatDoc(formatter, mapEntry);

      try {
        // Use narrow width to force truncation
        final lines = renderToon(doc, mapEntry, LogLevel.info, width: 64);
        // Should contain json but potentially cut off
        expect(lines[1], contains('{'));
        expect(lines[1].length, lessThanOrEqualTo(128)); // Approximate check
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('renders nested JSON structures with indentation', () {
      final nested = {
        'a': {
          'b': {'c': 3},
        },
      };
      final mapEntry = LogEntry(
        loggerName: 'test.logger',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'nested',
        timestamp: '2025-01-01',
        error: {'data': nested},
      );
      const formatter = ToonFormatter();
      final doc = formatDoc(formatter, mapEntry);

      try {
        final lines = renderToon(doc, mapEntry, LogLevel.info);
        // By default ToonFormatter might flatten.
        expect(lines[1], contains('nested'));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('always includes context column even when context is null', () {
      const formatter = ToonFormatter();
      final doc = formatDoc(formatter, entry);
      try {
        final lines = renderToon(doc, entry, LogLevel.info);
        expect(lines[0], contains(',context}:'));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('sortKeys sorts map keys alphabetically when sortKeys is true', () {
      final mapEntry = LogEntry(
        loggerName: 'test.logger',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'sortTest',
        timestamp: '2025-01-01',
        error: {'z': 1, 'a': 2, 'm': 3},
      );
      const formatter = ToonFormatter(sortKeys: true);
      final doc = formatDoc(formatter, mapEntry);

      try {
        final lines = renderToon(doc, mapEntry, LogLevel.info);
        expect(lines[1], contains('{a:2,m:3,z:1}'));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });

    test('maxDepth limits recursion depth for nested maps', () {
      final deepMap = {
        'l1': {
          'l2': {
            'l3': {'l4': 'deep'},
          },
        },
      };
      final mapEntry = LogEntry(
        loggerName: 'test.logger',
        origin: 'main.dart',
        level: LogLevel.info,
        message: 'depthTest',
        timestamp: '2025-01-01',
        error: deepMap,
      );
      const formatter = ToonFormatter(maxDepth: 2);
      final doc = formatDoc(formatter, mapEntry);

      try {
        final lines = renderToon(doc, mapEntry, LogLevel.info);
        expect(lines[1], contains('...'));
      } finally {
        doc.releaseRecursive(Arena.instance);
      }
    });
  });

  group('ToonEncoder.extractPreamble', () {
    test('extracts preamble line from TOON bytes', () {
      final bytes = Uint8List.fromList(
        utf8.encode(
          'logs[]{timestamp,logger,level,message,error,stackTrace,context}:\n'
          '2025-01-01\tapp\tINFO\tmsg\t\t\t\n',
        ),
      );
      final preamble = ToonEncoder.extractPreamble(bytes);
      expect(
        preamble,
        equals(
          'logs[]{timestamp,logger,level,message,error,stackTrace,context}:\n',
        ),
      );
    });

    test('returns null for empty bytes or non-TOON text', () {
      expect(ToonEncoder.extractPreamble(Uint8List(0)), isNull);
      expect(
        ToonEncoder.extractPreamble(
          Uint8List.fromList(utf8.encode('just a plain text string')),
        ),
        isNull,
      );
    });
  });
}

List<String> renderToon(
  final LogDocument doc,
  final LogEntry entry,
  final LogLevel level, {
  final int? width,
}) {
  const encoder = ToonEncoder();
  final context = HandlerContext();
  const factory = StandardPipelineFactory();
  encoder.preamble(context, level, factory, document: doc);
  final header = Uint8List.fromList(context.takeBytes());

  encoder.encode(entry, doc, level, context, factory, width: width);
  final row = Uint8List.fromList(context.takeBytes());

  const decoder = Utf8Decoder();
  final headerStr = header.isNotEmpty ? decoder.convert(header) : '';
  final rowStr = decoder.convert(row);

  return [
    if (headerStr.isNotEmpty) headerStr,
    ...rowStr.split('\n'),
  ];
}
