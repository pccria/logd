# Migration Guide: `logd` v0.9.x to `logd_markdown`

Starting with `logd` v0.9.7, the built-in Markdown handlers and encoders are deprecated. They have been extracted into the standalone `logd_markdown` package.

## 1. Add the Dependency

Add `logd_markdown` to your `pubspec.yaml`:

```yaml
dependencies:
  logd: ^latest_version
  logd_markdown: ^latest_version
```

Run `dart pub get` or `flutter pub get`.

## 2. Update Imports

### On `logd` v0.10.0+ (Pure Semantic Engine)
In `logd` v0.10.0 and above, all legacy Markdown shims have been completely removed from core `package:logd`. You can import both packages directly with zero conflicts:

```dart
import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';
```

### On `logd` v0.9.7 (Transitional Period)
If you are temporarily using `logd` v0.9.7, hide the deprecated classes from the `logd` import:

```dart
import 'package:logd/logd.dart' hide MarkdownEncoder, MarkdownFileHandler;
import 'package:logd_markdown/logd_markdown.dart';
```

## 3. Registering Serializers (For Full Isolate Config Sync)

Because `MarkdownFormatter` is `@immutable`, using `MarkdownFileHandler.async()` automatically transfers the formatter across isolate boundaries without manual registration.

However, if you export and import the full logger configuration registry across isolates using `Logger.exportConfig()` and `Logger.importConfig()`, you must register Markdown serializers during your application bootstrap:

```dart
void main() {
  // Required only when using Logger.exportConfig() / Logger.importConfig()
  registerLogdMarkdownSerializers();
}
```

## 4. Status in `v0.10.0`

The legacy shims in `package:logd` have been **completely removed** in `v0.10.0`. Core `logd` has zero Markdown rendering dependencies. All Markdown document generation and table formatting are housed strictly in `package:logd_markdown`.
