# logd_linters

[![pub version](https://img.shields.io/pub/v/logd_linters.svg)](https://pub.dev/packages/logd_linters)
[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

![logd_linters Hero](../../assets/img/logd_linters_hero.webp)

Custom lint rules and quick-fixes for the `logd` logging library.

Surfaces `logd` API contracts, arena lifecycle constraints, and formatting purity constraints as compile-time analyzer squiggles directly in your IDE.

---

## Installation

Add to your `pubspec.yaml`'s `dev_dependencies`:

```yaml
dev_dependencies:
  custom_lint: ^latest_version
  logd_linters: ^latest_version
```

Enable the plugin in your `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

---

## Rule Index

### Arena / Lifecycle Rules (Group A)

#### 1. `logd_document_retained_across_cycles` (Error)
Fires when a `LogDocument` or `LogNode` is stored in an instance field or captured in a closure that outlives the current log execution frame. Reusing pooled objects after they have been returned to the arena leads to undefined behavior.

*   **Bad:**
    ```dart
    class LeakyFormatter implements LogFormatter {
      LogDocument? _cachedDoc;
      void format(LogEntry entry, LogDocument doc, LogPipelineFactory f) {
        _cachedDoc = doc; // Violation
      }
    }
    ```
*   **Good:**
    ```dart
    void format(LogEntry entry, LogDocument doc, LogPipelineFactory f) {
      doc.text(entry.message); // Only use inside format frame
    }
    ```

#### 2. `logd_missing_release_in_engine` (Error)
Ensures that custom `LogEngine` implementations wrap the pipeline execution in `try-finally` and call `document.releaseRecursive(factory)` in the `finally` block to prevent pool exhaustion.

*   **Bad:**
    ```dart
    Future<void> execute(...) async {
      final doc = factory.checkoutDocument();
      formatter.format(entry, doc, factory);
      await sink.output(doc, entry, entry.level, factory);
      doc.releaseRecursive(factory); // Leaks pool if sink throws
    }
    ```
*   **Good:**
    ```dart
    Future<void> execute(...) async {
      final doc = factory.checkoutDocument();
      try {
        formatter.format(entry, doc, factory);
        await sink.output(doc, entry, entry.level, factory);
      } finally {
        doc.releaseRecursive(factory);
      }
    }
    ```

#### 3. `logd_checkout_without_release` (Warning)
Fires when a pooled node or document checked out from `LogPipelineFactory` has no visible `release` or `releaseRecursive` invocation in the enclosing block.

---

### Formatter & Decorator Purity Rules (Group B)

#### 4. `logd_formatter_performs_string_rendering` (Warning)
Formatters and decorators must operate strictly on the Semantic IR (`LogDocument`). Accessing direct terminal outputs (like `stdout.terminalColumns` or `print()`) breaks architectural boundaries.

*   **Bad:**
    ```dart
    void format(LogEntry entry, LogDocument doc, LogPipelineFactory f) {
      final width = io.stdout.terminalColumns; // Layout concern in formatter
      doc.text(entry.message.substring(0, width));
    }
    ```
*   **Good:**
    ```dart
    void format(LogEntry entry, LogDocument doc, LogPipelineFactory f) {
      doc.text(entry.message); // TerminalLayout handles wrap width
    }
    ```

#### 5. `logd_decorator_not_immutable` (Warning)
`LogDecorator` implementations must be annotated with `@immutable` and contain only `final` fields.

#### 6. `logd_formatter_not_immutable` (Warning)
`LogFormatter` implementations must be annotated with `@immutable` and contain only `final` fields (excluding internal pool-managed standard types).

---

### Consumer Usage Rules (Group C)

#### 7. `logd_avoid_print_sink_in_production` (Info)
`PrintSink` is meant for tests and fast local debugging. Production code should route logs through `ConsoleSink` or `FileSink`.

#### 8. `logd_logtag_use_bitmask` (Warning)
`LogTag` constants are integers representing bitmasks. Direct equality comparisons (`==`, `!=`) will not match compound tags. Use bitwise `&`.

*   **Bad:**
    ```dart
    if (entry.tags == LogTag.error) { ... }
    ```
*   **Good:**
    ```dart
    if (entry.tags & LogTag.error != 0) { ... }
    ```

#### 9. `logd_log_buffer_not_sunk` (Warning · Experimental)
Fires when a `LogBuffer` is obtained but `sink()` is never called in the visible scope.

#### 10. `logd_handler_missing_engine` (Info)
High-throughput isolate sinks require `engine: ArenaEngine()` to bypass GC pressure.

*   **Bad:**
    ```dart
    final handler = Handler(sink: IsolateSink(worker)); // Missing engine
    ```
*   **Good:**
    ```dart
    final handler = Handler(sink: IsolateSink(worker), engine: ArenaEngine());
    ```

#### 11. `logd_metadata_set_duplicate` (Info)
Sets passed to metadata arguments should not contain duplicate items, which are silently discarded.

---

### Inheritance Configuration Rules (Group D)

#### 12. `logd_freeze_on_unconfigured_logger` (Warning)
`freezeInheritance()` called on a logger obtained via `Logger.get()` before `Logger.configure()` creates a ghost node that populates the hierarchy with unconfigured default properties.
