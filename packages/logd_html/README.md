# logd_html

[![pub version](https://img.shields.io/pub/v/logd_html.svg)](https://pub.dev/packages/logd_html)
[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

![logd_html Hero](https://raw.githubusercontent.com/pooriaaskarim/logd/master/assets/img/logd_html_hero.webp)

Modern HTML5 log rendering, dynamic dark/light stylesheet, and file handler satellite package for `logd`.

## Features

- **Modern HTML5 Output**: Renders structured, browser-ready log documents with level badges, metadata blocks, and collapsible stack traces.
- **Dynamic Dark/Light Themes**: Built-in CSS system supporting automatic system preferences (`prefers-color-scheme`) and custom stylesheet injection via `HtmlStylesheet`.
- **Asynchronous File Handling**: Background worker isolate offloading via `HtmlFileHandler.async()`.
- **Isolate-Safe Components**: Compatible with standard isolate pipelines and cross-isolate handlers.

## Installation

Add `logd_html` to your `pubspec.yaml`:

```yaml
dependencies:
  logd: ^latest_version
  logd_html: ^latest_version
```

## Quick Start

```dart
import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';

void main() async {
  // Configure a logger to write beautiful HTML logs in the background
  final handler = HtmlFileHandler.async(
    path: 'logs/app_logs.html',
    title: 'My Application Logs',
  );

  Logger.configure(
    'html_demo',
    handlers: [handler],
  );

  final logger = Logger.get('html_demo');
  logger.info(
    'Application started successfully.',
    context: {'version': '1.0.0', 'environment': 'production'},
  );

  try {
    throw StateError('Simulated database connection failure');
  } catch (e, stackTrace) {
    logger.error(
      'Failed to connect to database',
      error: e,
      stackTrace: stackTrace,
    );
  }

  await handler.dispose();
}
```

<p align="center">
  <img src="https://raw.githubusercontent.com/pooriaaskarim/logd/master/assets/img/logd_html_report_preview.webp" alt="logd_html Report Preview" width="780" />
</p>

## Custom Stylesheets

Customize typography, colors, padding, and layout by providing a custom `HtmlStylesheet`:

```dart
final customStylesheet = DefaultHtmlStylesheet().copyWith(
  fontFamily: 'Fira Code, monospace',
  fontSize: '13px',
);

final handler = HtmlFileHandler(
  path: 'logs/custom.html',
  formatter: HtmlFormatter(
    title: 'Custom Styled Logs',
    stylesheet: customStylesheet,
  ),
);
```

---

## Migration from `logd` <=0.9.7

Starting with `logd` v0.10.0, all legacy HTML shims (`HtmlEncoder`, `HtmlFileHandler`, `HtmlFormatter`, `HtmlStylesheet`) have been permanently removed from core `package:logd`.

- **On `logd >=0.10.0`**: Simply import `package:logd_html/logd_html.dart`. No `hide` clauses are required.
- **On `logd 0.9.7`**: If upgrading gradually, hide the legacy shims (`import 'package:logd/logd.dart' hide HtmlEncoder...`).
- For detailed instructions, see the [Migration Guide](doc/migration_guide.md).
