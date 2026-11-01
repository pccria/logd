import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart' hide Arena;
import 'package:logd/logd.dart'
    hide Arena, ArenaDocument, ArenaEngine, FileSink, IsolateSink, NativeEngine;
import 'package:logd/src/handler/document/binary_ir_native.dart';
import 'package:logd/src/handler/engine/arena_native.dart';
import 'package:test/test.dart';

void main() {
  group('Binary IR Bounds & Format Resilience', () {
    test('BinaryAnsiEncoder throws FormatException on invalid magic bytes', () {
      final ptr = calloc<ffi.Uint8>(32);
      try {
        ptr.cast<ffi.Uint32>()[0] = 0xDEADBEEF; // Invalid magic
        ptr.cast<ffi.Uint32>()[2] = 1;
        ptr.cast<ffi.Uint32>()[3] = 32;

        const encoder = BinaryAnsiEncoder();
        expect(
          () => encoder.encode(ptr, terminalWidth: 80),
          throwsA(isA<FormatException>()),
        );
      } finally {
        calloc.free(ptr);
      }
    });

    test('BinaryToonEncoder throws FormatException on invalid magic bytes', () {
      final ptr = calloc<ffi.Uint8>(32);
      try {
        ptr.cast<ffi.Uint32>()[0] = 0xDEADBEEF; // Invalid magic
        ptr.cast<ffi.Uint32>()[2] = 1;
        ptr.cast<ffi.Uint32>()[3] = 32;

        const encoder = BinaryToonEncoder();
        expect(
          () => encoder.encode(ptr),
          throwsA(isA<FormatException>()),
        );
      } finally {
        calloc.free(ptr);
      }
    });

    test('BinaryAnsiEncoder throws FormatException on unrecognized opcode', () {
      final ptr = calloc<ffi.Uint8>(32);
      try {
        ptr.cast<ffi.Uint32>()[0] = BinaryIR.magic;
        ptr.cast<ffi.Uint16>()[2] = BinaryIR.version;
        ptr.cast<ffi.Uint32>()[2] = 1; // 1 node
        ptr.cast<ffi.Uint32>()[3] = 32; // total length

        // OpCode at offset 16 is 0xFE (unrecognized)
        ptr[16] = 0xFE;

        const encoder = BinaryAnsiEncoder();
        expect(
          () => encoder.encode(ptr, terminalWidth: 80),
          throwsA(isA<FormatException>()),
        );
      } finally {
        calloc.free(ptr);
      }
    });

    test('BinaryToonEncoder throws FormatException on unrecognized opcode', () {
      final ptr = calloc<ffi.Uint8>(32);
      try {
        ptr.cast<ffi.Uint32>()[0] = BinaryIR.magic;
        ptr.cast<ffi.Uint16>()[2] = BinaryIR.version;
        ptr.cast<ffi.Uint32>()[2] = 1; // 1 node
        ptr.cast<ffi.Uint32>()[3] = 32; // total length

        // OpCode at offset 16 is 0xFE (unrecognized)
        ptr[16] = 0xFE;

        const encoder = BinaryToonEncoder();
        expect(
          () => encoder.encode(ptr),
          throwsA(isA<FormatException>()),
        );
      } finally {
        calloc.free(ptr);
      }
    });

    test('BinaryToonEncoder safely parses metadata without out-of-bounds reads',
        () {
      final arena = Arena.instance..clear();
      final doc = arena.checkoutDocument() as ArenaDocument;
      doc.metadata['toon_columns'] = ['id', 'message'];
      doc.metadata['toon_array'] = 'events';

      doc.writeNode(
        MapNode(
          {'id': '101', 'message': 'first entry'},
        ),
      );

      final writer = BinaryIRWriter(doc);
      final ptr = writer.write(doc);

      const toonEncoder = BinaryToonEncoder();
      final output = toonEncoder.encode(ptr);

      expect(output, contains('events[]id,message:'));
      expect(output, contains('101'));
      expect(output, contains('first entry'));

      doc.releaseRecursive(arena);
    });
  });
}
