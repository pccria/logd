// ignore_for_file: comment_references

import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'html_stylesheet.dart';

/// A pluggable component that renders the top header of an HTML log session.
abstract interface class HtmlHeaderComponent {
  /// Renders the HTML markup for the header block.
  String render({
    required final String title,
    required final DateTime sessionStart,
    required final LogTheme theme,
  });
}

/// The default session header containing branding logo, title, and session
/// start time.
@immutable
class DefaultHtmlHeader implements HtmlHeaderComponent {
  /// Creates a [DefaultHtmlHeader].
  const DefaultHtmlHeader({
    this.logoText = 'LOGD',
    this.showDate = true,
    this.subtitle,
  });

  /// The logo or brand text displayed on the top left.
  final String logoText;

  /// Whether to display the session start date and time.
  final bool showDate;

  /// An optional subtitle or environment label displayed next to the title.
  final String? subtitle;

  @override
  String render({
    required final String title,
    required final DateTime sessionStart,
    required final LogTheme theme,
  }) {
    final t = _escapeHtml(title);
    final logo = _escapeHtml(logoText);
    final dateStr = sessionStart.toString().split('.')[0];
    final sub = subtitle != null
        ? ' <span class="log-session-subtitle">${_escapeHtml(subtitle!)}</span>'
        : '';

    final metaBlock = showDate
        ? '<div class="log-session-meta">\n'
              '      <span class="log-session-date">Session started: $dateStr</span>\n'
              '    </div>'
        : '';

    return '''
  <header class="log-session-header">
    <div class="log-session-branding">
      <span class="log-session-logo">$logo</span>
      <span class="log-header-divider">|</span>
      <span class="log-session-title">$t</span>$sub
    </div>
    $metaBlock
  </header>
''';
  }

  /// Creates a copy of this header with the given fields replaced.
  DefaultHtmlHeader copyWith({
    final String? logoText,
    final bool? showDate,
    final String? subtitle,
  }) => DefaultHtmlHeader(
    logoText: logoText ?? this.logoText,
    showDate: showDate ?? this.showDate,
    subtitle: subtitle ?? this.subtitle,
  );

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is DefaultHtmlHeader &&
          runtimeType == other.runtimeType &&
          logoText == other.logoText &&
          showDate == other.showDate &&
          subtitle == other.subtitle;

  @override
  int get hashCode => Object.hash(runtimeType, logoText, showDate, subtitle);
}

/// Represents an interactive action button in the HTML control panel.
@immutable
class HtmlActionButton {
  /// Creates an [HtmlActionButton].
  const HtmlActionButton({
    required this.id,
    required this.label,
    this.onClickJs,
    this.cssClass,
  });

  /// The DOM element ID for the button.
  final String id;

  /// The label displayed inside the button.
  final String label;

  /// Inline JavaScript to execute on click (e.g. `window.print()`).
  final String? onClickJs;

  /// Additional CSS class names.
  final String? cssClass;

  /// Renders the button as HTML markup.
  String render() {
    final click = onClickJs != null
        ? ' onclick="${_escapeHtml(onClickJs!)}"'
        : '';
    final cls = cssClass != null ? ' ${_escapeHtml(cssClass!)}' : '';
    return '<button class="log-action-btn$cls" id="${_escapeHtml(id)}"$click>'
        '${_escapeHtml(label)}</button>';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is HtmlActionButton &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          onClickJs == other.onClickJs &&
          cssClass == other.cssClass;

  @override
  int get hashCode => Object.hash(runtimeType, id, label, onClickJs, cssClass);
}

/// A pluggable component that renders the interactive control panel.
abstract interface class HtmlControlPanelComponent {
  /// Renders the HTML markup for the control panel.
  String render({required final LogTheme theme});
}

/// The default control panel containing search, level filters, and expand/collapse actions.
@immutable
class DefaultHtmlControlPanel implements HtmlControlPanelComponent {
  /// Creates a [DefaultHtmlControlPanel].
  const DefaultHtmlControlPanel({
    this.showSearch = true,
    this.showLevelFilters = true,
    this.showExpandCollapse = true,
    this.showRegexToggle = false,
    this.showExportActions = false,
    this.showThemeToggle = false,
    this.showLiveFollow = false,
    this.showLoggerFilter = false,
    this.searchPlaceholder = 'Search logs...',
    this.extraActions = const [],
  });

