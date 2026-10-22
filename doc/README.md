# Documentation Index

This directory contains detailed documentation regarding the design, architecture, and roadmap of the `logd` library.

- [**API Reference**](api_reference.md): Public classes, methods, configurations, and satellite APIs catalog.
- [**Production Cookbook**](cookbook.md): Battle-tested copy-paste recipes for Flutter, Dio, Shelf, SQLite, live WebSockets, and AI agent telemetry.
- [**Migration Guide**](migration.md): Upgrading from legacy versions, satellite migrations, and Flutter SDK decoupling details.
- [**Architecture Decision Records (ADRs)**](decisions/README.md): Formal design decisions from ADR-001 to ADR-008.
- [**Cross-Isolate Coordination Guide**](logger/isolates.md): Configuration snapshots, serialization registry, and satellite package hooks.
- [**Semantic Versioning Contract**](semver_contract.md): Public API guarantees, stability tiers, and deprecation policies.

## Logger Core
The core module handles logger instantiation, the inheritance hierarchy, and configuration resolution.

- [**Overview**](logger/README.md): Module responsibilities and API overview
- [**Philosophy**](logger/philosophy.md): Explains the design principles (Inheritance, Sparse Configuration, Lazy Resolution).
- [**Architecture**](logger/architecture.md): Technical overview of the internal registry, caching mechanisms, and data structures.
- [**Roadmap**](logger/roadmap.md): Active tracking of features, technical debt, and future plans.

## Modules

### Handler
Responsible for the processing pipeline of log entries.
- [Overview](handler/README.md)
- [Design Philosophy](handler/philosophy.md)
- [Architecture](handler/architecture.md)
- [Execution Engines Guide](handler/engines.md) - Standard, Arena, and Native engines guide
- [Async Handler & Isolate Offloading Guide](handler/async_handler_guide.md) - Background isolate execution and worker lifecycle
- [Decorator Compositions](handler/decorator_compositions.md) - Execution priority and flow
- [Roadmap](handler/roadmap.md)

### Satellite Packages Documentation
- [**logd_dio**](../packages/logd_dio/doc/architecture.md) - Dio HTTP interceptor with cURL generation and redaction
- [**logd_toon**](../packages/logd_toon/doc/toon_spec.md) - TOON specification, dialects, and architecture
- [**logd_html**](../packages/logd_html/doc/architecture.md) - HTML architecture, custom stylesheets, and migration
- [**logd_markdown**](../packages/logd_markdown/doc/architecture.md) - Markdown architecture, GFM tables, and migration
- [**logd_sqlite**](../packages/logd_sqlite/doc/architecture.md) - SQLite WAL architecture, query engine, and benchmarks
- [**logd_network**](../packages/logd_network/doc/architecture.md) - HTTP batching, WebSockets, dashboard, and roadmap

### Reports & Benchmarks
Performance and quality analysis reports:
- [Engine Stability & Performance Report](engine_stability_report.md) - Profile and memory analysis of the execution engines

### Time
Handles timestamp generation and timezone management.
- [Overview](time/README.md)
- [Design Philosophy](time/philosophy.md)
- [Architecture](time/architecture.md)
- [Roadmap](time/roadmap.md)

### Stack Trace
Parses and sanitizes stack traces to provide meaningful caller information.
- [Overview](stack_trace/README.md)
- [Design Philosophy](stack_trace/philosophy.md)
- [Architecture](stack_trace/architecture.md)
- [Roadmap](stack_trace/roadmap.md)

## Meta
- [**Contributing to Documentation**](CONTRIBUTING_DOCS.md): Guidelines for documentation contributions.
- [**Contributing**](../CONTRIBUTING.md): Guidelines for project contributors.
