import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:logd/logd.dart' hide NativeIsolateSink;
import 'package:logd/src/handler/sink/isolate_sink_native.dart';
import 'package:test/test.dart';

base class TestEncodingSink extends EncodingSink {
  TestEncodingSink(this.sendPort)
      : super(
          encoder: const PlainTextEncoder(),
          delegate: TestEncodingSink.staticWrite,
        );

  final SendPort sendPort;

  static SendPort? activeSendPort;

  @override
  FutureOr<void> Function(Uint8List) get delegate {
    activeSendPort = sendPort;
    return TestEncodingSink.staticWrite;
  }

  static void staticWrite(final Uint8List data) {
    if (data.length == 1 && data.first == 255) {
      Future.microtask(
        () => throw Exception('Simulated crash in worker delegate'),
      );
      return;
    }
    activeSendPort?.send(data);
  }
}

void main() {
  final testEntry = LogEntry(
    loggerName: 'test',
    origin: 'main',
    level: LogLevel.info,
    message: 'msg',
    timestamp: '2025-01-01',
  );

  group('NativeIsolateSink Stabilization', () {
    test('normal logging works through NativeIsolateSink', () async {
      final receivePort = ReceivePort();
      final completer = Completer<Uint8List>();
      receivePort.listen((final data) {
        if (data is Uint8List && !completer.isCompleted) {
          completer.complete(data);
        }
      });

      final delegateSink = TestEncodingSink(receivePort.sendPort);
      final isolateSink = NativeIsolateSink(delegateSink);

      const factory = StandardPipelineFactory();
      final doc = factory.checkoutDocument()..text('hello isolate');

      await isolateSink.output(doc, testEntry, LogLevel.info, factory);

      final result = await completer.future.timeout(const Duration(seconds: 3));
      expect(String.fromCharCodes(result), contains('hello isolate'));

      receivePort.close();
      await isolateSink.dispose();
    });

    test('pre-ready buffer is capped at 200 and drops oldest log entries',
        () async {
      final receivePort = ReceivePort();
      final receivedData = <Uint8List>[];
      final completer = Completer<void>();

      receivePort.listen((final data) {
        if (data is Uint8List) {
          receivedData.add(data);
          if (receivedData.length == 200) {
            completer.complete();
          }
        }
      });

      final delegateSink = TestEncodingSink(receivePort.sendPort);
      final isolateSink = NativeIsolateSink(delegateSink);

      const factory = StandardPipelineFactory();

      // Send 250 Uint8List logs immediately
      for (var i = 0; i < 250; i++) {
        final bytes = Uint8List(1)..first = i;
        await isolateSink.output(bytes, testEntry, LogLevel.info, factory);
      }

      // Wait for the 200 logs to be processed
      await completer.future.timeout(const Duration(seconds: 5));

      expect(receivedData.length, 200);
      // The oldest 50 (indices 0 to 49) should have been dropped.
      expect(receivedData.first.first, 50);
      expect(receivedData.last.first, 249);

      receivePort.close();
      await isolateSink.dispose();
    });

    test('worker crash is detected and automatically recovered', () async {
      final receivePort = ReceivePort();
      final completer = Completer<Uint8List>();
      receivePort.listen((final data) {
        if (data is Uint8List && !completer.isCompleted) {
          completer.complete(data);
        }
      });

      final delegateSink = TestEncodingSink(receivePort.sendPort);
      final isolateSink = NativeIsolateSink(delegateSink);

      // Wait until isolate is ready
      await Future.delayed(const Duration(milliseconds: 200));
      expect(isolateSink.workerDead, isFalse);

      final oldIsolate = isolateSink.isolate;
      expect(oldIsolate, isNotNull);

      // Log a special message containing 255 to trigger the crash in worker
      // isolate.
      const factory = StandardPipelineFactory();
      final triggerBytes = Uint8List(1)..first = 255;
      await isolateSink.output(triggerBytes, testEntry, LogLevel.info, factory);

      // Wait for error handler to run
      await Future.delayed(const Duration(milliseconds: 200));
      expect(isolateSink.workerDead, isTrue);

      // Wait for restart (2 seconds retry interval + some startup latency)
      await Future.delayed(const Duration(milliseconds: 2200));
      expect(isolateSink.workerDead, isFalse);
      expect(isolateSink.isolate, isNot(equals(oldIsolate)));

      // Verify log works on recovered worker
      final doc2 = factory.checkoutDocument()..text('recovered log');
      await isolateSink.output(doc2, testEntry, LogLevel.info, factory);

      final result = await completer.future.timeout(const Duration(seconds: 3));
      expect(String.fromCharCodes(result), contains('recovered log'));

      receivePort.close();
      await isolateSink.dispose();
    });
  });
}
