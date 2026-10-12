# Performance Goldens

This directory contains snapshot results of major architectural milestones for the `logd` handler pipeline.

## Performance Ledger (Milestones)

The following table tracks the performance evolution of the `logd` handler architecture through its primary refinement milestones.

| Milestone | Commit | Description | Plain (µs) | Structured (µs) | Json (µs) |
|---|---|---|---|---|---|
| **M0** | `dev` | Legacy Baseline | 276.5 | 467.3 | 26.3* |
| **M1** | `cc3f7ad` | Core Semantic Engine | 198.4 | 569.5 | 274.1 |
| **M2** | `7ed89d8` | Pipeline Migration | 147.5 | 478.7 | 268.1 |
| **M3** | `788b9bb` | Optimized Bitmasks | 138.3 | 405.3 | 241.9 |
| **M4** | `b943c05` | Final Release Candidate | **136.3** | **411.3** | **262.1** |
| **M5** | `eb6cd11` | Arena Pooling | 139.4 | 423.4 | **241.8** |
| **M6** | `eb6cd11` | Buffer Stream | 164.8 | 438.8 | 275.1 |
| **M7** | `HEAD` | In-Place Refinements | 145.0 | 421.1 | 263.8 |
| **M8** | `HEAD` | Physical Arena Pooling | 138.6 | 404.2 | 262.7 |
| **M9** | `HEAD` | Static Tokens & Fast Paths | 135.7 | 305.8 | 242.1 |
| **M10** | `HEAD` | Zero-Churn & Isolate Sinks | **136.7** | **299.2** | **247.0** |
| **M11** | `HEAD` | Arena Engine Comparison | -- | **303.8** (Raw) | **129.1** (Human) |
| **M12** | `HEAD` | FFI Binary IR Groundwork | -- | 12.0 (Native)* | 5.0 (Native)* |
| **M13** | `606fcce` | Pipeline Stability & Alignment | 161.2 | 331.7 | 281.0 |
| **M14** | `0d14f22` | Zero-Latency Native Offload | 171.3 | 355.5 | 319.6 |
| **M15** | `9ea5843` | FFI Layout Parity & Stabilization | **221.1** | **342.0** | **366.3** |
| **M16** | `HEAD` | v0.9.1 API Stabilization & Hardening | **243.9** | **398.7** | **345.8** |
| **M17** | `6a972dc` | v0.9.3 Target Handlers | **235.0** | **380.9** | **408.7** |
| **M18** | `0be0f37` | v0.10.0 Pure Semantic Engine | **90.4** | **143.2** | **168.2** |

*\*M12 represents Native/FFI micro-benchmarks.*
*\*Legacy JSON utilized raw `jsonEncode` without semantic layout support.*

## Record Artifacts

- [Milestone 0: Legacy Baseline](./M00_LegacyBaseline.md)
- [Milestone 1: Semantic Engine](./M01_SemanticEngine.md)
- [Milestone 2: Pipeline Migration](./M02_PipelineMigration.md)
- [Milestone 3: Optimized Bitmasks](./M03_OptimizedBitmasks.md)
- [Milestone 4: HTML Pipeline](./M04_HtmlPipeline.md)
- [Milestone 5: Arena Pooling](./M05_LogArenaPooling.md)
- [Milestone 6: Buffer Stream Pipeline](./M06_BufferStream.md)
- [Milestone 7: In-Place Refinements](./M07_InPlaceRefinements.md)
- [Milestone 8: Physical Layer Arena](./M08_PhysicalArena.md)
- [Milestone 9: Static Tokens & Fast Paths](./M09_StaticTokens.md)
- [Milestone 10: Zero-Churn Encoding & Isolate Sinks](./M10_FinalCeiling.md)
- [Milestone 11: Arena Engine Comparison](./M11_ArenaEngineComparison.md)
- [Milestone 12: FFI Binary IR Groundwork](./M12_FFIBinaryIR.md)
- [Milestone 13: Pipeline Stability & Alignment](./M13_PipelineStability.md)
- [Milestone 14 (Phase 1): Native Offload](./M14_Phase1_NativeOffload.md)
- [Milestone 14 (Phase 2): LogEntry Pooling](./M14_Phase2_LogEntryPooling.md)
- [Milestone 15: FFI Layout Parity & Stabilization](./M15_FfiLayoutParity.md)
- [Milestone 16: v0.9.1 API Stabilization & Hardening](./M16_v091_ApiHardening.md)
- [Milestone 17: v0.9.3 Target Handlers](./M17_v093_TargetHandlers.md)
- [Milestone 18: v0.10.0 Pure Semantic Engine](./M18_v0100_PureSemanticEngine.md)

## Usage & Maintenance

These snapshots represent the **performance floor**. 

- **Test:** Run `dart run packages/benchmarks/lib/main.dart` and compare against the latest milestone. Investigate any `>10%` throughput regressions.
- **Commit Policy:** Do *not* commit routine benchmarks. Only commit new snapshot records here when:
  - Landing a major architectural/feature milestone
  - Reaching a stable version release
