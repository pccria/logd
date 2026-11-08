import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:logd/logd.dart' hide NativeIsolateSink;
import 'package:logd/src/handler/sink/isolate_sink_native.dart';
import 'package:test/test.dart';

base class ResilienceTestEncodingSink extends EncodingSink {
  ResilienceTestEncodingSink(this.sendPort)
      : super(
          encoder: const PlainTextEncoder(),
          delegate: ResilienceTestEncodingSink.workerWrite,
        );

  final SendPort sendPort;
  static SendPort? activeSendPort;
  static int callCount = 0;

  @override
  FutureOr<void> Function(Uint8List) get delegate {
    activeSendPort = sendPort;
    return ResilienceTestEncodingSink.workerWrite;
  }

  static void workerWrite(final Uint8List data) {
    activeSendPort?.send(data);
    callCount++;
    if (callCount == 1) {
      throw StateError('Simulated delegate exception on first write');
    }
  }
}

void main() {
  final testEntry = LogEntry(
    loggerName: 'test',
    origin: 'main',
    level: LogLevel.info,
    message: 'test entry',
    timestamp: '2026-11-02T00:00:00',
  );

  group('Native Worker Delegate Error Resilience', () {
    test(
      'worker survives downstream sink delegate exception and processes '
      'subsequent logs',
      () async {
        final receivePort = ReceivePort();
        final receivedList = <String>[];
        final completer = Completer<void>();

        receivePort.listen((final data) {
          if (data is Uint8List) {
            receivedList.add(String.fromCharCodes(data));
            if (receivedList.length == 2) {
              completer.complete();
            }
          }
        });

        final targetSink = ResilienceTestEncodingSink(receivePort.sendPort);
        final isolateSink = NativeIsolateSink(targetSink);

        // Wait until isolate is ready
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(isolateSink.workerDead, isFalse);

        const factory = StandardPipelineFactory();

        // 1. First log triggers delegate exception inside the worker
        final doc1 = factory.checkoutDocument()..text('first message');
        await isolateSink.output(doc1, testEntry, LogLevel.info, factory);

        // Wait a moment for worker to process first message
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // The worker isolate should NOT die from the downstream delegate error
        expect(isolateSink.workerDead, isFalse);

        // 2. Second log should succeed through the same worker isolate
        final doc2 = factory.checkoutDocument()..text('second message');
        await isolateSink.output(doc2, testEntry, LogLevel.info, factory);

        await completer.future.timeout(const Duration(seconds: 3));

        expect(receivedList.length, equals(2));
        expect(receivedList[0], contains('first message'));
        expect(receivedList[1], contains('second message'));
        expect(isolateSink.workerDead, isFalse);

        receivePort.close();
        await isolateSink.dispose();
      },
    );
  });
}