  /// Creates a [DefaultHtmlControlPanel] with all interactive capabilities
  /// enabled.
  const DefaultHtmlControlPanel.all({
    this.showSearch = true,
    this.showLevelFilters = true,
    this.showExpandCollapse = true,
    this.showRegexToggle = true,
    this.showExportActions = true,
    this.showThemeToggle = true,
    this.showLiveFollow = true,
    this.showLoggerFilter = true,
    this.searchPlaceholder = 'Search logs...',
    this.extraActions = const [],
  });

  /// Whether to display the client-side search input bar.
  final bool showSearch;

  /// Whether to display the interactive level toggle buttons.
  final bool showLevelFilters;

  /// Whether to display the Expand All / Collapse All buttons.
  final bool showExpandCollapse;

  /// Whether to display a toggle button for regular expression search mode.
  final bool showRegexToggle;

  /// Whether to display the Export JSON / CSV action buttons.
  final bool showExportActions;

  /// Whether to display the live Dark / Light mode toggle button.
  final bool showThemeToggle;

  /// Whether to display the Live Follow / Auto-Scroll toggle button.
  final bool showLiveFollow;

  /// Whether to display the subsystem/logger dropdown selector.
  final bool showLoggerFilter;

  /// The placeholder text for the search input.
  final String searchPlaceholder;

  /// Additional user-defined action buttons injected into the controls row.
  final List<HtmlActionButton> extraActions;

  @override
  String render({required final LogTheme theme}) {
    final regexBtn = (showSearch && showRegexToggle)
        ? '<button type="button" class="log-search-tool-btn" id="btn-regex-toggle" title="Toggle Regular Expression Search">.*</button>'
        : '';
    final inputClass = showRegexToggle ? ' class="with-tool-btn"' : '';
    final searchBlock = showSearch
        ? '''
      <div class="log-search-wrapper">
        <input type="text" id="log-search-input"$inputClass placeholder="${_escapeHtml(searchPlaceholder)}" autocomplete="off">$regexBtn
      </div>'''
        : '';

    final loggerFilterBlock = showLoggerFilter
        ? '''
      <select id="log-logger-select" class="log-select" title="Filter by Subsystem / Logger">
        <option value="">All Loggers</option>
      </select>'''
        : '';

    final filterBlock = showLevelFilters
        ? '''
      <div class="log-level-filters">
        <button class="log-filter-btn active" data-level="trace" id="filter-trace">Trace <span class="log-level-count" id="count-trace">0</span></button>
        <button class="log-filter-btn active" data-level="debug" id="filter-debug">Debug <span class="log-level-count" id="count-debug">0</span></button>
        <button class="log-filter-btn active" data-level="info" id="filter-info">Info <span class="log-level-count" id="count-info">0</span></button>
        <button class="log-filter-btn active" data-level="warning" id="filter-warning">Warning <span class="log-level-count" id="count-warning">0</span></button>
        <button class="log-filter-btn active" data-level="error" id="filter-error">Error <span class="log-level-count" id="count-error">0</span></button>
      </div>'''
        : '';

    final extraActionsBlock = extraActions.isNotEmpty
        ? extraActions.map((final a) => '      ${a.render()}\n').join()
        : '';

    final themeToggleBlock = showThemeToggle
        ? '      <button type="button" class="log-action-btn" id="btn-theme-toggle" title="Toggle Light / Dark Theme">☀️ Light</button>\n'
        : '';

    final liveFollowBlock = showLiveFollow
        ? '      <button type="button" class="log-action-btn" id="btn-live-follow" title="Toggle Live Auto-Scroll">⚡ Live Follow [OFF]</button>\n'
        : '';

    final exportActionsBlock = showExportActions
        ? '''
      <button type="button" class="log-action-btn" id="btn-export-json" title="Export visible logs as JSON">Export JSON</button>
      <button type="button" class="log-action-btn" id="btn-export-csv" title="Export visible logs as CSV">Export CSV</button>
'''
        : '';

    final expandCollapseBlock = showExpandCollapse
        ? '''

      <button class="log-action-btn" id="btn-expand-all">Expand All</button>
      <button class="log-action-btn" id="btn-collapse-all">Collapse All</button>'''
        : '';

    final hasSecondaryRow =
        showExpandCollapse ||
        showExportActions ||
        showThemeToggle ||
        showLiveFollow ||
        extraActions.isNotEmpty;

    final secondaryRow = hasSecondaryRow
        ? '''
    <div class="log-controls-row secondary-controls">
$extraActionsBlock$themeToggleBlock$liveFollowBlock$exportActionsBlock$expandCollapseBlock
    </div>'''
        : '';

    return '''
  <div class="log-control-panel">
    <div class="log-controls-row">
$searchBlock
$loggerFilterBlock
$filterBlock
    </div>
$secondaryRow
  </div>
''';
  }

