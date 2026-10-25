# Changelog

## 0.1.4

- **Documentation**: Added official high-DPI hero branding.

## 0.1.3: Handler Missing Dispose Rule & Quick-Fix

This release introduces static analysis rule C6 (`logd_handler_missing_dispose`) with an automated IDE quick-fix to detect un-disposed `AsyncHandler` instances.

- ### New Lint Rule (Group C)
  - **Handler Missing Dispose (`logd_handler_missing_dispose`)**: Fires when an `AsyncHandler` is instantiated in a scope without a corresponding call to `dispose()`, preventing abandoned worker isolates and open IPC control ports.
  - **Automated Quick-Fix**: Added IDE quick-fix to automatically insert `await handler.dispose();` before the instance goes out of scope.

## 0.1.2: Automation of Code-Style & Arena Lifecycle Rules (Quick-Fixes)

This release focuses on improving the developer experience by introducing automated IDE quick-fixes for core validation warnings.

- ### Automated Quick-Fixes (DartFix)
  - **Metadata Set Deduplication**: Added a fix for `logd_metadata_set_duplicate` that automatically removes duplicate entries from `metadata` set literals.
  - **LogEngine Lifecycle Safety**: Added a fix for `logd_missing_release_in_engine` that automatically wraps `execute` method bodies in `try-finally` and invokes `releaseRecursive` in the `finally` block to protect the object pool.
  - **Purity Enforcers (Immutability)**: Added fixes for `logd_decorator_not_immutable` and `logd_formatter_not_immutable` to automatically prepend the `@immutable` annotation (inserting the required `package:meta/meta.dart` import if missing) and convert mutable fields to `final`.

## 0.1.1: Licensing Cleanup

This patch release completes the package packaging requirements.

- ### Package Quality
  - **License File**: Populated the package `LICENSE` file.

## 0.1.0: Initial Custom Lint Release

Initial release of `logd_linters`, establishing the AST-based validation suite for `logd`.

- ### Rules Library (12 Rules, 4 Quick-Fixes)
  - **Arena Lifecycle (Group A)**: Introduced rules preventing pool-leak and use-after-free bugs (`logd_document_retained_across_cycles`, `logd_missing_release_in_engine`, `logd_checkout_without_release`).
  - **Formatter/Decorator Purity (Group B)**: Enforces physical-vs-semantic rendering boundaries (`logd_formatter_performs_string_rendering`, `logd_decorator_not_immutable`, `logd_formatter_not_immutable`).
  - **Consumer Usage (Group C)**: Prevents engine misconfiguration, duplicate metadata arguments, and print sinks in production (`logd_avoid_print_sink_in_production`, `logd_logtag_use_bitmask`, `logd_log_buffer_not_sunk`, `logd_handler_missing_engine`, `logd_metadata_set_duplicate`).
  - **Logger Config (Group D)**: Guards the logger inheritance system against unconfigured freeze attempts (`logd_freeze_on_unconfigured_logger`).
