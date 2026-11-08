import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:logd/logd.dart';
import 'package:test/test.dart';

base class SlowTrackingSink extends LogSink<LogDocument> {
  SlowTrackingSink(this.notifyPort);

  final SendPort notifyPort;
  final List<String> received = [];
  bool flushed = false;
  bool disposed = false;
  int disposeCallCount = 0;

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    // Artificial latency to simulate I/O
    await Future<void>.delayed(const Duration(milliseconds: 20));
    received.add(entry.message);
    notifyPort.send('log:${entry.message}');
  }

  @override
  Future<void> flush() async {
    flushed = true;
    notifyPort.send('flushed');
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    disposeCallCount++;
    notifyPort.send('disposed');
  }
}

void main() {
  group('Lifecycle & Flush Contract', () {
    setUp(() {
      Logger.reset();
    });

    test('AsyncHandler.flush() awaits all in-flight logs before completing',
        () async {
      final receivePort = ReceivePort();
      final events = <String>[];
      receivePort.listen((final msg) {
        if (msg is String) {
          events.add(msg);
        }
      });

      final sink = SlowTrackingSink(receivePort.sendPort);
      final handler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
      );

      final logger = Logger.get('async_flush_test');
      Logger.configure('async_flush_test', handlers: [handler]);

      // Emit 3 logs rapidly
      logger
        ..info('Entry 1')
        ..info('Entry 2')
        ..info('Entry 3');

      // flush() must ensure all entries are processed and sink.flush() called
      await handler.flush();

      expect(events, contains('log:Entry 1'));
      expect(events, contains('log:Entry 2'));
      expect(events, contains('log:Entry 3'));
      expect(events, contains('flushed'));

      await handler.dispose();
      receivePort.close();
    });

    test('Logger.flush() coordinates flushing across all registered handlers',
        () async {
      final receivePort = ReceivePort();
      final events = <String>[];
      receivePort.listen((final msg) {
        if (msg is String) {
          events.add(msg);
        }
      });

      final sink = SlowTrackingSink(receivePort.sendPort);
      final handler = AsyncHandler(
        formatter: const PlainFormatter(),
        sink: sink,
      );

      final logger = Logger.get('global_flush_test');
      Logger.configure('global_flush_test', handlers: [handler]);

      logger
        ..info('Global 1')
        ..info('Global 2');

      await Logger.flush();

      expect(events, contains('log:Global 1'));
      expect(events, contains('log:Global 2'));
      expect(events, contains('flushed'));

      await Logger.shutdown();
      receivePort.close();
    });

    test('IsolateSink.flush() drains in-flight items before completing',
        () async {
      final receivePort = ReceivePort();
      final events = <String>[];
      receivePort.listen((final msg) {
        if (msg is String) {
          events.add(msg);
        }
      });

      final targetSink = SlowByteSink(receivePort.sendPort);
      final isolateSink = IsolateSink(targetSink);

      final dummyEntry = LogEntry(
        loggerName: 'test',
        origin: 'main',
        level: LogLevel.info,
        message: 'Isolate Item',
        timestamp: 'now',
      );
      const factory = StandardPipelineFactory();

      await isolateSink.output(
        Uint8List(2),
        dummyEntry,
        LogLevel.info,
        factory,
      );

      await isolateSink.flush();

      expect(events, contains('byte-flushed'));

      await isolateSink.dispose();
      receivePort.close();
    });

    test('logger.flushHandlers() drains specific logger handlers', () async {
      final receivePort = ReceivePort();
      final events = <String>[];
      receivePort.listen((final msg) {
        if (msg is String) {
          events.add(msg);
        }
      });

      final sink = SlowTrackingSink(receivePort.sendPort);
      final handler = Handler(
        formatter: const PlainFormatter(),
        sink: sink,
      );

      final logger = Logger.get('instance_flush_test');
      Logger.configure('instance_flush_test', handlers: [handler]);

      logger.info('Instance Msg');
      await logger.flushHandlers();
      expect(sink.flushed, isTrue);
      receivePort.close();
    });

    test('Handler.dispose() disposes underlying sink', () async {
      final receivePort = ReceivePort();
      final sink = SlowTrackingSink(receivePort.sendPort);
      final handler = Handler(
        formatter: const PlainFormatter(),
        sink: sink,
      );

      expect(sink.disposed, isFalse);
      await handler.dispose();
      expect(sink.disposed, isTrue);
      expect(sink.disposeCallCount, equals(1));
      receivePort.close();
    });

    test('Logger.shutdown() disposes plain handler sinks', () async {
      final receivePort = ReceivePort();
      final sink = SlowTrackingSink(receivePort.sendPort);
      final handler = Handler(
        formatter: const PlainFormatter(),
        sink: sink,
      );

      Logger.configure('shutdown_sink_test', handlers: [handler]);
      await Logger.shutdown();

      expect(sink.flushed, isTrue);
      expect(sink.disposed, isTrue);
      receivePort.close();
    });

    test(
      'reconfiguring with a shared sink does not dispose sink and delivers '
      'entries',
      () async {
        final receivePort = ReceivePort();
        final s = SlowTrackingSink(receivePort.sendPort);
        final handlerA = Handler(
          formatter: const PlainFormatter(),
          sink: s,
        );

        Logger.configure('shared_sink_test', handlers: [handlerA]);

        final handlerB = Handler(
          formatter: const StructuredFormatter(),
          sink: s,
        );

        // Reconfigure with Handler B sharing sink s
        Logger.configure('shared_sink_test', handlers: [handlerB]);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          s.disposed,
          isFalse,
          reason: 'shared sink must not be disposed',
        );

        Logger.get('shared_sink_test').info('entry via handler B');

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await Logger.flush();

        expect(s.disposed, isFalse);
        expect(s.received, contains('entry via handler B'));

        receivePort.close();
      },
    );

    test(
      'a displaced handler with an unshared sink IS disposed',
      () async {
        final receivePort = ReceivePort();
        final sink1 = SlowTrackingSink(receivePort.sendPort);
        final handler1 = Handler(
          formatter: const PlainFormatter(),
          sink: sink1,
        );

        Logger.configure('unshared_sink_test', handlers: [handler1]);

        final sink2 = SlowTrackingSink(receivePort.sendPort);
        final handler2 = Handler(
          formatter: const PlainFormatter(),
          sink: sink2,
        );

        // Reconfigure replaces handler1 with handler2 (unshared sink)
        Logger.configure('unshared_sink_test', handlers: [handler2]);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          sink1.disposed,
          isTrue,
          reason: 'displaced handler with unshared sink must be disposed',
        );
        expect(
          sink2.disposed,
          isFalse,
          reason: 'active handler sink must not be disposed',
        );

        receivePort.close();
      },
    );

    test('Logger.reset() disposes registered handlers', () async {
      final receivePort = ReceivePort();
      final sink = SlowTrackingSink(receivePort.sendPort);
      final handler = Handler(
        formatter: const PlainFormatter(),
        sink: sink,
      );

      Logger.configure('reset_dispose_test', handlers: [handler]);
      Logger.reset('reset_dispose_test');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        sink.disposed,
        isTrue,
        reason: 'handler sink should be disposed when logger is reset',
      );

      receivePort.close();
    });
  });
}

base class SlowByteSink extends LogSink<Uint8List> {
  SlowByteSink(this.notifyPort);

  final SendPort notifyPort;

  @override
  Future<void> output(
    final Uint8List data,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  @override
  Future<void> flush() async {
    notifyPort.send('byte-flushed');
  }
}
