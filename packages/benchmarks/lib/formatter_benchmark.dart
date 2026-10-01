// ignore_for_file: invalid_use_of_internal_member, implementation_imports
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:logd/logd.dart';
import 'package:logd/src/handler/handler.dart' show TerminalLayout;
import 'package:logd_markdown/logd_markdown.dart';
import 'package:logd_toon/logd_toon.dart';

// Helper to create a dummy LogEntry
LogEntry createEntry() {
  return LogEntry(
    level: LogLevel.info,
    message: 'This is a benchmark log message with typical length.',
    loggerName: 'benchmark.logger',
    timestamp: '2023-10-27T10:00:00.000Z',
    origin: 'benchmark.dart:42',
  );
}

abstract class FormatterBenchmark extends BenchmarkBase {
  FormatterBenchmark(super.name);

  late LogEntry entry;
  late LogFormatter formatter;

  @override
  void setup() {
    entry = createEntry();
    formatter = createFormatter();
  }

  LogFormatter createFormatter();

  @override
  void run() {
    final factory = Arena.instance;
    final doc = factory.checkoutDocument();
    try {
      formatter.format(entry, doc, factory);
      final layout = TerminalLayout(width: 80, factory: factory);
      final lines = layout.layout(doc, LogLevel.info).lines;
      for (final _ in lines) {}
    } finally {
      doc.releaseRecursive(factory);
    }
  }
}

class PlainFormatterBenchmark extends FormatterBenchmark {
  PlainFormatterBenchmark() : super('PlainFormatter');

  @override
  LogFormatter createFormatter() => const PlainFormatter();
}

class StructuredFormatterBenchmark extends FormatterBenchmark {
  StructuredFormatterBenchmark() : super('StructuredFormatter');

  @override
  LogFormatter createFormatter() => const StructuredFormatter();
}

class ToonFormatterBenchmark extends FormatterBenchmark {
  ToonFormatterBenchmark() : super('ToonFormatter');

  @override
  LogFormatter createFormatter() => const ToonFormatter();
}

class JsonFormatterBenchmark extends FormatterBenchmark {
  JsonFormatterBenchmark() : super('JsonFormatter');

  @override
  LogFormatter createFormatter() => const JsonFormatter();
}

class JsonPrettyFormatterBenchmark extends FormatterBenchmark {
  JsonPrettyFormatterBenchmark() : super('JsonPrettyFormatter');

  @override
  LogFormatter createFormatter() => const JsonPrettyFormatter();
}

class MarkdownEncoderBenchmark extends BenchmarkBase {
  MarkdownEncoderBenchmark() : super('MarkdownEncoder');

  late LogEntry entry;
  late LogDocument doc;
  late LogPipelineFactory factory;
  late HandlerContext context;

  @override
  void setup() {
    entry = createEntry();
    factory = Arena.instance;
    doc = factory.checkoutDocument();
    context = factory.checkoutContext();
    const StructuredFormatter().format(entry, doc, factory);
  }

  @override
  void run() {
    const MarkdownEncoder().encode(entry, doc, LogLevel.info, context, factory);
    context.takeBytes();
  }
}

void runFormatterBenchmarks() {
  print('\n--- Formatter Throughput ---');
  PlainFormatterBenchmark().report();
  StructuredFormatterBenchmark().report();
  ToonFormatterBenchmark().report();
  JsonFormatterBenchmark().report();
  JsonPrettyFormatterBenchmark().report();
  MarkdownEncoderBenchmark().report();
}
