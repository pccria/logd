# Migration Guide: `logd` v0.9.x to `logd_html`

Starting with `logd` v0.9.7, the built-in HTML handlers, formatters, encoders, and stylesheets are deprecated. They have been extracted into the standalone `logd_html` package to reduce the core package size and allow independent versioning of HTML utilities.

This guide explains how to migrate your existing codebase.

## 1. Add the Dependency

Add `logd_html` to your `pubspec.yaml`:

```yaml
dependencies:
  logd: ^latest_version
  logd_html: ^latest_version
```

Run `dart pub get` or `flutter pub get`.

## 2. Update Imports

### On `logd` v0.10.0+ (Pure Semantic Engine)
In `logd` v0.10.0 and above, all legacy HTML shims have been completely removed from core `package:logd`. You can import both packages directly with zero conflicts:

```dart
import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
```

### On `logd` v0.9.7 (Transitional Period)
If you are temporarily using `logd` v0.9.7, hide the deprecated classes from the `logd` import:

```dart
import 'package:logd/logd.dart'
    hide HtmlEncoder, HtmlFileHandler, HtmlFormatter, HtmlStylesheet, DefaultHtmlStylesheet;
import 'package:logd_html/logd_html.dart';
```

## 3. Registering Serializers (For Full Isolate Config Sync)

Because `HtmlFormatter` is `@immutable`, using `HtmlFileHandler.async()` automatically transfers the formatter across isolate boundaries without manual registration.

However, if you export and import the full logger configuration registry across isolates using `Logger.exportConfig()` and `Logger.importConfig()`, you must register HTML serializers during your application bootstrap:

```dart
void main() {
  // Required only when using Logger.exportConfig() / Logger.importConfig()
  registerLogdHtmlSerializers();
}
```

## 4. Status in `v0.10.0`

The legacy shims in `package:logd` have been **completely removed** in `v0.10.0`. Core `logd` has zero HTML rendering dependencies. All HTML document generation and stylesheet customizations are housed strictly in `package:logd_html`.
