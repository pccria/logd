import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:logd/logd.dart' hide IsolateSink;
import 'package:logd/src/handler/sink/isolate_sink_native.dart';
import 'package:test/test.dart';

base class FaultyTargetSink extends LogSink<Uint8List> {
  FaultyTargetSink(this.notifyPort);

  final SendPort notifyPort;
  int callCount = 0;

  @override
  Future<void> output(
    final Uint8List data,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    callCount++;
    if (callCount == 1) {
      throw StateError('Simulated target sink write failure on first call');
    }
    notifyPort.send(entry.message);
  }
}

void main() {
  final testEntry1 = LogEntry(
    loggerName: 'test',
    origin: 'main',
    level: LogLevel.info,
    message: 'First entry that throws',
    timestamp: '2026-11-02T00:00:00',
  );

  final testEntry2 = LogEntry(
    loggerName: 'test',
    origin: 'main',
    level: LogLevel.info,
    message: 'Second entry that should succeed',
    timestamp: '2026-11-02T00:00:01',
  );

  group('IsolateSink Error Resilience', () {
    test(
        'worker isolate survives an underlying sink output exception and '
        'processes next entry', () async {
      final receivePort = ReceivePort();
      final completer = Completer<String>();

      receivePort.listen((final message) {
        if (message is String && !completer.isCompleted) {
          completer.complete(message);
        }
      });

      final targetSink = FaultyTargetSink(receivePort.sendPort);
      final isolateSink = IsolateSink(targetSink);

      const factory = StandardPipelineFactory();
      final dummyBytes = Uint8List(4);

      // 1. First output throws inside the worker isolate
      await isolateSink.output(
        dummyBytes,
        testEntry1,
        LogLevel.info,
        factory,
      );

      // Brief delay to let the worker isolate process the first event
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // 2. Second output should still be processed by the worker isolate
      await isolateSink.output(
        dummyBytes,
        testEntry2,
        LogLevel.info,
        factory,
      );

      final result = await completer.future.timeout(const Duration(seconds: 3));
      expect(result, equals('Second entry that should succeed'));

      receivePort.close();
      await isolateSink.dispose();
    });
  });
}
