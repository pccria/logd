import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'github_env_stub.dart' if (dart.library.io) 'github_env_io.dart';
import 'markdown_dialect.dart';
import 'markdown_formatter.dart';
import 'markdown_table_formatter.dart';

/// A captured warning or error entry recorded for a [MarkdownRunSummary].
@immutable
final class MarkdownSummaryFailure {
  /// Creates a [MarkdownSummaryFailure].
  const MarkdownSummaryFailure({
    required this.timestamp,
    required this.loggerName,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  /// Timestamp string recorded on the log entry.
  final String timestamp;

  /// Hierarchical logger name that emitted the entry.
  final String loggerName;

  /// Severity level of the captured entry.
  final LogLevel level;

  /// Primary log message text.
  final String message;

  /// Optional serialized error message.
  final String? error;

  /// Optional serialized stack trace string.
  final String? stackTrace;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is MarkdownSummaryFailure &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          loggerName == other.loggerName &&
          level == other.level &&
          message == other.message &&
          error == other.error &&
          stackTrace == other.stackTrace;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    timestamp,
    loggerName,
    level,
    message,
    error,
    stackTrace,
  );
}

/// An immutable execution summary of log severities and failures for a run.
@immutable
final class MarkdownRunSummary {
  /// Creates a [MarkdownRunSummary].
  MarkdownRunSummary({
    required this.totalEntries,
    required this.traceCount,
    required this.debugCount,
    required this.infoCount,
    required this.warningCount,
    required this.errorCount,
    required this.elapsed,
    final List<MarkdownSummaryFailure> failures = const [],
  }) : failures = List.unmodifiable(failures);

  /// Total number of log entries processed.
  final int totalEntries;

  /// Number of [LogLevel.trace] entries recorded.
  final int traceCount;

  /// Number of [LogLevel.debug] entries recorded.
  final int debugCount;

  /// Number of [LogLevel.info] entries recorded.
  final int infoCount;

  /// Number of [LogLevel.warning] entries recorded.
  final int warningCount;

  /// Number of [LogLevel.error] entries recorded.
  final int errorCount;

  /// Elapsed duration since the handler started collecting entries.
  final Duration elapsed;

  /// Captured warning and error entries (bounded by `maxFailures`).
  final List<MarkdownSummaryFailure> failures;

  /// Whether any [LogLevel.error] entries were recorded.
  bool get hasErrors => errorCount > 0;

