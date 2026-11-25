# logd_markdown

[![pub version](https://img.shields.io/pub/v/logd_markdown.svg)](https://pub.dev/packages/logd_markdown)
[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

![logd_markdown Hero](https://raw.githubusercontent.com/pccria/logd/master/assets/img/logd_markdown_hero.webp)

GitHub-Flavored Markdown (GFM), CommonMark, and GitLab CI encoder, table digest formatter, and step summary handler satellite package for `logd`.

## Features

- **GitHub-Flavored Markdown & Multi-Dialect (`MarkdownDialect`)**: Switch between `MarkdownDialect.gfm` (`> [!ERROR]`, `<details>`), `MarkdownDialect.commonmark` (pure CommonMark), and `MarkdownDialect.gitlab`.
- **CI/CD Job Summaries (`GitHubStepSummaryHandler`)**: Automatically resolves `$GITHUB_STEP_SUMMARY`, streams compact log tables, tracks severity counts in `MarkdownRunSummary`, and appends an executive rollup table + collapsible failure details.
- **Compact Table Digest Mode (`MarkdownTableFormatter`)**: Renders aligned Markdown tables (`| Timestamp | Level | Logger | Message | Context |`) with automatic pipe escaping and inline JSON context.
- **Safe Context Serialization**: Serializes `MapNode` payloads as valid JSON fenced blocks with safe fallbacks for `DateTime`, `Duration`, `Enum`, and custom objects.
- **Asynchronous Isolate Support**: Offload Markdown serialization and file I/O to background worker isolates using `MarkdownFileHandler.async()`.
- **Isolate Registry**: Includes `registerLogdMarkdownSerializers()` for cross-isolate configuration transfer.

## Installation

Add `logd_markdown` to your `pubspec.yaml`:

```yaml
dependencies:
  logd: ^latest_version
  logd_markdown: ^latest_version
```

## Quick Start

### 1. Markdown File Logging (Card or Table Mode)

```dart
import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';

void main() async {
  registerLogdMarkdownSerializers();

  // Detailed GFM cards (or pass tableMode: true for compact table rows)
  final handler = MarkdownFileHandler.async(
    path: 'logs/app.md',
    dialect: MarkdownDialect.gfm,
    metadata: const {LogMetadata.timestamp, LogMetadata.logger},
  );

  Logger.configure('main', handlers: [handler]);

  final logger = Logger.get('main');
  logger.info('Application started successfully');

  await handler.dispose();
}
```

### 2. GitHub Actions Step Summary (`GitHubStepSummaryHandler`)

```dart
import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';

void main() async {
  // Auto-reads $GITHUB_STEP_SUMMARY in CI; falls back safely when run locally
  final summaryHandler = GitHubStepSummaryHandler(
    title: 'CI Verification Run',
    fallbackPath: 'logs/ci_summary.md',
    tableMode: true,
  );

  Logger.configure('ci', handlers: [summaryHandler]);
  final logger = Logger.get('ci');

  logger.info('Static analysis passed', context: {'packages': 7});
  logger.error('Integration test failed', error: 'Connection refused');

  // Flushes entries and appends the severity rollup + collapsible failures
  await summaryHandler.dispose();
}
```

### 3. Compact Table Formatter (`MarkdownTableFormatter`)

```dart
import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';

void main() async {
  final handler = MarkdownFileHandler(
    path: 'logs/digest.md',
    tableMode: true,
    dialect: MarkdownDialect.gfm,
  );

  Logger.configure('digest', handlers: [handler]);
  Logger.get('digest').warning('High latency', context: {'ms': 420});

  await handler.dispose();
}
```

## Showcase Gallery

Run the 4-scenario interactive showcase:

```bash
dart run packages/logd_markdown/example/showcase_gallery.dart
```

---

## Migration from `logd` <=0.9.7

Starting with `logd` v0.10.0, all legacy Markdown shims (`MarkdownEncoder`, `MarkdownFormatter`, `MarkdownFileHandler`) have been permanently removed from core `package:logd`.

- **On `logd >=0.10.0`**: Simply import `package:logd_markdown/logd_markdown.dart`. No `hide` clauses are required.
- **On `logd 0.9.7`**: If upgrading gradually, hide the legacy shims (`import 'package:logd/logd.dart' hide MarkdownEncoder, MarkdownFileHandler;`).
- For detailed instructions, see the [Migration Guide](doc/migration_guide.md).
