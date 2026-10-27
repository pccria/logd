# Contributing to logd

Thank you for considering contributing to `logd`. This document outlines the process and standards for contributing to the project.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please report unacceptable behavior to the project maintainers.

---

## Getting Started

### Development Environment Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/pccria/logd.git
   cd logd
   ```

2. Install dependencies:
   ```bash
   dart pub get
   ```

3. Run tests:
   ```bash
   dart test
   ```

4. Verify formatting:
   ```bash
   dart format --set-exit-if-changed .
   ```

---

## How to Contribute

### Reporting Issues

Before opening a new issue, search the [issue tracker](https://github.com/pccria/logd/issues) to avoid duplicates.

**For Bug Reports**, include:
- Clear, descriptive title
- Steps to reproduce
- Expected vs. actual behavior
- Minimal code example
- Dart/Flutter version
- Relevant logs or stack traces

**For Feature Requests**, include:
- Use case description
- Proposed API or behavior
- Potential implementation approach
- References to similar features in other libraries

### Pull Requests

We welcome PRs for bug fixes, features, and improvements.

#### PR Guidelines

1. **Branch Naming**: Use descriptive names
   - `fix/cache-invalidation-bug`
   - `feat/http-sink`
   - `docs/handler-philosophy`

2. **Commit Messages**: Follow [Conventional Commits](https://www.conventionalcommits.org)
   ```
   feat(handler): add HttpSink for remote logging
   fix(logger): correct descendant invalidation logic
   docs(time): clarify DST rule limitations
   test(stack_trace): add web platform parsing tests
   ```

3. **Before Submitting**:
   - [ ] Run `dart test` (all tests pass)
   - [ ] Run `dart format .` (code is formatted)
   - [ ] Run `dart analyze` (no analysis issues)
   - [ ] Update documentation if behavior changes
   - [ ] Add tests for new functionality

4. **PR Description**:
   - Reference related issues: "Fixes #123" or "Relates to #456"
   - Explain *why* the change is needed
   - Describe *what* changed at a high level
   - Note any breaking changes or migration requirements

---

## Code Standards

### Style Guidelines

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) conventions
- Use `dart format` for consistent formatting
- Prefer immutability: use `final` and `const` where possible
- Add `@immutable` annotation to immutable classes

### Documentation

**Public APIs** require documentation:
```dart
/// Formats a [LogEntry] into structured JSON.
///
/// The output is a single-line JSON object containing all log entry fields.
/// Timestamps are formatted according to ISO 8601.
///
/// Example:
/// ```dart
/// final formatter = JsonFormatter();
/// final entry = LogEntry(...);
/// final output = formatter.format(entry);
/// ```
class JsonFormatter implements LogFormatter {
  // ...
}
```

**Documentation Updates**: When changing behavior, update:
- Relevant files in `docs/` (philosophy, architecture, roadmap)
- Public API documentation strings
- Examples in `README.md` if applicable

See [docs/CONTRIBUTING_DOCS.md](doc/CONTRIBUTING_DOCS.md) for documentation-specific guidelines.

### Testing

**Test Coverage Expectations**:
- All new features must include unit tests
- Bug fixes should include regression tests
- Aim for >80% coverage for new code

**Test Organization**:
```
test/
├── logger/
│   ├── logger_test.dart
│   └── logger_cache_test.dart
├── handler/
│   ├── handler_test.dart
│   ├── formatters_test.dart
│   └── sinks_test.dart
└── integration/
    └── end_to_end_test.dart
```

**Writing Tests**:
```dart
group('LoggerCache', () {
  test('invalidates descendants when parent config changes', () {
    Logger.configure('app', logLevel: LogLevel.info);
    final child = Logger.get('app.ui');
    
    expect(child.logLevel, LogLevel.info);
    
    Logger.configure('app', logLevel: LogLevel.error);
    expect(child.logLevel, LogLevel.error); // Inherited change
  });
});
```

### Performance Considerations

`logd` is performance-critical. Consider:
- **Hot path optimization**: `Logger.info()` must be extremely fast when disabled
- **Memory efficiency**: Avoid unnecessary allocations in logging pipeline
- **Benchmark when relevant**: Add benchmarks for performance-sensitive changes

---

## Module-Specific Guidelines

### Logger Module
- Changes to inheritance logic require updates to `docs/logger/architecture.md`
- Cache invalidation changes need performance benchmarks
- Configuration API changes are breaking - discuss in issue first

### Handler Module
- New formatters should implement `LogFormatter` interface
- New sinks should implement `LogSink` abstract class
- Decorator interactions must be tested (see `docs/handler/roadmap.md`)

### Time Module
- DST rule changes must include validation tests
- Timestamp format additions need documentation in `Timestamp` class docs
- Performance impact of new formatters should be measured

### Stack Trace Module
- Platform-specific parsing must be tested on target platform
- Regex changes need comprehensive test cases
- Frame filtering logic should fail-safe (return null, not throw)

---

## Dependency Policy

**Minimize Dependencies**: `logd` aims to remain lightweight.

Before adding a dependency:
1. Open an issue to discuss necessity
2. Justify why the functionality can't be implemented internally
3. Consider impact on dependency graph
4. Verify license compatibility (BSD-3-Clause)

---

## Documentation Contributions

Documentation improvements are highly valued. See:
- [docs/CONTRIBUTING_DOCS.md](doc/CONTRIBUTING_DOCS.md) for documentation standards
- [docs/README.md](doc/README.md) for documentation structure

---

## Questions or Discussions

- **Questions**: Open a GitHub issue with the `question` label
- **Discussions**: Use [GitHub Discussions](https://github.com/pccria/logd/discussions)
- **Clarifications**: Comment on relevant issues or PRs

---

## Review Process

1. **Automated Checks**: GitHub Actions runs tests and analysis
2. **Code Review**: Maintainers review for correctness, style, and design
3. **Feedback**: Be responsive to review comments
4. **Approval**: PRs require maintainer approval before merge
5. **Merge**: Squash merging is preferred for clean history

---

Thank you for contributing to `logd`!
