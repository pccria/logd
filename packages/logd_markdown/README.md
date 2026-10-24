# logd_markdown

[![pub version](https://img.shields.io/pub/v/logd_markdown.svg)](https://pub.dev/packages/logd_markdown)
[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

![logd_markdown Hero](https://raw.githubusercontent.com/pooriaaskarim/logd/master/assets/img/logd_markdown_hero.webp)

GitHub-Flavored Markdown (GFM) encoder, formatter, and file handler satellite package for `logd`.

## Features

- **GitHub-Flavored Markdown**: Generates structured Markdown log documents with emoji headings, alert callouts (`> [!ERROR]`), and syntax-highlighted code blocks.
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

```dart
import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';

void main() async {
  registerLogdMarkdownSerializers();

  final handler = MarkdownFileHandler.async(path: 'logs/app.md');

  Logger.configure('main', handlers: [handler]);

  final logger = Logger.get('main');
  logger.info('Application started successfully');

  await handler.dispose();
}
```

---

## Migration from `logd` <=0.9.7

Starting with `logd` v0.10.0, all legacy Markdown shims (`MarkdownEncoder`, `MarkdownFormatter`, `MarkdownFileHandler`) have been permanently removed from core `package:logd`.

- **On `logd >=0.10.0`**: Simply import `package:logd_markdown/logd_markdown.dart`. No `hide` clauses are required.
- **On `logd 0.9.7`**: If upgrading gradually, hide the legacy shims (`import 'package:logd/logd.dart' hide MarkdownEncoder, MarkdownFileHandler;`).
- For detailed instructions, see the [Migration Guide](doc/migration_guide.md).
