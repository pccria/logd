# Benchmark Report
**Commit:** 0be0f37 feat(core): v0.10.0 pure semantic engine & hard deprecation removal
**Branch:** feat/v0.10.0-pure-semantic-engine
**Dart:** Dart SDK version: 3.13.5 (stable) (Tue Sep 29 01:00:52 2026 -0700) on "linux_x64"

```text
Running Baseline Benchmarks...
==============================

--- Formatter Throughput ---
PlainFormatter(RunTime): 90.381876724931 us.
StructuredFormatter(RunTime): 143.2189713581768 us.
ToonFormatter(RunTime): 200.098543786156 us.
JsonFormatter(RunTime): 168.23824768323504 us.
JsonPrettyFormatter(RunTime): 351.50252657257363 us.
MarkdownEncoder(RunTime): 18.86315662895781 us.

--- Decorator Overhead ---
BoxDecorator(RunTime): 258.6938328827089 us.
PrefixDecorator(RunTime): 316.27631783548435 us.
StyleDecorator(RunTime): 3.4788132605933697 us.
SuffixDecorator(RunTime): 317.94126984126984 us.
HierarchyDepthPrefixDecorator(RunTime): 279.88980716253445 us.

--- Pipeline Throughput ---
FullPipeline(RunTime): 1.219922803285008 us.
ArenaFullPipeline(RunTime): 1.5596986350297395 us.
ManualPipeline(RunTime): 249.67822089700584 us.
--- Lazy Stack & Origin Bypass Throughput ---
Logger.info(includeOrigin: true)(RunTime): 257.8355773153815 us.
Logger.info(includeOrigin: false)(RunTime): 102.40234738662056 us.
--- Ambient LogContext (MDC) Throughput ---
Logger.info (no context)(RunTime): 98.59565273477813 us.
Logger.info (ambient LogContext)(RunTime): 138.22682161773025 us.

--- Multi-Sink Scaling ---
MultiSink (x1)(RunTime): 10.865248822692504 us.
MultiSink (x2)(RunTime): 11.031899856450647 us.
MultiSink (x4)(RunTime): 11.252784362470369 us.

--- Cache Invalidation Performance ---
Descendant Invalidation (10,000 Unrelated, 1 Descendant)(RunTime): 11.858760282479436 us.

--- Timezone Cache Performance ---
TimezoneOffsetLocal(RunTime): 0.461034 us.
TimezoneOffsetNamed(RunTime): 0.4607435 us.
TimestampFormatting(RunTime): 5.8912262175475645 us.

--- AsyncHandler vs StandardEngine Performance ---
StandardEngine (Sync JSON)(RunTime): 1558.1163801620232 us.
AsyncHandler (Isolate-offloaded JSON)(RunTime): 6.050799442452487 us.

--- Phase 1: Native Offload Scaling (10k iterations) ---
[logd-internal] [WARNING]: Arena saturation reached (200 packets). Blocking main thread.

--- Phase 1: Native Offload Scaling (10k iterations) ---
  Progress: 0/10000
  Progress: 1000/10000
  Progress: 2000/10000
[logd-internal] [WARNING]: Blocked main thread for 18ms waiting for pool capacity.
  Progress: 3000/10000
  Progress: 4000/10000
  Progress: 5000/10000
[logd-internal] [WARNING]: Blocked main thread for 25ms waiting for pool capacity.
  Progress: 6000/10000
  Progress: 7000/10000
  Progress: 8000/10000
  Progress: 9000/10000
NativeEngineOffload (Phase 1): 21.71 us/op

--- Stress Test & Profiling ---
### 1. The Raw Machine (JSON -> FileSink)
Profiling: Raw Machine ...
13550 Ops/sec | p90: 29.00µs | p95: 32.00µs | p99: 58.00µs | GC Pressure: 0.00 KB/10k

### 2. The Modern Human (Structured -> Box -> ConsoleSink)
Profiling: Modern Human ...
11445 Ops/sec | p90: 36.00µs | p95: 39.00µs | p99: 63.00µs | GC Pressure: 0.00 KB/10k

### 3. The Framing Squeeze (Prefix -> Box -> ConsoleSink @ 40 width)
Profiling: Framing Squeeze ...
3967 Ops/sec | p90: 130.00µs | p95: 141.00µs | p99: 228.00µs | GC Pressure: 0.00 KB/10k


--- Structural Efficiency Report ---
Error: VM Service not enabled. Run with --observe or --enable-vm-service.
==============================
Benchmarks Complete.
```
