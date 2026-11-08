import 'dart:convert';
import 'dart:io' as io;

import 'package:logd/logd.dart';
import 'package:logd/src/core/context/clock/clock.dart';
import 'package:logd/src/core/context/context.dart';
import 'package:logd/testing.dart';
import 'package:test/test.dart';

import '../handler/test_helpers.dart';

class _CustomNonJsonModel {
  _CustomNonJsonModel(this.id, this.label);
  final int id;
  final String label;

  @override
  String toString() => 'Model($id: $label)';
}

class _TestClock implements Clock {
  _TestClock(this._now);
  DateTime _now;

  void advance(final Duration duration) {
    _now = _now.add(duration);
  }

  @override
  DateTime get now => _now;

  @override
  String? get timezoneName => 'Etc/UTC';
}

void main() {
  group('0.10.6 Regression Suite (Resilience & Serialization)', () {
    tearDown(() {
      Logger.reset();
      Context.reset();
    });

    test(
      'entries with unparseable/stripped stack traces are not dropped',
      () async {
        final testLogger = TestLogger('test.stripped');
        addTearDown(testLogger.dispose);

        // Simulate a stripped stack trace from --split-debug-info / --obfuscate:
        final strippedTrace = StackTrace.fromString(
          '#00 abs 0000007b8971f1 virt 00000000000411f1 '
          '_kDartIsolateSnapshotInstructions+0x411f1\n'
          '#01 abs 0000007b897250 virt 0000000000041250 '
          '_kDartIsolateSnapshotInstructions+0x41250',
        );

        testLogger.logger.error(
          'critical error in release build',
          stackTrace: strippedTrace,
        );

        // Give microtasks a turn to drain
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(testLogger.logs, hasLength(1));
        expect(
          testLogger.logs.first.message,
          equals('critical error in release build'),
        );
        expect(testLogger.logs.first.origin, equals('unknown'));
      },
    );

    test(
      'JsonEncoder serializes non-JSON-native objects without throwing',
      () {
        final context = HandlerContext();
        const encoder = JsonEncoder();

        final now = DateTime.utc(2026, 11, 1, 23, 30);
        final entry = Arena.instance.checkoutLogEntry(
          loggerName: 'test.json',
          level: LogLevel.info,
          message: 'hello json',
          timestamp: '2026-11-01',
          origin: 'main',
          context: {
            'time': now,
            'level': LogLevel.info,
            'uri': Uri.parse('https://example.com/api?q=1'),
            'custom': _CustomNonJsonModel(42, 'test'),
          },
        );

        final doc = Arena.instance.checkoutDocument();
        const formatter = JsonFormatter();
        formatter.format(entry, doc, Arena.instance);

        expect(
          () => encoder.encode(
            entry,
            doc,
            LogLevel.info,
            context,
            Arena.instance,
          ),
          returnsNormally,
        );

        final bytes = context.takeBytes();
        final output = utf8.decode(bytes);
        final decoded = jsonDecode(output) as Map<String, dynamic>;
        expect(decoded['message'], equals('hello json'));
        final decodedCtx = decoded['context'] as Map<String, dynamic>;
        expect(decodedCtx['time'], equals(now.toIso8601String()));
        expect(decodedCtx['level'], equals('info'));
        expect(decodedCtx['uri'], equals('https://example.com/api?q=1'));
        expect(decodedCtx['custom'], equals('Model(42: test)'));

        doc.releaseRecursive(Arena.instance);
        Arena.instance.releaseLogEntry(entry);
      },
    );

    test(
      'SizeRotation cleanup does not delete sibling log files',
      () async {
        final tempDir =
            await io.Directory.systemTemp.createTemp('logd_f39_test');
        addTearDown(() => tempDir.delete(recursive: true));

        final sep = io.Platform.pathSeparator;
        final appLogPath = '${tempDir.path}${sep}app.log';
        final siblingErrorLogPath = '${tempDir.path}${sep}app_error.log';
        final siblingErrorBackup1 = '${tempDir.path}${sep}app_error.1.log';
        final siblingErrorBackup2 = '${tempDir.path}${sep}app_error.2.log';

        // Create sibling files
        await io.File(siblingErrorLogPath).writeAsString('error active log');
        await io.File(siblingErrorBackup1).writeAsString('error backup 1');
        await io.File(siblingErrorBackup2).writeAsString('error backup 2');

        // Create app.log and rotate it past backupCount
        final rotation = SizeRotation(
          maxSize: '10 B',
          backupCount: 1,
          compress: false,
        );

        final sink = FileSink(
          appLogPath,
          fileRotation: rotation,
        );

        final entry = LogEntry(
          loggerName: 'test',
          level: LogLevel.info,
          message: 'log entry overflowing',
          timestamp: '2026-11-01',
          origin: 'main',
        );

        // Write enough times to trigger rotation and excess cleanup
        for (int i = 0; i < 5; i++) {
          final doc =
              createTestDocument(['Log entry $i - overflowing 10 bytes']);
          await sink.output(
            doc,
            entry,
            LogLevel.info,
            const StandardPipelineFactory(),
          );
          doc.releaseRecursive(Arena.instance);
        }

        // Sibling files must NOT be touched or deleted
        expect(
          await io.File(siblingErrorLogPath).exists(),
          isTrue,
          reason: 'app_error.log was deleted!',
        );
        expect(
          await io.File(siblingErrorBackup1).exists(),
          isTrue,
          reason: 'app_error.1.log was deleted!',
        );
        expect(
          await io.File(siblingErrorBackup2).exists(),
          isTrue,
          reason: 'app_error.2.log was deleted!',
        );
      },
    );

    test(
      'TimeRotation rotates when interval elapses under '
      'continuous logging',
      () async {
        final tempDir =
            await io.Directory.systemTemp.createTemp('logd_f40_test');
        addTearDown(() => tempDir.delete(recursive: true));

        final sep = io.Platform.pathSeparator;
        final appLogPath = '${tempDir.path}${sep}time_app.log';

        final clock = _TestClock(DateTime(2026, 11, 1, 12));
        Context.setClock(clock);

        final timeRotation = TimeRotation(
          interval: const Duration(hours: 1),
          backupCount: 5,
          compress: false,
        );

        final sink = FileSink(
          appLogPath,
          fileRotation: timeRotation,
        );

        final entry = LogEntry(
          loggerName: 'test',
          level: LogLevel.info,
          message: 'msg',
          timestamp: '2026-11-01',
          origin: 'main',
        );

        // Write initial log
        final doc1 = createTestDocument(['First log at 12:00']);
        await sink.output(
          doc1,
          entry,
          LogLevel.info,
          const StandardPipelineFactory(),
        );
        doc1.releaseRecursive(Arena.instance);

        // Continuous logging: simulate writes every 10 minutes for 2 hours
        for (int i = 1; i <= 12; i++) {
          clock.advance(const Duration(minutes: 10));
          final doc = createTestDocument(['Log at minute ${i * 10}']);
          await sink.output(
            doc,
            entry,
            LogLevel.info,
            const StandardPipelineFactory(),
          );
          doc.releaseRecursive(Arena.instance);
        }

        // Check rotated files in directory
        final entities = await tempDir.list().toList();
        final rotatedFiles = entities.where(
          (final e) => e is io.File && e.path.contains('time_app-'),
        );

        expect(
          rotatedFiles.isNotEmpty,
          isTrue,
          reason: 'TimeRotation never rotated under continuous logging!',
        );
      },
    );
  });
}
