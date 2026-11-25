# The Logd Vault: Architectural Knowledge Base (AKB)

Welcome to the central repository of architectural wisdom for the `logd` library. This vault is organized according to the system's anatomy, ensuring a clear and extensible home for all technical domains.

## Navigation Map

### [Core](core/)
The foundational philosophy. Documents the vision of [Strategic Elasticity](core/manifest.md) and "The Dual Path."

### [Interface](interface/)
The developer's gateway. Documents regarding the Logger API, static context, and user-facing configurations.

### [Handler](handler/)
The engine room. [Pipeline Orchestration](handler/orchestration.md), [Network Telemetry & Resilience](handler/network_telemetry.md), [HTTP Inspection & Distributed Tracing](handler/http_inspection.md), [TOON LLM Telemetry & DuckDB Bridge](handler/toon_llm_telemetry.md), sink management, and asynchronous flow control.

### [Document](handler/document/)
The semantic heart. Definitions of the `LogDocument`, `LogNode` hierarchy, and metadata schemas.

### [Layout](handler/layout/)
The physical layer. Logic for terminal width calculations, word-wrapping, and ANSI render tokens.

### [Performance](performance/mm_strategies.md)
The resilience records. Analysis of [Memory Management Strategies](performance/mm_strategies.md), [Pressure Thresholds](performance/pressure_thresholds.md), and the [Arena](performance/mm_strategies.md).

### [Meta](meta/resonance.md)
The creation protocol. [Agentic Resonance](meta/resonance.md) and rules for the "Creation Comfort" environment.

### [Archive](archive/)
Historical ledger. [Architectural Decision Records (ADRs)](archive/) providing context for our evolution (e.g., [Strategic Simplification](archive/003-strategic-simplification.md)).

---
*Philosophy: Organic by default, Mechanical when forced.*
