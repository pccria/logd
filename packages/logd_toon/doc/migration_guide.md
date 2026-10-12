# Migration Guide: `logd` v0.9.x to `logd_toon`

Starting with `logd` v0.9.7, the built-in TOON handlers, formatters, and encoders are deprecated. They have been extracted into the standalone `logd_toon` package to reduce the core package size and allow independent versioning of the TOON specification.

This guide explains how to migrate your existing codebase.

## 1. Add the Dependency

Add `logd_toon` to your `pubspec.yaml`:

```yaml
dependencies:
  logd: ^latest_version
  logd_toon: ^latest_version
```

Run `dart pub get` or `flutter pub get`.

## 2. Update Imports

### On `logd` v0.10.0+ (Pure Semantic Engine)
In `logd` v0.10.0 and above, all legacy TOON shims have been completely removed from core `package:logd`. You can import both packages directly with zero conflicts:

```dart
import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
```

### On `logd` v0.9.7 (Transitional Period)
If you are temporarily using `logd` v0.9.7, hide the deprecated classes from the `logd` import:

```dart
import 'package:logd/logd.dart'
    hide ToonEncoder, ToonFormatter, ToonFileHandler, ToonPrettyFormatter;
import 'package:logd_toon/logd_toon.dart';
```

## 3. Update Handler Usage

If you were using `ToonFileHandler` directly, the API remains the same. Just ensure you are importing it from `logd_toon`.

```dart
// The syntax remains identical
final handler = ToonFileHandler(
  'logs/app.toon',
  dialect: ToonDialect.strict,
);

Logger.configure(
  'app',
  handlers: [handler],
);
```

## 4. Registering Serializers (For Full Isolate Config Sync)

Because `ToonFormatter` is `@immutable`, using `ToonFileHandler.async()` automatically transfers the formatter across isolate boundaries without manual registration.

However, if you export and import the full logger configuration registry across isolates using `Logger.exportConfig()` and `Logger.importConfig()`, you must register TOON serializers during your application bootstrap:

```dart
void main() {
  // Required only when using Logger.exportConfig() / Logger.importConfig()
  registerLogdToonSerializers();
}
```

## 5. Status in `v0.10.0`

The legacy shims in `package:logd` have been **completely removed** in `v0.10.0`. Core `logd` has zero TOON formatting dependencies. All TOON document generation, schema reflection, and preamble extraction utilities are housed strictly in `package:logd_toon`.
