import 'dart:io';

import 'package:logd/logd.dart';
import 'package:logd_html/logd_html.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlView Modular Components', () {
    late LogPipelineFactory factory;
    late HandlerContext context;

    setUp(() {
      factory = const StandardEngine().factory;
      context = factory.checkoutContext();
    });

    test('default HtmlView renders complete standalone document', () {
      const encoder = HtmlEncoder(view: HtmlView(title: 'Default Test'));
      encoder
        ..preamble(context, LogLevel.info, factory)
        ..postamble(context, LogLevel.info, factory);

      final output = String.fromCharCodes(context.takeBytes());

      expect(output, contains('<!DOCTYPE html>'));
      expect(output, contains('<title>Default Test</title>'));
      expect(output, contains('<header class="log-session-header">'));
      expect(output, contains('LOGD'));
      expect(output, contains('<div class="log-control-panel">'));
      expect(output, contains('id="log-search-input"'));
      expect(output, contains('data-level="trace"'));
      expect(output, contains('<footer class="log-page-footer">'));
      expect(output, contains('<script>'));
      expect(output, contains('</body>\n</html>'));
    });

    test('HtmlView.embedded renders fragment without HTML document shell', () {
      const encoder = HtmlEncoder(
        view: HtmlView.embedded(title: 'Embedded Widget'),
      );
      encoder
        ..preamble(context, LogLevel.info, factory)
        ..postamble(context, LogLevel.info, factory);

      final output = String.fromCharCodes(context.takeBytes());

      expect(output, isNot(contains('<!DOCTYPE html>')));
      expect(output, isNot(contains('<title>')));
      expect(output, isNot(contains('<body>')));
      expect(output, isNot(contains('</html>')));
      expect(output, contains('<div class="log-container log-embedded">'));
      expect(output, contains('<style>'));
      expect(output, contains('<div class="log-control-panel">'));
      expect(output, contains('<script>'));
      expect(output, contains('</script>'));
    });

    test(
      'custom HtmlHeaderComponent renders tailored branding and metadata',
      () {
        const encoder = HtmlEncoder(
          view: HtmlView(
            title: 'Production Logs',
            header: DefaultHtmlHeader(
              logoText: 'ACME CORP',
              subtitle: 'us-east-1 production',
              showDate: false,
            ),
          ),
        );
        encoder.preamble(context, LogLevel.info, factory);

        final output = String.fromCharCodes(context.takeBytes());

        expect(output, contains('ACME CORP'));
        expect(output, contains('us-east-1 production'));
        expect(output, isNot(contains('Session started:')));
      },
    );

    test('custom HtmlControlPanelComponent toggles controls and actions', () {
      const encoder = HtmlEncoder(
        view: HtmlView(
          controlPanel: DefaultHtmlControlPanel(
            showSearch: false,
            showExpandCollapse: false,
            extraActions: [
              HtmlActionButton(
                id: 'btn-export-json',
                label: 'Export JSON',
                onClickJs: 'exportLogs()',
                cssClass: 'btn-primary',
              ),
            ],
          ),
        ),
      );
      encoder.preamble(context, LogLevel.info, factory);

      final output = String.fromCharCodes(context.takeBytes());

      expect(output, isNot(contains('id="log-search-input"')));
      expect(output, isNot(contains('id="btn-expand-all"')));
      expect(output, contains('id="btn-export-json"'));
      expect(output, contains('onclick="exportLogs()"'));
      expect(output, contains('Export JSON'));
      expect(output, contains('btn-primary'));
    });

    test('DefaultHtmlControlPanel with showLoggerFilter renders logger select '
        'dropdown', () {
      const encoder = HtmlEncoder(
        view: HtmlView(
          controlPanel: DefaultHtmlControlPanel(showLoggerFilter: true),
        ),
      );
      encoder.preamble(context, LogLevel.info, factory);

      final output = String.fromCharCodes(context.takeBytes());

      expect(output, contains('<select id="log-logger-select"'));
      expect(output, contains('All Loggers'));
    });

    test(
      'DefaultHtmlControlPanel.all enables all tools including logger select',
      () {
        const panel = DefaultHtmlControlPanel.all();
        expect(panel.showSearch, isTrue);
        expect(panel.showLevelFilters, isTrue);
        expect(panel.showExpandCollapse, isTrue);
        expect(panel.showRegexToggle, isTrue);
        expect(panel.showExportActions, isTrue);
        expect(panel.showThemeToggle, isTrue);
        expect(panel.showLiveFollow, isTrue);
        expect(panel.showLoggerFilter, isTrue);
      },
    );

    test('HtmlStylesheet buildJs contains flat-index search and context '
        'click-to-isolate', () {
      const stylesheet = DefaultHtmlStylesheet();
      final js = stylesheet.buildJs();

      expect(js, contains('buildLogIndex()'));
      expect(js, contains('ensureIndex()'));
      expect(js, contains('populateLoggerDropdown()'));
      expect(js, contains("closest('.log-val')"));
      expect(js, contains('debounceTimer'));
    });

    test('custom HtmlFooterComponent renders custom attribution', () {
      const encoder = HtmlEncoder(
        view: HtmlView(
          footer: DefaultHtmlFooter(
            attribution: 'Internal Tooling',
            customContent: '<span class="confidential">CONFIDENTIAL</span>',
          ),
        ),
      );
      encoder.postamble(context, LogLevel.info, factory);

      final output = String.fromCharCodes(context.takeBytes());

      expect(output, contains('Internal Tooling'));
      expect(output, contains('CONFIDENTIAL'));
    });

    test(
      'HtmlView with injectScripts false omits script tags in postamble',
      () {
        const encoder = HtmlEncoder(view: HtmlView(injectScripts: false));
        encoder.postamble(context, LogLevel.info, factory);

        final output = String.fromCharCodes(context.takeBytes());

        expect(output, isNot(contains('<script>')));
        expect(output, contains('</div>'));
        expect(output, contains('</body>\n</html>'));
      },
    );

    test('fully custom HtmlHeaderComponent implementation is supported', () {
      const customHeader = _FullyCustomHeader();
      const encoder = HtmlEncoder(view: HtmlView(header: customHeader));
      encoder.preamble(context, LogLevel.info, factory);

      final output = String.fromCharCodes(context.takeBytes());

      expect(output, contains('<nav class="my-custom-portal-header">'));
      expect(output, contains('PORTAL-V2'));
    });

    test('HtmlFormatter formats document and injects configured HtmlView', () {
      const view = HtmlView(
        title: 'Formatter Test',
        header: DefaultHtmlHeader(logoText: 'FORMATTER-LOGO'),
      );
      const formatter = HtmlFormatter(view: view);
      final doc = factory.checkoutDocument();

      formatter.format(
        LogEntry(
          level: LogLevel.info,
          message: 'Test Formatter Message',
          loggerName: 'test.formatter',
          origin: 'test.dart:10',
          timestamp: '2026-11-16 01:00:00',
        ),
        doc,
        factory,
      );

      final injectedEncoder =
          doc.metadata[AutoEncoder.encoderKey] as HtmlEncoder?;
      expect(injectedEncoder, isNotNull);
      expect(injectedEncoder!.effectiveView.title, equals('Formatter Test'));
      expect(
        (injectedEncoder.effectiveView.header! as DefaultHtmlHeader).logoText,
        equals('FORMATTER-LOGO'),
      );
    });

    test('HtmlFormatter equality and hashCode accounts for view', () {
      const view1 = HtmlView(title: 'View A');
      const view2 = HtmlView(title: 'View B');

      const formatter1 = HtmlFormatter(view: view1);
      const formatter1Copy = HtmlFormatter(view: view1);
      const formatter2 = HtmlFormatter(view: view2);

      expect(formatter1, equals(formatter1Copy));
      expect(formatter1.hashCode, equals(formatter1Copy.hashCode));
      expect(formatter1, isNot(equals(formatter2)));
    });

    test('DefaultHtmlControlPanel.all renders all advanced tool buttons', () {
      const panel = DefaultHtmlControlPanel.all();
      final markup = panel.render(theme: const DarkTheme());

      expect(markup, contains('id="btn-regex-toggle"'));
      expect(markup, contains('id="btn-theme-toggle"'));
      expect(markup, contains('id="btn-live-follow"'));
      expect(markup, contains('id="btn-export-json"'));
      expect(markup, contains('id="btn-export-csv"'));
      expect(markup, contains('id="btn-expand-all"'));
      expect(markup, contains('id="btn-collapse-all"'));
    });

    test(
      'DefaultHtmlControlPanel granular toggles render only enabled buttons',
      () {
        const panel = DefaultHtmlControlPanel(
          showRegexToggle: true,
          showExportActions: true,
        );
        final markup = panel.render(theme: const DarkTheme());

        expect(markup, contains('id="btn-regex-toggle"'));
        expect(markup, contains('id="btn-export-json"'));
        expect(markup, contains('id="btn-export-csv"'));
        expect(markup, isNot(contains('id="btn-theme-toggle"')));
        expect(markup, isNot(contains('id="btn-live-follow"')));
      },
    );

    test('DefaultHtmlControlPanel value equality and hashCode', () {
      const p1 = DefaultHtmlControlPanel(showRegexToggle: true);
      const p1Copy = DefaultHtmlControlPanel(showRegexToggle: true);
      const p2 = DefaultHtmlControlPanel(showRegexToggle: false);

      expect(p1, equals(p1Copy));
      expect(p1.hashCode, equals(p1Copy.hashCode));
      expect(p1, isNot(equals(p2)));
    });

    test('DefaultHtmlHeader, DefaultHtmlFooter and HtmlActionButton equality '
        'and hashCode', () {
      const h1 = DefaultHtmlHeader(logoText: 'A');
      const h1Copy = DefaultHtmlHeader(logoText: 'A');
      const h2 = DefaultHtmlHeader(logoText: 'B');
      expect(h1, equals(h1Copy));
      expect(h1.hashCode, equals(h1Copy.hashCode));
      expect(h1, isNot(equals(h2)));

      const f1 = DefaultHtmlFooter(attribution: 'A');
      const f1Copy = DefaultHtmlFooter(attribution: 'A');
      const f2 = DefaultHtmlFooter(attribution: 'B');
      expect(f1, equals(f1Copy));
      expect(f1.hashCode, equals(f1Copy.hashCode));
      expect(f1, isNot(equals(f2)));

      const btn1 = HtmlActionButton(id: '1', label: 'One');
      const btn1Copy = HtmlActionButton(id: '1', label: 'One');
      const btn2 = HtmlActionButton(id: '2', label: 'Two');
      expect(btn1, equals(btn1Copy));
      expect(btn1.hashCode, equals(btn1Copy.hashCode));
      expect(btn1, isNot(equals(btn2)));
    });

    test('HtmlView value equality and hashCode', () {
      const v1 = HtmlView(title: 'T1');
      const v1Copy = HtmlView(title: 'T1');
      const v2 = HtmlView(title: 'T2');

      expect(v1, equals(v1Copy));
      expect(v1.hashCode, equals(v1Copy.hashCode));
      expect(v1, isNot(equals(v2)));
    });

    test('DefaultHtmlStylesheet buildCss and buildJs include advanced search '
        'and export features', () {
      const stylesheet = DefaultHtmlStylesheet();
      final css = stylesheet.buildCss(const DarkTheme());
      final js = stylesheet.buildJs();

      expect(css, contains('.log-search-tool-btn'));
      expect(css, contains('mark.log-search-match'));
      expect(css, contains('.light-theme'));

      expect(js, contains('isRegexMode'));
      expect(js, contains('escapeRegex'));
      expect(js, contains('btn-regex-toggle'));
      expect(js, contains('btn-theme-toggle'));
      expect(js, contains('btn-live-follow'));
      expect(js, contains('btn-export-json'));
      expect(js, contains('btn-export-csv'));
    });
  });

  group('HtmlFileHandler with HtmlView Integration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logd_html_view_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test(
      'synchronous HtmlFileHandler with custom HtmlView writes correctly',
      () async {
        final file = File('${tempDir.path}/custom_view.html');
        final handler = HtmlFileHandler(
          path: file.path,
          view: const HtmlView(
            title: 'Custom Synchronous Session',
            header: DefaultHtmlHeader(logoText: 'TEST-LOGO'),
          ),
        );

        Logger.configure('html_view_sync', handlers: [handler]);
        Logger.get('html_view_sync').info('Sync message with custom view');
        await handler.dispose();

        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();
        expect(content, contains('TEST-LOGO'));
        expect(content, contains('Custom Synchronous Session'));
        expect(content, contains('Sync message with custom view'));
      },
    );

    test(
      'asynchronous HtmlFileHandler with HtmlView.embedded offloads cleanly',
      () async {
        final file = File('${tempDir.path}/embedded_view.html');
        final handler = HtmlFileHandler.async(
          path: file.path,
          view: const HtmlView.embedded(title: 'Embedded Async'),
        );

        Logger.configure('html_view_async', handlers: [handler]);
        Logger.get('html_view_async').info('Embedded async telemetry message');

        await Logger.shutdown();

        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();
        expect(content, isNot(contains('<!DOCTYPE html>')));
        expect(content, contains('log-embedded'));
        expect(content, contains('Embedded async telemetry message'));
      },
    );

    test(
      'HtmlFileHandler with custom HtmlView preserves view on file rotation',
      () async {
        final file = File('${tempDir.path}/rot_view.html');
        final handler = HtmlFileHandler(
          path: file.path,
          view: const HtmlView(
            title: 'Rotated View Test',
            header: DefaultHtmlHeader(logoText: 'ROT-BRAND'),
            footer: DefaultHtmlFooter(attribution: 'ROT-ATTRIBUTION'),
          ),
          fileRotation: SizeRotation(maxSize: '10KB', backupCount: 2),
        );

        final logger = Logger.get('html_view_rot');
        Logger.configure('html_view_rot', handlers: [handler]);

        // Emit two batches of logs to trigger size-based rotation
        logger.info('First log before rotation in rot_view.html');
        await handler.flush();

        logger.info('Second log triggering rotation into new file');
        await handler.dispose();

        expect(file.existsSync(), isTrue);
        final activeContent = file.readAsStringSync();
        expect(activeContent, contains('ROT-BRAND'));
        expect(activeContent, contains('ROT-ATTRIBUTION'));

        final rotatedFile = File('${tempDir.path}/rot_view.1.html');
        if (rotatedFile.existsSync()) {
          final rotatedContent = rotatedFile.readAsStringSync();
          expect(rotatedContent, contains('ROT-BRAND'));
          expect(rotatedContent, contains('ROT-ATTRIBUTION'));
        }
      },
    );

    test('includeExternalFonts controls Google Fonts CDN injection', () {
      const engineFactory = StandardPipelineFactory();
      final testContext = engineFactory.checkoutContext();
      try {
        // By default (false), external fonts are omitted for air-gapped
        // security.
        const defaultView = HtmlView(title: 'Air Gapped Test');
        const defaultEncoder = HtmlEncoder(view: defaultView);
        defaultEncoder.preamble(testContext, LogLevel.info, engineFactory);
        var output = String.fromCharCodes(testContext.takeBytes());
        expect(output, isNot(contains('fonts.googleapis.com')));

        // When explicitly enabled, external font links must be injected
        const fontsView = HtmlView(
          title: 'Fonts Test',
          includeExternalFonts: true,
        );
        const fontsEncoder = HtmlEncoder(view: fontsView);
        fontsEncoder.preamble(testContext, LogLevel.info, engineFactory);
        output = String.fromCharCodes(testContext.takeBytes());
        expect(output, contains('fonts.googleapis.com'));
      } finally {
        engineFactory.release(testContext);
      }
    });

    test('copyWith works across all modular view components', () {
      const header = DefaultHtmlHeader(logoText: 'ORIG');
      final updatedHeader = header.copyWith(
        logoText: 'MODIFIED',
        subtitle: 'v2',
      );
      expect(updatedHeader.logoText, 'MODIFIED');
      expect(updatedHeader.subtitle, 'v2');
      expect(updatedHeader.showDate, isTrue);

      const panel = DefaultHtmlControlPanel(showSearch: false);
      final updatedPanel = panel.copyWith(
        showSearch: true,
        showThemeToggle: true,
      );
      expect(updatedPanel.showSearch, isTrue);
      expect(updatedPanel.showThemeToggle, isTrue);

      const footer = DefaultHtmlFooter(attribution: 'ATTR');
      final updatedFooter = footer.copyWith(customContent: 'CUSTOM');
      expect(updatedFooter.attribution, 'ATTR');
      expect(updatedFooter.customContent, 'CUSTOM');

      const view = HtmlView(title: 'ORIG_TITLE');
      final updatedView = view.copyWith(
        title: 'NEW_TITLE',
        includeExternalFonts: true,
      );
      expect(updatedView.title, 'NEW_TITLE');
      expect(updatedView.includeExternalFonts, isTrue);
    });

    test(
      'sessionLabel customizes resumption delimiter in appendSession mode',
      () async {
        final file = File('${tempDir.path}/custom_session.html');
        final handler1 = HtmlFileHandler(
          path: file.path,
          fileMode: HtmlFileMode.appendSession,
        );
        Logger.configure('sess_logger', handlers: [handler1]);
        Logger.get('sess_logger').info('Message from run 1');
        await handler1.dispose();

        // Session 2 with custom sessionLabel
        final handler2 = HtmlFileHandler(
          path: file.path,
          fileMode: HtmlFileMode.appendSession,
          sessionLabel: 'Pod: worker-east-2 • Commit: 8ab2f',
        );
        Logger.configure('sess_logger', handlers: [handler2]);
        Logger.get('sess_logger').info('Message from run 2');
        await handler2.dispose();

        final content = file.readAsStringSync();
        expect(content, contains('Pod: worker-east-2 • Commit: 8ab2f'));
      },
    );

    test(
      'HtmlFileSink dispose is idempotent and safe against multiple calls',
      () async {
        final file = File('${tempDir.path}/idempotent_dispose.html');
        final sink = HtmlFileSink(file.path);
        // Multiple disposes must not throw or cause reference count issues
        await sink.dispose();
        await sink.dispose();
        await sink.dispose();
      },
    );
  });
}

class _FullyCustomHeader implements HtmlHeaderComponent {
  const _FullyCustomHeader();

  @override
  String render({
    required final String title,
    required final DateTime sessionStart,
    required final LogTheme theme,
  }) => '<nav class="my-custom-portal-header"><span>PORTAL-V2</span></nav>\n';
}
