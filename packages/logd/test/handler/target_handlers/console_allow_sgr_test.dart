import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logd/logd.dart';
import 'package:test/test.dart';

class _CapturingStdout implements Stdout {
  final List<int> bytes = [];

  @override
  void add(final List<int> data) {
    bytes.addAll(data);
  }

  @override
  void write(final Object? object) {
    if (object != null) {
      bytes.addAll(utf8.encode(object.toString()));
    }
  }

  @override
  void writeln([final Object? object = '']) {
    write(object);
    write('\n');
  }

  @override
  bool get hasTerminal => true;

  @override
  bool get supportsAnsiEscapes => true;

  @override
  int get terminalColumns => 80;

  @override
  Future<void> flush() async {}

  @override
  dynamic noSuchMethod(final Invocation invocation) => null;
}

void main() {
  group('F-78: allowSgr option in ConsoleHandler and ConsoleSink', () {
    const rawAnsi = '\u001B[31mred\u001B[0m';
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_sgr_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'default false neutralizes \\u001B[31mred\\u001B[0m in ConsoleHandler',
      () async {
        final mockStdout = _CapturingStdout();
        final capturedPrint = <String>[];
        final handler = ConsoleHandler();
        Logger.configure('test.console.default', handlers: [handler]);

        await IOOverrides.runZoned(
          () async {
            await runZoned(
              () async {
                Logger.get('test.console.default').info(rawAnsi);
                await handler.flush();
              },
              zoneSpecification: ZoneSpecification(
                print: (final self, final parent, final zone, final line) {
                  capturedPrint.add(line);
                },
              ),
            );
          },
          stdout: () => mockStdout,
        );

        await handler.dispose();

        final output = mockStdout.bytes.isNotEmpty
            ? utf8.decode(mockStdout.bytes)
            : capturedPrint.join('\n');
        expect(output, isNotEmpty);
        expect(output, contains('^[[31mred^[[0m'));
        expect(output, isNot(contains(rawAnsi)));
      },
    );

    test(
      'with allowSgr: true the console output keeps codes in ConsoleHandler',
      () async {
        final mockStdout = _CapturingStdout();
        final capturedPrint = <String>[];
        final handler = ConsoleHandler(allowSgr: true);
        Logger.configure('test.console.allowsgr', handlers: [handler]);

        await IOOverrides.runZoned(
          () async {
            await runZoned(
              () async {
                Logger.get('test.console.allowsgr').info(rawAnsi);
                await handler.flush();
              },
              zoneSpecification: ZoneSpecification(
                print: (final self, final parent, final zone, final line) {
                  capturedPrint.add(line);
                },
              ),
            );
          },
          stdout: () => mockStdout,
        );

        await handler.dispose();

        final output = mockStdout.bytes.isNotEmpty
            ? utf8.decode(mockStdout.bytes)
            : capturedPrint.join('\n');
        expect(output, isNotEmpty);
        expect(output, contains(rawAnsi));
      },
    );

    test(
      'ConsoleSink respects allowSgr: false and allowSgr: true directly',
      () async {
        const factory = StandardPipelineFactory();
        final entry = LogEntry(
          level: LogLevel.info,
          message: rawAnsi,
          loggerName: 'test.sink',
          origin: 'test',
          timestamp: '2026-11-07T00:00:00Z',
        );

        // Default (allowSgr: false)
        const defaultSink = ConsoleSink(usePrint: true);
        final defaultCaptured = <String>[];
        final doc1 = StandardDocument()
          ..nodes.add(MessageNode(segments: [const StyledText(rawAnsi)]));
        await runZoned(
          () async {
            await defaultSink.output(doc1, entry, LogLevel.info, factory);
          },
          zoneSpecification: ZoneSpecification(
            print: (final self, final parent, final zone, final line) {
              defaultCaptured.add(line);
            },
          ),
        );
        expect(defaultCaptured.join('\n'), contains('^[[31mred^[[0m'));
        expect(defaultCaptured.join('\n'), isNot(contains(rawAnsi)));

        // With allowSgr: true
        const sgrSink = ConsoleSink(allowSgr: true, usePrint: true);
        final sgrCaptured = <String>[];
        final doc2 = StandardDocument()
          ..nodes.add(MessageNode(segments: [const StyledText(rawAnsi)]));
        await runZoned(
          () async {
            await sgrSink.output(doc2, entry, LogLevel.info, factory);
          },
          zoneSpecification: ZoneSpecification(
            print: (final self, final parent, final zone, final line) {
              sgrCaptured.add(line);
            },
          ),
        );
        expect(sgrCaptured.join('\n'), contains(rawAnsi));
      },
    );

    test(
      'PlainFileHandler is unaffected either way (neutralizes ANSI codes)',
      () async {
        final filePath = '${tempDir.path}/plain.log';
        final handler = PlainFileHandler(path: filePath);
        Logger.configure('test.plain.file', handlers: [handler]);

        Logger.get('test.plain.file').info(rawAnsi);
        await handler.flush();
        await handler.dispose();

        final fileContent = File(filePath).readAsStringSync();
        expect(fileContent, contains('^[[31mred^[[0m'));
        expect(fileContent, isNot(contains(rawAnsi)));
      },
    );
  });
}
