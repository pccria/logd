---
name: Bug report
about: Report a defect, unexpected behavior, or crash in the logd ecosystem
title: '[bug]: '
labels: ['bug', 'triage']
assignees: ''

---

### Description of the Bug
<!-- A clear and concise description of the defect or unexpected behavior. -->

### Affected Package(s) & Version(s)
<!-- Check and specify versions (e.g., logd: 0.10.8, logd_dio: 0.2.x, etc.) -->
- [ ] `packages/logd` (Core): 
- [ ] `packages/logd_dio`: 
- [ ] `packages/logd_sqlite`: 
- [ ] `packages/logd_network`: 
- [ ] `packages/logd_html`: 
- [ ] `packages/logd_toon`: 
- [ ] `packages/logd_markdown`: 
- [ ] `packages/logd_linters`: 

### Environment & Target Platform
- **Dart SDK version** (`dart --version`):
- **Flutter SDK version** (if applicable, `flutter --version`):
- **Operating System / Target Host**: (e.g., macOS Sonoma, Ubuntu 24.04, Windows 11)
- **Execution Target**:
  - [ ] Dart CLI / Server
  - [ ] Flutter Mobile (Android / iOS)
  - [ ] Flutter Desktop (macOS / Linux / Windows)
  - [ ] Web

### Logger / Handler Pipeline Configuration
<!-- How is your logger or handler tree initialized? Provide the configuration snippet. -->
```dart
// Example:
// final logger = Logger.get('app');
// logger.attach(ConsoleHandler().async());
```

### Minimal Steps to Reproduce
<!-- Provide a minimal, self-contained reproducible code example or test case. -->
```dart
void main() {
  // Minimal code that triggers the issue
}
```

### Expected Behavior
<!-- What did you expect to happen? -->

### Actual Behavior / Logs / Stack Trace
<!-- Include terminal logs, error messages, or full stack traces here. -->
```text
// Paste output or stack trace here
```

### Concurrency / Context Details (if applicable)
<!-- Mark any relevant execution details: -->
- [ ] Occurs with `.async()` isolate offloading
- [ ] Involves ambient context (`LogContext.run(...)`) across async/Zone boundaries
- [ ] Involves high-throughput / stress logging
- [ ] Involves process shutdown or isolate teardown

### Additional Context
<!-- Any other background, custom decorators, or network/disk constraints. -->
