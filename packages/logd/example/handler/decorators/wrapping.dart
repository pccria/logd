import 'package:logd/logd.dart';

/// This example demonstrates the implicit wrapping behavior.
///
/// Decorators like `BoxDecorator` and aligned `SuffixDecorator` now
/// automatically wrap content that exceeds the available width. This ensures
/// that layout constraints are respected even when using formatters like
/// `JsonFormatter` that produce single long lines.
void main() async {
  print('=== Logd / Wrapping Showcase ===\n');

  // SCENARIO 1: Unwrapped Text (Wide Line)
  const rawHandler = Handler(
    formatter: PlainFormatter(metadata: {}),
    sink: ConsoleSink(lineLength: 80),
  );

  Logger.configure('raw', handlers: [rawHandler]);
  print('--- 1. Raw Text (Wide Line) ---');
  Logger.get('raw').info(
    'This is a very long message that demonstrates how text looks before '
    'wrapping constraints are applied.',
  );

  print('\n${'=' * 60}\n');

  // SCENARIO 2: Implicitly Wrapped Box
  // BoxDecorator enforces the 40 char limit by wrapping the content
  // automatically inside the rounded box.
  const wrappedHandler = Handler(
    formatter: PlainFormatter(metadata: {}),
    decorators: [
      BoxDecorator(borderStyle: BorderStyle.rounded),
    ],
    sink: ConsoleSink(lineLength: 40),
  );

  Logger.configure('wrapped', handlers: [wrappedHandler]);
  print('--- 2. Wrapped Text Inside Box (40 chars) ---');
  Logger.get('wrapped').info(
    'This is a long message that wraps gracefully '
    'inside the 40-character rounded box.',
  );

  print('\n${'=' * 60}\n');

  // SCENARIO 3: Wrapped + Suffix (Sidebar Effect)
  // SuffixDecorator (aligned) ensures content fits and suffix aligns on every line.
  const sidebarHandler = Handler(
    formatter: PlainFormatter(metadata: {}),
    decorators: [
      SuffixDecorator(' [SIDEBAR]', aligned: true),
      BoxDecorator(borderStyle: BorderStyle.rounded),
    ],
    sink: ConsoleSink(lineLength: 50),
  );

  Logger.configure('sidebar', handlers: [sidebarHandler]);
  print('--- 3. Wrapped + Sidebar Suffix ---');
  Logger.get('sidebar').info(
    'This message wraps, and the suffix aligns perfectly on every line.',
  );

  print('\n=== Wrapping Showcase Complete ===');
}