  /// Renders this summary as a Markdown report using [title] and [dialect].
  String toMarkdown({
    final String title = 'Log Summary',
    final MarkdownDialect dialect = MarkdownDialect.gfm,
  }) {
    final statusEmoji = errorCount > 0 ? '❌' : (warningCount > 0 ? '⚠️' : '✅');
    final buffer = StringBuffer()
      ..writeln('## $statusEmoji $title\n')
      ..writeln('| Metric | Count |')
      ..writeln('| --- | ---: |')
      ..writeln('| Total Entries | $totalEntries |')
      ..writeln('| ❌ Errors | $errorCount |')
      ..writeln('| ⚠️ Warnings | $warningCount |')
      ..writeln('| ℹ️ Info | $infoCount |')
      ..writeln('| 🔍 Debug | $debugCount |')
      ..writeln('| 🧬 Trace | $traceCount |')
      ..writeln('| ⏱️ Duration | ${elapsed.inMilliseconds} ms |\n');

    if (failures.isNotEmpty) {
      if (dialect == MarkdownDialect.commonmark) {
        buffer.writeln('### Failure & Warning Details (${failures.length})\n');
      } else {
        buffer
          ..writeln('<details>')
          ..writeln(
            '<summary>Failure &amp; Warning Details (${failures.length})</summary>\n',
          );
      }

      for (final f in failures) {
        final icon = f.level == LogLevel.error ? '❌' : '⚠️';
        buffer.writeln(
          '- $icon **${f.level.name.toUpperCase()}** `[${f.loggerName}]` '
          '(${f.timestamp}): ${f.message}',
        );
        if (f.error != null && f.error!.isNotEmpty) {
          buffer.writeln('  - Error: `${f.error}`');
        }
        if (f.stackTrace != null && f.stackTrace!.trim().isNotEmpty) {
          var fence = '```';
          while (f.stackTrace!.contains(fence)) {
            fence += '`';
          }
          buffer
            ..writeln('\n$fence')
            ..writeln(f.stackTrace!.trimRight())
            ..writeln('$fence\n');
        }
      }

      if (dialect != MarkdownDialect.commonmark) {
        buffer.writeln('</details>\n');
      }
    }

    return buffer.toString();
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is MarkdownRunSummary &&
          runtimeType == other.runtimeType &&
          totalEntries == other.totalEntries &&
          traceCount == other.traceCount &&
          debugCount == other.debugCount &&
          infoCount == other.infoCount &&
          warningCount == other.warningCount &&
          errorCount == other.errorCount &&
          elapsed == other.elapsed &&
          _listEquals(failures, other.failures);

  @override
  int get hashCode => Object.hash(
    runtimeType,
    totalEntries,
    traceCount,
    debugCount,
    infoCount,
    warningCount,
    errorCount,
    elapsed,
    Object.hashAll(failures),
  );

  static bool _listEquals<T>(final List<T> a, final List<T> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// A CI/CD [Handler] targeting GitHub Actions `$GITHUB_STEP_SUMMARY` reports.
///
/// Automatically resolves `Platform.environment['GITHUB_STEP_SUMMARY']` unless
/// an explicit [path] is supplied, falling back to [fallbackPath] or an
/// in-memory no-op collector when running outside CI.
///
/// Collects severity counts and failure diagnostics into [summary], optionally
/// streams formatted log entries, and appends a rollup summary table when
/// [writeSummary] or [dispose] is called.
@immutable
class GitHubStepSummaryHandler extends Handler {
  /// Creates a [GitHubStepSummaryHandler].
  factory GitHubStepSummaryHandler({
    final String title = 'Log Summary',
    final String? path,
    final String? fallbackPath,
    final bool tableMode = true,
    final bool includeEntries = true,
    final bool includeSummaryRollup = true,
    final int maxFailures = 50,
    final MarkdownDialect dialect = MarkdownDialect.gfm,
    final Set<LogMetadata> metadata = const {
      LogMetadata.timestamp,
      LogMetadata.logger,
    },
    final LogFormatter? formatter,
    final List<LogDecorator>? decorators,
    final List<LogFilter> filters = const [],
    final LogEngine engine = const StandardEngine(),
    final Duration? timeout,
  }) {
    final resolvedPath = _resolvePath(path, fallbackPath);
    final collector = _SummaryCollector(maxFailures: maxFailures);
    final effectiveFormatter =
        formatter ??
        (tableMode
            ? MarkdownTableFormatter(metadata: metadata, dialect: dialect)
            : MarkdownFormatter(metadata: metadata, dialect: dialect));

    final fileSink = (resolvedPath != null && includeEntries)
        ? FileSink(resolvedPath, encoder: const AutoTextEncoder())
        : null;

    final sink = _StepSummarySink(
      collector: collector,
      delegateSink: fileSink,
      resolvedPath: resolvedPath,
      title: title,
      dialect: dialect,
      includeSummaryRollup: includeSummaryRollup,
    );

    return GitHubStepSummaryHandler._(
      title: title,
      resolvedPath: resolvedPath,
      collector: collector,
      summarySink: sink,
      formatter: effectiveFormatter,
      sink: sink,
      decorators: decorators ?? const [],
      filters: filters,
      engine: engine,
      timeout: timeout,
    );
  }

  const GitHubStepSummaryHandler._({
    required this.title,
    required this.resolvedPath,
    required final _SummaryCollector collector,
    required final _StepSummarySink summarySink,
    required super.formatter,
    required super.sink,
    super.decorators = const [],
    super.filters = const [],
    super.engine = const StandardEngine(),
    super.timeout,
  }) : _collector = collector,
       _summarySink = summarySink;

  /// Section title rendered in the generated rollup summary.
  final String title;

  /// Resolved output file path (`path`, `GITHUB_STEP_SUMMARY`, or `fallbackPath`).
  final String? resolvedPath;

  final _SummaryCollector _collector;
  final _StepSummarySink _summarySink;

  /// Current immutable [MarkdownRunSummary] snapshot of processed log entries.
  MarkdownRunSummary get summary => _collector.snapshot();

  /// Writes the formatted [summary] rollup to [resolvedPath], if configured.
  ///
  /// Safe to call explicitly before process exit; calling [dispose] invokes
  /// this automatically if not already written.
  Future<void> writeSummary() => _summarySink.writeSummaryOnce();

  static String? _resolvePath(final String? path, final String? fallbackPath) {
    if (path != null && path.trim().isNotEmpty) {
      return path.trim();
    }
    final envPath = readGitHubStepSummaryEnv();
    if (envPath != null) {
      return envPath;
    }
    if (fallbackPath != null && fallbackPath.trim().isNotEmpty) {
      return fallbackPath.trim();
    }
    return null;
  }
}

final class _SummaryCollector {
  _SummaryCollector({required this.maxFailures})
    : _stopwatch = Stopwatch()..start();

  final int maxFailures;
  final Stopwatch _stopwatch;

  int _total = 0;
  int _trace = 0;
  int _debug = 0;
  int _info = 0;
  int _warning = 0;
  int _error = 0;
  final List<MarkdownSummaryFailure> _failures = [];

  void record(final LogEntry entry) {
    _total++;
    switch (entry.level) {
      case LogLevel.trace:
        _trace++;
      case LogLevel.debug:
        _debug++;
      case LogLevel.info:
        _info++;
      case LogLevel.warning:
        _warning++;
      case LogLevel.error:
        _error++;
    }

    if ((entry.level == LogLevel.warning ||
            entry.level == LogLevel.error ||
            entry.error != null) &&
        _failures.length < maxFailures) {
      _failures.add(
        MarkdownSummaryFailure(
          timestamp: entry.timestamp,
          loggerName: entry.loggerName,
          level: entry.level,
          message: entry.message,
          error: entry.error?.toString(),
          stackTrace: entry.stackTrace?.toString(),
        ),
      );
    }
  }

  MarkdownRunSummary snapshot() => MarkdownRunSummary(
    totalEntries: _total,
    traceCount: _trace,
    debugCount: _debug,
    infoCount: _info,
    warningCount: _warning,
    errorCount: _error,
    elapsed: _stopwatch.elapsed,
    failures: _failures,
  );
}

base class _StepSummarySink extends LogSink<LogDocument> {
  _StepSummarySink({
    required this.collector,
    required this.delegateSink,
    required this.resolvedPath,
    required this.title,
    required this.dialect,
    required this.includeSummaryRollup,
  });

  final _SummaryCollector collector;
  final LogSink<LogDocument>? delegateSink;
  final String? resolvedPath;
  final String title;
  final MarkdownDialect dialect;
  final bool includeSummaryRollup;
  bool _summaryWritten = false;

  @override
  Future<void> output(
    final LogDocument data,
    final LogEntry entry,
    final LogLevel level,
    final LogPipelineFactory factory,
  ) async {
    collector.record(entry);
    final target = delegateSink;
    if (target != null) {
      await target.output(data, entry, level, factory);
    }
  }

  @override
  Future<void> flush() async {
    final target = delegateSink;
    if (target != null) {
      await target.flush();
    }
  }

  Future<void> writeSummaryOnce() async {
    if (_summaryWritten || !includeSummaryRollup || resolvedPath == null) {
      return;
    }
    _summaryWritten = true;
    await flush();
    final markdown =
        '\n${collector.snapshot().toMarkdown(title: title, dialect: dialect)}\n';
    await appendStepSummaryFile(resolvedPath!, markdown);
  }

  @override
  Future<void> dispose() async {
    await writeSummaryOnce();
    final target = delegateSink;
    if (target != null) {
      await target.dispose();
    }
  }
}
