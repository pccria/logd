// ignore_for_file: invalid_use_of_internal_member, implementation_imports
import 'dart:async';
import 'dart:developer';
import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:vm_service/vm_service_io.dart';

const int iterations = 10000;

final entry = LogEntry(
  loggerName: 'bench.logger',
  level: LogLevel.info,
  message: 'This is a standard benchmark log message for engine comparison.',
  timestamp: '2026-03-22T00:00:00.000Z',
  origin: 'engine_comparison.dart:10',
);

class Scenario {
  final String name;
  final LogFormatter formatter;
  final List<LogDecorator> decorators;
  final int width;

  Scenario(this.name, this.formatter, this.decorators, [this.width = 80]);
}

class Result {
  final String engine;
  final double opsPerSec;
  final double p90;
  final int gcPressureKb;

  Result(this.engine, this.opsPerSec, this.p90, this.gcPressureKb);
}

Future<void> main() async {
  print('# Logd Engine Comparison Report Generator');

  final info = await Service.getInfo();
  if (info.serverUri == null) {
    print('Error: VM Service not enabled. Run with --enable-vm-service.');
    return;
  }

  final String wsUri =
      'ws://${info.serverUri!.host}:${info.serverUri!.port}${info.serverUri!.path}ws';
  final vmService = await vmServiceConnectUri(wsUri);
  final vm = await vmService.getVM();
  final isolateId = vm.isolates!.first.id!;

  final scenarios = [
    Scenario('1. Raw Machine (JSON)', const JsonFormatter(), []),
    Scenario('2. Modern Human (Structured + Box)', const StructuredFormatter(),
        [const BoxDecorator()]),
    Scenario(
        '3. Framing Squeeze (Prefix + Box @ 40)',
        const StructuredFormatter(),
        [const HierarchyDepthPrefixDecorator(), const BoxDecorator()],
        40),
    Scenario('4. Complex Native (TOON + Box + Nesting)', const ToonFormatter(),
        [const BoxDecorator(), const HierarchyDepthPrefixDecorator()]),
  ];

  final report = <String, List<Result>>{};

  for (final scenario in scenarios) {
    print('\nEvaluating Scenario: ${scenario.name}');
    final results = <Result>[];

    // Standard Engine
    results.add(await profile(
        vmService, isolateId, 'Standard', scenario, const StandardEngine()));

    // Arena Engine
    results.add(await profile(
        vmService, isolateId, 'Arena', scenario, const ArenaEngine()));

    // Native Engine (B-IR)
    results.add(await profile(
        vmService, isolateId, 'Native', scenario, NativeEngine()));

    report[scenario.name] = results;
  }

  print('\n\n${'=' * 60}');
  print('FINAL COMPARISON SUMMARY');
  print('=' * 60);

  for (final entry in report.entries) {
    print('\nScenario: ${entry.key}');
    print('Engine   | Throughput | p90 Latency | GC Pressure');
    print('-' * 55);
    for (final res in entry.value) {
      print(
          '${res.engine.padRight(8)} | ${res.opsPerSec.toStringAsFixed(0).padLeft(10)} | ${res.p90.toStringAsFixed(1).padLeft(10)}µs | ${res.gcPressureKb.toString().padLeft(10)} KB');
    }
  }

  await vmService.dispose();
}

Future<Result> profile(
  dynamic vmService,
  String isolateId,
  String engineName,
  Scenario scenario,
  LogEngine engine,
) async {
  final handler = Handler(
    formatter: scenario.formatter,
    decorators: scenario.decorators,
    sink: SilentSink(scenario.width),
    engine: engine,
  );

  // Warmup
  for (int i = 0; i < 500; i++) {
    await handler.log(entry);
  }

  // Reset counters
  await vmService.getAllocationProfile(isolateId, reset: true);

  final latencies = <int>[];
  final swatch = Stopwatch()..start();
  final iterWatch = Stopwatch();

  for (int i = 0; i < iterations; i++) {
    iterWatch.reset();
    iterWatch.start();
    await handler.log(entry);
    iterWatch.stop();
    latencies.add(iterWatch.elapsedMicroseconds);
  }
  swatch.stop();

  final profile = await vmService.getAllocationProfile(isolateId);
  num totalAllocated = 0;
  for (final member in profile.members!) {
    totalAllocated += (member.accumulatedSize ?? 0);
  }

  final opsPerSec = iterations / (swatch.elapsedMicroseconds / 1000000);
  latencies.sort();
  final p90 = latencies[(iterations * 0.90).toInt()].toDouble();
  final gcKb = (totalAllocated / 1024).toInt();

  return Result(engineName, opsPerSec, p90, gcKb);
}

base class SilentSink extends EncodingSink {
  SilentSink(final int width)
      : super(
          delegate: (final _) {}, // No-op
          encoder: const AnsiEncoder(),
          preferredWidth: width,
        );

  @override
  Future<void> output(
    final LogDocument document,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    final context = factory.checkoutContext();
    encoder.encode(entry, document, level, context, factory,
        width: preferredWidth);
    context.takeBytes();
    factory.release(context);
  }
}
