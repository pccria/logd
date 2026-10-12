# logd_toon

[![pub version](https://img.shields.io/pub/v/logd_toon.svg)](https://pub.dev/packages/logd_toon)
[![pub points](https://img.shields.io/pub/points/logd_toon.svg)](https://pub.dev/packages/logd_toon/score)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

Tab-Oriented Object Notation (**TOON**) formatter, encoder, and file handler satellite package for [logd](https://pub.dev/packages/logd).

TOON is a compact, token-efficient tabular text format specifically optimized for streaming structured logs into Large Language Models (LLMs), machine query engines (e.g. DuckDB, Vector), or automated log aggregators with **30–50% fewer tokens than JSON**.

---

## Features

- **`ToonFormatter`**: Converts structured log entries into header schemas and delimited data rows.
- **`ToonEncoder`**: Encodes semantic log documents into token-optimized text streams.
- **`ToonFileHandler`**: Pre-wired file logging handler for TOON logs (supports synchronous and `.async()` isolate workers).
- **Explicit Schema Reflection**: Emits typed column declarations (`explicitSchema: true`) for LLMs and schema generators.
- **Dialect Support**: Switch between `ToonDialect.compact` (LLM prompt optimized) and `ToonDialect.strict` (DuckDB / SQL pipeline ingestion).
- **LLM Context Extraction**: Built-in `ToonEncoder.extractPreamble()` utility for sliding-window log slicing.
- **Full Specification**: Read the complete format design in the [TOON Specification](doc/toon_spec.md).

---

## Installation

Add `logd` and `logd_toon` to your `pubspec.yaml`:

```yaml
dependencies:
  logd: ^latest_version
  logd_toon: ^latest_version
```

---

## Usage Examples

### 1. Basic File Logging

```dart
import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';

void main() async {
  // Synchronous file handler using default compact TOON format
  final handler = ToonFileHandler('logs/app.toon');

  Logger.configure('app', handlers: [handler]);
  final logger = Logger.get('app');

  logger.info('System initialization started');
  logger.warning('Memory threshold reached', context: {'usage_pct': 85.2});

  await handler.dispose();
}
```

### 2. Asynchronous Isolate Worker

Offload TOON formatting, escaping, and file I/O to a background worker isolate:

```dart
Logger.configure('app', handlers: [
  ToonFileHandler.async('logs/production.toon'),
]);
```

### 3. Explicit Type Schema & Strict Dialect for DuckDB

```dart
final handler = ToonFileHandler(
  'logs/pipeline.toon',
  explicitSchema: true,
  dialect: ToonDialect.strict,
  formatter: const ToonFormatter(
    sortKeys: true,
    maxDepth: 3,
  ),
);
```

**Output:**

```text
-- TOON/1.0 logs
-- DELIMITER:\t QUOTE:" NULL:\N
logs[]{
  timestamp  : iso8601;
  logger     : string;
  origin     : string;
  level      : enum(TRACE,DEBUG,INFO,WARNING,ERROR,FATAL);
  message    : markdown;
  error      : string;
  stackTrace : stacktrace;
  context    : string;
}:
2026-09-14 00:00:00	app	main.dart:10	INFO	System initialization started	\N	\N	\N
```

---

## Advanced Utilities

### Extracting Preamble for LLM Prompts

When sending recent logs to an LLM context window, slice the file and prepend the TOON preamble:

```dart
final bytes = await File('logs/app.toon').readAsBytes();
final schema = ToonEncoder.extractPreamble(bytes) ?? '';
final recentLines = sliceLines(bytes, count: 50);

final llmPrompt = '''
You are an expert systems engineer. Analyze the following log entries:
$schema
${recentLines.join('\n')}
''';
```

---

## Documentation Links

- [TOON Specification Document](doc/toon_spec.md)
- [logd Core Package](https://pub.dev/packages/logd)
- [Issue Tracker](https://github.com/pooriaaskarim/logd/issues)

---

## Migration from `logd` <=0.9.7

Starting with `logd` v0.10.0, all legacy TOON shims (`ToonEncoder`, `ToonFormatter`, `ToonFileHandler`, `ToonPrettyFormatter`) have been permanently removed from core `package:logd`.

- **On `logd >=0.10.0`**: Simply import `package:logd_toon/logd_toon.dart`. No `hide` clauses are required.
- **On `logd 0.9.7`**: If upgrading gradually, hide the legacy shims (`import 'package:logd/logd.dart' hide ToonEncoder...`).
- For detailed instructions, see the [Migration Guide](doc/migration_guide.md).

---

## License

[BSD-3-Clause](LICENSE)
