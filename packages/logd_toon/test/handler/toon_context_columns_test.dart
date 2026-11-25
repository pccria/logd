import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

void main() {
  group('ToonFormatter contextColumns & Handler Parity Tests', () {
    test('extracts configured contextColumns as dedicated columns', () {
      const formatter = ToonFormatter(
        metadata: {LogMetadata.timestamp},
        contextColumns: ['traceId', 'userId'],
      );

      final entry = LogEntry(
        loggerName: 'orders',
        origin: 'main',
        level: LogLevel.info,
        message: 'Order created',
        timestamp: '2026-11-25T15:00:00.000',
        context: {'traceId': 'tr-9942', 'userId': 'usr-101', 'amount': 45.99},
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

      final output = context.toString();
      expect(
        output,
        contains(
          'logs[]{timestamp,level,message,error,stackTrace,traceId,userId,context}:',
        ),
      );
      expect(output, contains('tr-9942\tusr-101'));
    });

    test('maintains column invariance when entries lack context keys', () {
      const formatter = ToonFormatter(
        metadata: {LogMetadata.timestamp},
        contextColumns: ['traceId', 'userId'],
        dialect: ToonDialect.strict,
      );

      final entryWithoutKeys = LogEntry(
        loggerName: 'orders',
        origin: 'main',
        level: LogLevel.info,
        message: 'Order created without trace',
        timestamp: '2026-11-25T15:00:00.000',
        context: {'otherKey': 'val'},
      );

      final doc = StandardDocument();
      formatter.format(entryWithoutKeys, doc, const StandardPipelineFactory());

      const encoder = ToonEncoder();
      final context = HandlerContext();
      encoder.preamble(
        context,
        LogLevel.info,
        const StandardPipelineFactory(),
        document: doc,
      );
      encoder.encode(
        entryWithoutKeys,
        doc,
        LogLevel.info,
        context,
        const StandardPipelineFactory(),
      );

      final output = context.toString();
      // In strict mode, absent traceId and userId should emit \N
      expect(output, contains(r'\N'));
    });

    test('ToonFileHandler exposes full parameter parity', () async {
      final tempDir = await Directory.systemTemp.createTemp('toon_test');
      final filePath = '${tempDir.path}/test.toon';

      try {
        final handler = ToonFileHandler(
          path: filePath,
          delimiter: '\t',
          arrayName: 'app_events',
          metadata: {LogMetadata.logger},
          sortKeys: true,
          maxDepth: 3,
          contextColumns: ['reqId'],
        );

        final asyncHand = ToonFileHandler.async(
          path: filePath,
          delimiter: '\t',
          arrayName: 'async_events',
          metadata: {LogMetadata.logger},
          sortKeys: true,
          maxDepth: 3,
          contextColumns: ['reqId'],
        );

        expect(handler, isNotNull);
        expect(asyncHand, isNotNull);

        await handler.dispose();
        await asyncHand.dispose();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
