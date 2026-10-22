<h1 style="margin-bottom: 20px; text-align: left;font-weight: bold; width:" > logd Monorepo <img src="https://img.shields.io/pub/v/logd?logo=dart" alt="Pub Version" title="Pub Version"> <img src="https://img.shields.io/badge/License-BSD%203--Clause-blue.svg" alt="License: BSD 3-Clause" title="License: BSD 3-Clause"> <img src="https://img.shields.io/badge/maintained%20with-melos-f7bf7f.svg" alt="Maintained with Melos" title="Maintained with Melos"> </h1>


![logd Hero](https://raw.githubusercontent.com/pooriaaskarim/logd/refs/heads/master/assets/img/logd_hero.webp)


<p style="width: 100%; margin-bottom: 25px; text-align: left; font-weight: normal; font-size: 18px;"><b>logd</b> is a high-performance, structured hierarchical logging engine for Dart and Flutter. Engineered for zero-jank background isolate offloading, ambient async context propagation (MDC), and LLM token-optimized formats.</p>

### Why developers choose logd

- **Never drop a frame on disk or network I/O**: Add `.async()` to any handler to offload formatting, serialization, and I/O to a background worker isolate in ~15µs.
- **Trace requests across async boundaries**: `LogContext.run()` binds ambient context once, automatically propagating `requestId` or `userId` through every nested `await` and microtask with zero boilerplate.
- **Cut LLM prompt token costs by 30–50%**: Native **TOON** (Tab-Oriented Object Notation) emits compact schema headers and tab-delimited rows for AI agent telemetry and DuckDB ingestion.
- **Full-lifecycle HTTP inspection & redaction**: Intercept Dio requests with monotonic timing, automatic SOC2/GDPR redaction, executable cURL generation, and ambient trace forwarding via [`packages/logd_dio`](packages/logd_dio).
- **One log call, any destination**: Route logs simultaneously to styled ANSI consoles, queryable WAL SQLite ([`packages/logd_sqlite`](packages/logd_sqlite)), interactive HTML session files ([`packages/logd_html`](packages/logd_html)), or live WebSocket dashboards ([`packages/logd_network`](packages/logd_network)).
- **Surgical noise control**: Silence or debug specific subsystems dynamically with O(1) hierarchical inheritance and glob pattern matching.
- **Zero silent drops**: Fail-safe fallback prevents data loss if a disk fills or a network sink throws — without ever crashing the host application.

---

## Project Structure

This project is organized as a **Native Dart Workspace** managed with [Melos](https://melos.invertase.dev/).

- **[packages/logd](packages/logd)**: The core hierarchical logging engine.
- **[packages/logd_dio](packages/logd_dio)**: Production-grade Dio HTTP logging interceptor with cURL generation & redaction.
- **[packages/logd_toon](packages/logd_toon)**: Tab-Oriented Object Notation (TOON) formatter, encoder & file handler (30–50% LLM token reduction).
- **[packages/logd_html](packages/logd_html)**: Modern HTML5 log rendering, dynamic dark/light stylesheet & file handler.
- **[packages/logd_markdown](packages/logd_markdown)**: GitHub-Flavored Markdown formatter & file handler for CI summaries.
- **[packages/logd_sqlite](packages/logd_sqlite)**: SQLite WAL persistence handler and rich querying engine.
- **[packages/logd_network](packages/logd_network)**: HTTP batch shipping, WebSockets streaming, and live browser dashboard.
- **[packages/logd_linters](packages/logd_linters)**: Custom lint rules for arena lifecycle and formatter purity.
- **[packages/benchmarks](packages/benchmarks)**: Performance, throughput, and memory churn benchmark suite.
- **[doc/](doc)**: Deep-dive technical documentation (Philosophy, Architecture, Roadmaps).
- **[scripts/](scripts)**: Infrastructure for testing and network logging simulations.

## Development Guide

### Prerequisites

Ensure you have the Dart SDK (3.6.0+) and [Melos](https://pub.dev/packages/melos) installed:

```bash
dart pub global activate melos
```

### Common Commands

We use Melos to orchestrate tasks across the workspace:

| Command | Description |
|---------|-------------|
| `melos bootstrap` | Initialize the workspace and link packages |
| `melos run test` | Run all unit and integration tests |
| `melos run get` | Run `pub get` in all packages |
| `melos clean` | Clean build artifacts and dependencies |

### Running the Showcase

Explore runnable interactive demonstrations:

```bash
# Core logging engine showcase
dart run packages/logd/example/main.dart

# Dio HTTP logging interceptor showcase gallery
dart run packages/logd_dio/example/showcase_gallery.dart
```

## Documentation Source of Truth

Technical depth is maintained in the root `/doc` directory:

- [**Documentation Index**](doc/README.md)
- [**API Reference**](doc/api_reference.md)
- [**Production Cookbook**](doc/cookbook.md)
- [**Dio Logging Guide**](packages/logd_dio/README.md)
- [**Design Philosophy**](doc/logger/philosophy.md)
- [**Architecture Overview**](doc/logger/architecture.md)

## Contributing

Please read our [Contributing Guidelines](CONTRIBUTING.md) and [Documentation Standards](doc/CONTRIBUTING_DOCS.md) before submitting pull requests.

## License

All packages in this monorepo are licensed under the **BSD 3-Clause License**. See the [LICENSE](LICENSE) file for details.