  /// Creates a copy of this control panel with the given fields replaced.
  DefaultHtmlControlPanel copyWith({
    final bool? showSearch,
    final bool? showLevelFilters,
    final bool? showExpandCollapse,
    final bool? showRegexToggle,
    final bool? showExportActions,
    final bool? showThemeToggle,
    final bool? showLiveFollow,
    final bool? showLoggerFilter,
    final String? searchPlaceholder,
    final List<HtmlActionButton>? extraActions,
  }) => DefaultHtmlControlPanel(
    showSearch: showSearch ?? this.showSearch,
    showLevelFilters: showLevelFilters ?? this.showLevelFilters,
    showExpandCollapse: showExpandCollapse ?? this.showExpandCollapse,
    showRegexToggle: showRegexToggle ?? this.showRegexToggle,
    showExportActions: showExportActions ?? this.showExportActions,
    showThemeToggle: showThemeToggle ?? this.showThemeToggle,
    showLiveFollow: showLiveFollow ?? this.showLiveFollow,
    showLoggerFilter: showLoggerFilter ?? this.showLoggerFilter,
    searchPlaceholder: searchPlaceholder ?? this.searchPlaceholder,
    extraActions: extraActions ?? this.extraActions,
  );

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is DefaultHtmlControlPanel &&
          runtimeType == other.runtimeType &&
          showSearch == other.showSearch &&
          showLevelFilters == other.showLevelFilters &&
          showExpandCollapse == other.showExpandCollapse &&
          showRegexToggle == other.showRegexToggle &&
          showExportActions == other.showExportActions &&
          showThemeToggle == other.showThemeToggle &&
          showLiveFollow == other.showLiveFollow &&
          showLoggerFilter == other.showLoggerFilter &&
          searchPlaceholder == other.searchPlaceholder &&
          _listEquals(extraActions, other.extraActions);

  @override
  int get hashCode => Object.hash(
    runtimeType,
    showSearch,
    showLevelFilters,
    showExpandCollapse,
    showRegexToggle,
    showExportActions,
    showThemeToggle,
    showLiveFollow,
    showLoggerFilter,
    searchPlaceholder,
    Object.hashAll(extraActions),
  );
}

/// A pluggable component that renders the document footer.
abstract interface class HtmlFooterComponent {
  /// Renders the HTML markup for the footer block.
  String render({required final LogTheme theme});
}

/// The default footer component displaying attribution.
@immutable
class DefaultHtmlFooter implements HtmlFooterComponent {
  /// Creates a [DefaultHtmlFooter].
  const DefaultHtmlFooter({
    this.attribution =
        'Generated by <a href="https://github.com/pccria/logd">Logd</a>',
    this.customContent,
  });

  /// The attribution HTML string.
  final String attribution;

  /// Optional custom raw HTML appended to the footer.
  final String? customContent;

  @override
  String render({required final LogTheme theme}) {
    final custom = customContent != null ? '\n  $customContent' : '';
    return '''
<footer class="log-page-footer">
  $attribution$custom
</footer>
''';
  }

