import 'dart:convert';
import 'package:logd/logd.dart';
import 'package:logd_markdown/logd_markdown.dart';
import 'package:test/test.dart';

LogDocument formatDoc(
  final LogFormatter formatter,
  final LogEntry entry, {
  final LogPipelineFactory? factory,
}) {
  final f = factory ?? const StandardPipelineFactory();
  final doc = f.checkoutDocument();
  formatter.format(entry, doc, f);
  return doc;
}

void main() {
  group('MarkdownEncoder', () {
    const encoder = MarkdownEncoder();
    const factory = StandardPipelineFactory();

    test('renders StructuredFormatter IR with GFM elements', () {
      const formatter = StructuredFormatter(
        metadata: {LogMetadata.logger, LogMetadata.timestamp},
      );
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'Hello Markdown',
        loggerName: 'test',
        timestamp: '2023-10-27T10:00:00.000Z',
        origin: 'test.dart:42',
      );

      final document = formatDoc(formatter, entry);
      final context = HandlerContext();
      encoder.encode(entry, document, LogLevel.info, context, factory);
      final output = const Utf8Decoder().convert(context.takeBytes());

      expect(
        output,
        contains('### ℹ️ 2023-10-27T10:00:00.000Z [INFO] [test]'),
      );
      expect(output, contains('**Hello Markdown**'));
      expect(output, contains('---'));
    });

    test('renders Error and StackTrace in GFM blocks', () {
      const formatter = StructuredFormatter(metadata: {});
      final entry = LogEntry(
        level: LogLevel.error,
        message: 'Fatal Error',
        loggerName: 'test',
        timestamp: '2023-10-27T10:00:00.000Z',
        origin: 'test.dart:42',
        error: 'System failure',
        stackTrace: StackTrace.fromString('line 1\nline 2'),
      );

      final document = formatDoc(formatter, entry);
      final context = HandlerContext();
      encoder.encode(entry, document, LogLevel.error, context, factory);
      final output = const Utf8Decoder().convert(context.takeBytes());

      expect(output, contains('### ❌ [ERROR]'));
      expect(output, contains('> [!ERROR]'));
      expect(output, contains('**Fatal Error**'));
      expect(output, contains('line 1'));
    });

    test('renders JsonFormatter map as a code block', () {
      const formatter = JsonFormatter(metadata: {});
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'JSON Event',
        loggerName: 'test',
        timestamp: '2023-10-27T10:00:00.000Z',
        origin: 'test.dart:42',
      );

      final document = formatDoc(formatter, entry);
      final context = HandlerContext();
      encoder.encode(entry, document, LogLevel.info, context, factory);
      final output = const Utf8Decoder().convert(context.takeBytes());

      expect(output, contains('```json'));
      expect(output, contains('"level":"info"'));
      expect(output, contains('"message":"JSON Event"'));
      expect(output, contains('```'));
    });

    test('preserves messages with Markdown special characters and pipes', () {
      const formatter = StructuredFormatter(metadata: {});
      final entry = LogEntry(
        level: LogLevel.warning,
        message:
            '| col1 | col2 |\n# Heading\n```dart\nfinal x = 1;\n```\n**bold**',
        loggerName: 'test.special',
        timestamp: '2023-10-27T10:00:00.000Z',
        origin: 'test.dart:42',
      );

      final document = formatDoc(formatter, entry);
      final context = HandlerContext();
      encoder.encode(entry, document, LogLevel.warning, context, factory);
      final output = const Utf8Decoder().convert(context.takeBytes());

      expect(output, contains('| col1 | col2 |'));
      expect(output, contains('# Heading'));
      expect(output, contains('```dart'));
      expect(output, contains('**bold**'));
    });

    test('renders TableNode with GFM table syntax', () {
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'Table test',
        loggerName: 'test',
        timestamp: '2023-10-27T10:00:00.000Z',
        origin: 'test.dart:1',
      );

      final document = factory.checkoutDocument();
      document.writeNode(
        TableNode(
          title: const StyledText('Summary Table'),
          children: [
            TableRowNode(
              children: [
                TableCellNode(children: [
                  MessageNode(segments: [const StyledText('Header 1')])
                ]),
                TableCellNode(children: [
                  MessageNode(segments: [const StyledText('Header 2')])
                ]),
              ],
            ),
            TableRowNode(
              children: [
                TableCellNode(children: [
                  MessageNode(segments: [const StyledText('Val 1')])
                ]),
                TableCellNode(children: [
                  MessageNode(segments: [const StyledText('Val 2')])
                ]),
              ],
            ),
          ],
        ),
      );

      final context = HandlerContext();
      encoder.encode(entry, document, LogLevel.info, context, factory);
      final output = const Utf8Decoder().convert(context.takeBytes());

      expect(output, contains('**Summary Table**'));
      expect(output, contains('| **Header 1** | **Header 2** |'));
      expect(output, contains('| --- | --- |'));
      expect(output, contains('| **Val 1** | **Val 2** |'));
    });

    test('renders ListNode with GFM bullet list', () {
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'List test',
        loggerName: 'test',
        timestamp: '2023-10-27T10:00:00.000Z',
        origin: 'test.dart:1',
      );

      final document = factory.checkoutDocument();
      document.writeNode(ListNode(['First item', 'Second item', 42]));

      final context = HandlerContext();
      encoder.encode(entry, document, LogLevel.info, context, factory);
      final output = const Utf8Decoder().convert(context.takeBytes());

      expect(output, contains('- First item'));
      expect(output, contains('- Second item'));
      expect(output, contains('- 42'));
    });

    test('renders SectionNode with GFM details/summary', () {
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'Section test',
        loggerName: 'test',
        timestamp: '2023-10-27T10:00:00.000Z',
        origin: 'test.dart:1',
      );

      final document = factory.checkoutDocument();
      document.writeNode(
        SectionNode(
          summary: MessageNode(segments: [const StyledText('Click to expand')]),
          children: [
            MessageNode(segments: [const StyledText('Hidden content line')]),
          ],
        ),
      );

      final context = HandlerContext();
      encoder.encode(entry, document, LogLevel.info, context, factory);
      final output = const Utf8Decoder().convert(context.takeBytes());

      expect(output, contains('<details>'));
      expect(output, contains('<summary>**Click to expand**'));
      expect(output, contains('**Hidden content line**'));
      expect(output, contains('</details>'));
    });

    test('renders MetadataNode with GFM alert note', () {
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'Metadata test',
        loggerName: 'test',
        timestamp: '2023-10-27T10:00:00.000Z',
        origin: 'test.dart:1',
      );

      final document = factory.checkoutDocument();
      document.writeNode(
        MetadataNode(
          segments: [const StyledText('Diagnostic key=value thread=main')],
        ),
      );

      final context = HandlerContext();
      encoder.encode(entry, document, LogLevel.info, context, factory);
      final output = const Utf8Decoder().convert(context.takeBytes());

      expect(output, contains('> [!NOTE]'));
      expect(output, contains('Diagnostic key=value thread=main'));
    });

    test('renders nested structures with all concrete node types', () {
      final entry = LogEntry(
        level: LogLevel.warning,
        message: 'All-nodes audit',
        loggerName: 'audit',
        timestamp: '2023-10-27T10:00:00.000Z',
        origin: 'audit.dart:1',
      );

      final document = factory.checkoutDocument();
      document
        ..writeNode(
          BoxNode(
            title: const StyledText('System Audit'),
            children: [
              SectionNode(
                summary:
                    MessageNode(segments: [const StyledText('Table Details')]),
                children: [
                  TableNode(
                    title: const StyledText('Metrics'),
                    children: [
                      TableRowNode(
                        children: [
                          TableCellNode(children: [
                            MessageNode(segments: [const StyledText('Metric')])
                          ]),
                          TableCellNode(children: [
                            MessageNode(segments: [const StyledText('Value')])
                          ]),
                        ],
                      ),
                      TableRowNode(
                        children: [
                          TableCellNode(children: [
                            MessageNode(segments: [const StyledText('CPU')])
                          ]),
                          TableCellNode(children: [
                            MessageNode(segments: [const StyledText('12%')])
                          ]),
                        ],
                      ),
                    ],
                  ),
                  IndentationNode(
                    children: [
                      ListNode(['Worker Alpha', 'Worker Beta']),
                    ],
                  ),
                ],
              ),
            ],
          ),
        )
        ..writeNode(
            MetadataNode(segments: [const StyledText('Host: worker-1')]))
        ..writeNode(AlignmentNode(children: [
          MessageNode(segments: [const StyledText('Aligned Message')])
        ]))
        ..writeNode(RowNode(children: [
          MessageNode(segments: [const StyledText('Left')]),
          MessageNode(segments: [const StyledText('Right')])
        ]))
        ..writeNode(ParagraphNode(children: [
          MessageNode(segments: [const StyledText('Paragraph content')])
        ]))
        ..writeNode(
            ErrorNode(segments: [const StyledText('Warning anomaly detected')]))
        ..writeNode(FooterNode(segments: [const StyledText('End of audit')]));

      final context = HandlerContext();
      encoder.encode(entry, document, LogLevel.warning, context, factory);
      final output = const Utf8Decoder().convert(context.takeBytes());

      // Verify all elements rendered without exception or data loss
      expect(output, contains('> [!NOTE]'));
      expect(output, contains('System Audit'));
      expect(output, contains('<details>'));
      expect(output, contains('<summary>**Table Details**'));
      expect(output, contains('**Metrics**'));
      expect(output, contains('| **Metric** | **Value** |'));
      expect(output, contains('| **CPU** | **12%** |'));
      expect(output, contains('- Worker Alpha'));
      expect(output, contains('- Worker Beta'));
      expect(output, contains('Host: worker-1'));
      expect(output, contains('**Aligned Message**'));
      expect(output, contains('**Left**'));
      expect(output, contains('**Right**'));
      expect(output, contains('**Paragraph content**'));
      expect(output, contains('> [!ERROR]'));
      expect(output, contains('Warning anomaly detected'));
      expect(output, contains('End of audit'));
    });

    test('wrappingStrategy returns WrappingStrategy.none', () {
      expect(encoder.wrappingStrategy, equals(WrappingStrategy.none));
    });
  });
}
