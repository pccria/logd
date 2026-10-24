import 'dart:convert';
import 'dart:ffi' as ffi;

import 'package:logd/logd.dart'
    hide Arena, ArenaDocument, ArenaEngine, FileSink, IsolateSink, NativeEngine;
import 'package:logd/src/handler/document/binary_ir_native.dart';
import 'package:logd/src/handler/engine/arena_native.dart';
import 'package:logd/src/handler/engine/native_engine_native.dart';
import 'package:test/test.dart';

void main() {
  group('Arena & BinaryIR Memory Safety Tests', () {
    late Arena arena;

    setUp(() {
      arena = Arena.instance..clear();
    });

    tearDown(() {
      arena.clear();
    });

    test('Arena.clear() properly resets totalAllocatedBytes to zero', () {
      expect(arena.totalAllocatedBytes, equals(0));

      final doc = (arena.checkoutDocument() as ArenaDocument)
        ..text('Testing memory allocation counter');
      final writer = BinaryIRWriter(doc);
      final ptr = writer.write(doc);

      expect(ptr, isNotNull);
      expect(arena.totalAllocatedBytes, greaterThan(0));

      doc.releaseRecursive(arena);
      arena.clear();

      expect(arena.totalAllocatedBytes, equals(0));
    });

    test(
      'Buffer dynamically grows when document exceeds 64KB chunk size '
      'and decodes accurately',
      () {
        final doc = arena.checkoutDocument() as ArenaDocument;

        // Generate text larger than default 64KB packet size (~80KB total)
        final chunk = 'A' * 1024;
        for (int i = 0; i < 80; i++) {
          doc.text('[$i]: $chunk\n');
        }

        final writer = BinaryIRWriter(doc);
        final irPtr = writer.write(doc);

        expect(irPtr, isNotNull);

        // Verify Header magic & total length
        expect(irPtr.cast<ffi.Uint32>()[0], equals(BinaryIR.magic));
        final nodeCount = irPtr.cast<ffi.Uint32>()[2];
        final totalLength = irPtr.cast<ffi.Uint32>()[3];

        expect(nodeCount, equals(80));
        expect(totalLength, greaterThan(64 * 1024));

        // Decode using BinaryAnsiEncoder
        const encoder = BinaryAnsiEncoder();
        final output = encoder.encode(irPtr, terminalWidth: 120);

        // Verify that all 80 chunks are present from first to last
        expect(output.contains('[0]:'), isTrue);
        expect(output.contains('[40]:'), isTrue);
        expect(output.contains('[79]:'), isTrue);

        doc.releaseRecursive(arena);
      },
    );

    test('BinaryAnsiEncoder respects length boundary on truncated buffer', () {
      final doc = (arena.checkoutDocument() as ArenaDocument)
        ..text('First line\n')
        ..text('Second line\n')
        ..text('Third line\n');

      final writer = BinaryIRWriter(doc);
      final irPtr = writer.write(doc);
      final totalLength = irPtr.cast<ffi.Uint32>()[3];
      expect(totalLength, greaterThan(0));

      const encoder = BinaryAnsiEncoder();

      // Full decode
      final fullOutput = encoder.encode(irPtr, terminalWidth: 80);
      expect(fullOutput, contains('First line'));
      expect(fullOutput, contains('Second line'));
      expect(fullOutput, contains('Third line'));

      // Truncated decode with an artificially restricted length boundary
      // Should terminate safely without reading out of bounds
      final partialOutput = encoder.encode(
        irPtr,
        terminalWidth: 80,
        length: BinaryIR.headerSize +
            24, // only enough for header + partial first node
      );
      expect(partialOutput, isA<String>());

      doc.releaseRecursive(arena);
    });

    test('Eviction from free pool prevents false OutOfMemoryError under churn',
        () {
      // Allocate and release buffers repeatedly
      for (int i = 0; i < 50; i++) {
        final doc = (arena.checkoutDocument() as ArenaDocument)
          ..text('M' * (32 * 1024));
        BinaryIRWriter(doc).write(doc);
        doc.releaseRecursive(arena);
      }

      // Memory allocated should stay well within the 128MB ceiling
      expect(arena.totalAllocatedBytes, lessThan(Arena.maxNativeMemory));
    });

    test(
        'NativeEngine safely handles multi-kilobyte log entry (>64KB) '
        'end-to-end', () async {
      final sinkChunks = <List<int>>[];
      final sink = EncodingSink(
        encoder: const AnsiEncoder(),
        preferredWidth: 100,
        delegate: (final data) => sinkChunks.add(data),
      );

      final handler = Handler(
        formatter: const PlainFormatter(),
        sink: sink,
        engine: NativeEngine(),
      );

      final hugeMessage =
          List.generate(70, (final i) => 'Line $i: ${"X" * 1000}').join('\n');
      final entry = LogEntry(
        level: LogLevel.info,
        message: hugeMessage,
        loggerName: 'test.native',
        timestamp: '2026-10-23 00:00:00',
        origin: 'arena_memory_safety_test.dart',
      );

      await handler.log(entry);

      final fullOutput =
          utf8.decode(sinkChunks.expand((final b) => b).toList());
      expect(fullOutput, contains('Line 0:'));
      expect(fullOutput, contains('Line 35:'));
      expect(fullOutput, contains('Line 69:'));
    });
  });
}