  /// Creates a copy of this footer with the given fields replaced.
  DefaultHtmlFooter copyWith({
    final String? attribution,
    final String? customContent,
  }) => DefaultHtmlFooter(
    attribution: attribution ?? this.attribution,
    customContent: customContent ?? this.customContent,
  );

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is DefaultHtmlFooter &&
          runtimeType == other.runtimeType &&
          attribution == other.attribution &&
          customContent == other.customContent;

  @override
  int get hashCode => Object.hash(runtimeType, attribution, customContent);
}

/// Defines the modular layout, components, and embedding mode for HTML log
/// output.
///
/// Use [HtmlView] to customize the visual structure of logs generated by
/// [HtmlFileHandler] or [HtmlEncoder], or use [HtmlView.embedded] to produce
/// an embeddable HTML fragment suitable for inclusion in an existing web app
/// or dashboard.
@immutable
class HtmlView {
  /// Creates a standalone full-document [HtmlView].
  const HtmlView({
    this.title = 'Log Output',
    this.isStandalone = true,
    this.header = const DefaultHtmlHeader(),
    this.controlPanel = const DefaultHtmlControlPanel(),
    this.footer = const DefaultHtmlFooter(),
    this.stylesheet = const DefaultHtmlStylesheet(),
    this.injectScripts = true,
    this.includeExternalFonts = false,
  });

  /// Creates an embeddable [HtmlView] fragment without `<!DOCTYPE html>`,
  /// `<head>`, or `<body>` wrappers.
  ///
  /// Useful for embedding directly into an existing web dashboard, admin panel,
  /// or iframe.
  const HtmlView.embedded({
    this.title = '',
    this.header,
    this.controlPanel = const DefaultHtmlControlPanel(),
    this.footer,
    this.stylesheet = const DefaultHtmlStylesheet(),
    this.injectScripts = true,
    this.includeExternalFonts = false,
  }) : isStandalone = false;

  /// The title of the document or log session.
  final String title;

  /// Whether to render a full standalone HTML document with doctype and head,
  /// or an embeddable fragment container.
  final bool isStandalone;

  /// The header component rendered at the top of the container, or `null`
  /// to omit.
  final HtmlHeaderComponent? header;

  /// The interactive control panel component, or `null` to omit.
  final HtmlControlPanelComponent? controlPanel;

  /// The footer component rendered at the bottom, or `null` to omit.
  final HtmlFooterComponent? footer;

  /// The stylesheet provider controlling CSS and JS injection.
  final HtmlStylesheet stylesheet;

  /// Whether to inject client-side interactive JavaScript scripts.
  final bool injectScripts;

  /// Whether to include external web fonts (e.g. Google Fonts) via CDN links.
  ///
  /// Defaults to `false` to guarantee 100% self-contained, air-gap-resilient
  /// output without external network requests or CSP violations.
  final bool includeExternalFonts;

  /// Creates a copy of this view with the given fields replaced.
  HtmlView copyWith({
    final String? title,
    final bool? isStandalone,
    final HtmlHeaderComponent? header,
    final HtmlControlPanelComponent? controlPanel,
    final HtmlFooterComponent? footer,
    final HtmlStylesheet? stylesheet,
    final bool? injectScripts,
    final bool? includeExternalFonts,
  }) => HtmlView(
    title: title ?? this.title,
    isStandalone: isStandalone ?? this.isStandalone,
    header: header ?? this.header,
    controlPanel: controlPanel ?? this.controlPanel,
    footer: footer ?? this.footer,
    stylesheet: stylesheet ?? this.stylesheet,
    injectScripts: injectScripts ?? this.injectScripts,
    includeExternalFonts: includeExternalFonts ?? this.includeExternalFonts,
  );

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is HtmlView &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          isStandalone == other.isStandalone &&
          header == other.header &&
          controlPanel == other.controlPanel &&
          footer == other.footer &&
          injectScripts == other.injectScripts &&
          includeExternalFonts == other.includeExternalFonts;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    title,
    isStandalone,
    header,
    controlPanel,
    footer,
    injectScripts,
    includeExternalFonts,
  );
}

String _escapeHtml(final String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

bool _listEquals<T>(final List<T>? a, final List<T>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }
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
