import 'package:meta/meta.dart';
import '../../../logd.dart';

export 'log_brightness.dart';

/// Semantic tags describing the content of a [LogNode].
abstract class LogTag {
  /// No tags.
  static const int none = 0;

  /// General metadata like timestamp, level, or logger name.
  static const int header = 1 << 0;

  /// Information about where the log was emitted (file, line, function).
  static const int origin = 1 << 1;

  /// The primary log message body.
  static const int message = 1 << 2;

  /// Error information (exception message).
  static const int error = 1 << 3;

  /// Individual frame in a stack trace.
  static const int stackFrame = 1 << 4;

  /// Content related to the log level (e.g. the `[INFO]` text).
  static const int level = 1 << 5;

  /// Structural lines like box borders or dividers.
  static const int border = 1 << 6;

  /// Content related to the timestamp.
  static const int timestamp = 1 << 7;

  /// Content related to the logger name.
  static const int loggerName = 1 << 8;

  /// Tree-like hierarchy prefix.
  static const int hierarchy = 1 << 9;

  /// Content Prefix
  static const int prefix = 1 << 10;

  /// Content Suffix
  static const int suffix = 1 << 11;

  /// Semantic key (e.g. JSON key, TOON field name).
  static const int key = 1 << 12;

  /// Generic data value.
  static const int value = 1 << 13;

  /// Structural punctuation (e.g. braces, commas, delimiters).
  static const int punctuation = 1 << 14;

  /// Optimization hint: Content should not be wrapped by the layout engine.
  /// Used for machine-readable formats (JSON, TOON) where structure is
  /// critical.
  static const int noWrap = 1 << 15;

  /// Semantic hint: Content is suitable for a collapsible/expandable section
  /// (e.g., \<details\> in HTML/Markdown).
  static const int collapsible = 1 << 16;

  /// Semantic hint: Content is a preview string for a collapsed section.
  /// (Should be hidden when the section is open).
  static const int preview = 1 << 17;

  /// Semantic hint: Content contains intentional raw formatting or escape
  /// codes and should not be sanitized.
  static const int raw = 1 << 18;
}

/// Visual style suggestion for a log segment.
@immutable
class LogStyle {
  /// Creates a [LogStyle].
  const LogStyle({
    this.color,
    this.backgroundColor,
    this.bold,
    this.dim,
    this.italic,
    this.inverse,
    this.underline,
  });

  /// The suggested foreground color.
  final LogColor? color;

  /// The suggested background color.
  final LogColor? backgroundColor;

  /// Whether the text should be bold.
  final bool? bold;

  /// Whether the text should be dimmed (faint).
  final bool? dim;

  /// Whether the text should be italic.
  final bool? italic;

  /// Whether the text/background color should be inverted.
  final bool? inverse;

  /// Whether the text should be underlined.
  final bool? underline;

  /// Returns a packed 32-bit integer representing this style.
  int get bitmask {
    int mask = 0;
    mask |= (color?.index ?? 15) & 0xF;
    mask |= ((backgroundColor?.index ?? 15) & 0xF) << 4;
    if (bold ?? false) {
      mask |= 1 << 8;
    }
    if (dim ?? false) {
      mask |= 1 << 9;
    }
    if (italic ?? false) {
      mask |= 1 << 10;
    }
    if (inverse ?? false) {
      mask |= 1 << 11;
    }
    if (underline ?? false) {
      mask |= 1 << 12;
    }
    return mask;
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is LogStyle &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          backgroundColor == other.backgroundColor &&
          bold == other.bold &&
          dim == other.dim &&
          italic == other.italic &&
          inverse == other.inverse &&
          underline == other.underline;

  @override
  int get hashCode => Object.hash(
        color,
        backgroundColor,
        bold,
        dim,
        italic,
        inverse,
        underline,
      );
}

/// Abstract color definitions for log rendering.
enum LogColor {
  black,
  red,
  green,
  yellow,
  blue,
  magenta,
  cyan,
  white,
  brightBlack,
  brightRed,
  brightGreen,
  brightYellow,
  brightBlue,
  brightMagenta,
  brightCyan,
  brightWhite;
}

/// Defines the semantic level color palette for a logging session.
///
/// [LogColorScheme] maps each severity level ([LogLevel.trace] through
/// [LogLevel.error]) to a primary [LogColor]. Visual styles and tag overrides
/// (such as bolding or dimmed timestamps) are managed separately by [LogTheme].
@immutable
class LogColorScheme {
  /// Creates a [LogColorScheme].
  const LogColorScheme({
    required this.trace,
    required this.debug,
    required this.info,
    required this.warning,
    required this.error,
  });

  /// Base color for trace log entries.
  final LogColor trace;

  /// Base color for debug log entries.
  final LogColor debug;

  /// Base color for info log entries.
  final LogColor info;

  /// Base color for warning log entries.
  final LogColor warning;

  /// Base color for error log entries.
  final LogColor error;

  /// Resolves the base color for a given [LogLevel].
  LogColor colorForLevel(final LogLevel level) => switch (level) {
        LogLevel.trace => trace,
        LogLevel.debug => debug,
        LogLevel.info => info,
        LogLevel.warning => warning,
        LogLevel.error => error,
      };

  /// Standard default color scheme.
  static const defaultScheme = LogColorScheme(
    trace: LogColor.green,
    debug: LogColor.white,
    info: LogColor.blue,
    warning: LogColor.yellow,
    error: LogColor.red,
  );

  /// Dark terminal color scheme.
  static const darkScheme = LogColorScheme(
    trace: LogColor.green,
    debug: LogColor.white,
    info: LogColor.blue,
    warning: LogColor.yellow,
    error: LogColor.red,
  );

  /// Soft pastel color scheme.
  static const pastelScheme = LogColorScheme(
    trace: LogColor.green,
    debug: LogColor.cyan,
    info: LogColor.brightCyan,
    warning: LogColor.brightYellow,
    error: LogColor.brightRed,
  );

  /// Light terminal color scheme.
  static const lightScheme = LogColorScheme(
    trace: LogColor.green,
    debug: LogColor.black,
    info: LogColor.blue,
    warning: LogColor.brightYellow,
    error: LogColor.red,
  );

  /// High contrast color scheme for legibility.
  static const highContrastScheme = LogColorScheme(
    trace: LogColor.brightGreen,
    debug: LogColor.brightWhite,
    info: LogColor.brightCyan,
    warning: LogColor.brightYellow,
    error: LogColor.brightRed,
  );

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is LogColorScheme &&
          trace == other.trace &&
          debug == other.debug &&
          info == other.info &&
          warning == other.warning &&
          error == other.error;

  @override
  int get hashCode => Object.hash(trace, debug, info, warning, error);
}

/// Defines visual styling rules for log elements across a pipeline.
///
/// [LogTheme] pairs a semantic level palette ([colorScheme]) with per-element
/// [LogStyle] rules (such as bold headers, dimmed timestamps, or custom
/// border colors).
@immutable
class LogTheme {
  /// Creates a [LogTheme].
  const LogTheme({
    this.colorScheme = LogColorScheme.darkScheme,
    this.brightness = LogBrightness.dark,
    this.timestampStyle,
    this.loggerNameStyle,
    this.levelStyle,
    this.messageStyle,
    this.borderStyle,
    this.stackFrameStyle,
    this.exceptionStyle,
    this.hierarchyStyle,
  });

  /// Creates a standard dark terminal theme.
  @Deprecated('Use DarkTheme() instead')
  const factory LogTheme.dark({
    final LogStyle? timestampStyle,
    final LogStyle? loggerNameStyle,
    final LogStyle? levelStyle,
    final LogStyle? messageStyle,
    final LogStyle? borderStyle,
    final LogStyle? stackFrameStyle,
    final LogStyle? exceptionStyle,
    final LogStyle? hierarchyStyle,
  }) = _LegacyDarkTheme;

  /// Creates a standard light terminal theme.
  @Deprecated('Use LightTheme() instead')
  const factory LogTheme.light({
    final LogStyle? timestampStyle,
    final LogStyle? loggerNameStyle,
    final LogStyle? levelStyle,
    final LogStyle? messageStyle,
    final LogStyle? borderStyle,
    final LogStyle? stackFrameStyle,
    final LogStyle? exceptionStyle,
    final LogStyle? hierarchyStyle,
  }) = _LegacyLightTheme;

  /// The level color palette.
  final LogColorScheme colorScheme;

  /// Overall background brightness hint (e.g., for HTML stylesheet generation).
  final LogBrightness brightness;

  /// Style override for timestamp segments (`LogTag.timestamp`).
  final LogStyle? timestampStyle;

  /// Style override for logger name segments (`LogTag.loggerName`).
  final LogStyle? loggerNameStyle;

  /// Style override for level text segments (`LogTag.level`).
  final LogStyle? levelStyle;

  /// Style override for log message content (`LogTag.message`).
  final LogStyle? messageStyle;

  /// Style override for structural borders (`LogTag.border`).
  final LogStyle? borderStyle;

  /// Style override for stack trace frames (`LogTag.stackFrame`).
  final LogStyle? stackFrameStyle;

  /// Style override for exception details (`LogTag.error`).
  final LogStyle? exceptionStyle;

  /// Style override for hierarchy lines (`LogTag.hierarchy`).
  final LogStyle? hierarchyStyle;

  /// Resolves the base color for a given log level.
  LogColor colorForLevel(final LogLevel level) =>
      colorScheme.colorForLevel(level);

  /// Resolves the style for a given segment based on level and tags.
  LogStyle getStyle(final LogLevel level, final int tags) {
    final baseColor = (tags & LogTag.hierarchy) != 0
        ? null
        : colorScheme.colorForLevel(level);

    var style = LogStyle(color: baseColor);

    if ((tags & LogTag.level) != 0) {
      style = _merge(style, const LogStyle(bold: true));
    } else if ((tags & LogTag.timestamp) != 0 ||
        (tags & LogTag.loggerName) != 0) {
      style = _merge(style, const LogStyle(dim: true));
    } else if ((tags & LogTag.header) != 0) {
      style = _merge(style, const LogStyle(bold: true));
    }

    if ((tags & LogTag.level) != 0) {
      style = _merge(style, levelStyle);
    } else if ((tags & LogTag.timestamp) != 0) {
      style = _merge(style, timestampStyle);
    } else if ((tags & LogTag.loggerName) != 0) {
      style = _merge(style, loggerNameStyle);
    } else if ((tags & LogTag.message) != 0) {
      style = _merge(style, messageStyle);
    } else if ((tags & LogTag.border) != 0) {
      style = _merge(style, borderStyle);
    } else if ((tags & LogTag.stackFrame) != 0) {
      style = _merge(style, stackFrameStyle);
    } else if ((tags & LogTag.error) != 0) {
      style = _merge(style, exceptionStyle);
    } else if ((tags & LogTag.hierarchy) != 0) {
      style = _merge(style, hierarchyStyle);
    }

    return style;
  }

  LogStyle _merge(final LogStyle base, final LogStyle? override) {
    if (override == null) {
      return base;
    }
    return LogStyle(
      color: override.color ?? base.color,
      backgroundColor: override.backgroundColor ?? base.backgroundColor,
      bold: override.bold ?? base.bold,
      dim: override.dim ?? base.dim,
      italic: override.italic ?? base.italic,
      inverse: override.inverse ?? base.inverse,
      underline: override.underline ?? base.underline,
    );
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is LogTheme &&
          runtimeType == other.runtimeType &&
          colorScheme == other.colorScheme &&
          brightness == other.brightness &&
          timestampStyle == other.timestampStyle &&
          loggerNameStyle == other.loggerNameStyle &&
          levelStyle == other.levelStyle &&
          messageStyle == other.messageStyle &&
          borderStyle == other.borderStyle &&
          stackFrameStyle == other.stackFrameStyle &&
          exceptionStyle == other.exceptionStyle &&
          hierarchyStyle == other.hierarchyStyle;

  @override
  int get hashCode => Object.hashAll([
        colorScheme,
        brightness,
        timestampStyle,
        loggerNameStyle,
        levelStyle,
        messageStyle,
        borderStyle,
        stackFrameStyle,
        exceptionStyle,
        hierarchyStyle,
      ]);
}

/// A standard dark terminal theme.
@immutable
final class DarkTheme extends LogTheme {
  /// Creates a [DarkTheme].
  const DarkTheme({
    super.colorScheme = LogColorScheme.darkScheme,
    super.levelStyle = const LogStyle(bold: true),
    super.timestampStyle = const LogStyle(dim: true),
    super.loggerNameStyle = const LogStyle(dim: true),
    super.messageStyle,
    super.borderStyle,
    super.stackFrameStyle,
    super.exceptionStyle,
    super.hierarchyStyle,
  }) : super(brightness: LogBrightness.dark);
}

/// A standard light terminal theme.
@immutable
final class LightTheme extends LogTheme {
  /// Creates a [LightTheme].
  const LightTheme({
    super.colorScheme = LogColorScheme.lightScheme,
    super.levelStyle = const LogStyle(bold: true),
    super.timestampStyle = const LogStyle(dim: true),
    super.loggerNameStyle = const LogStyle(dim: true),
    super.messageStyle,
    super.borderStyle,
    super.stackFrameStyle,
    super.exceptionStyle,
    super.hierarchyStyle,
  }) : super(brightness: LogBrightness.light);
}

/// A pastel color theme.
@immutable
final class PastelTheme extends LogTheme {
  /// Creates a [PastelTheme].
  const PastelTheme({
    super.colorScheme = LogColorScheme.pastelScheme,
    super.levelStyle = const LogStyle(bold: true),
    super.timestampStyle = const LogStyle(dim: true),
    super.loggerNameStyle = const LogStyle(dim: true),
    super.messageStyle,
    super.borderStyle,
    super.stackFrameStyle,
    super.exceptionStyle,
    super.hierarchyStyle,
  }) : super(brightness: LogBrightness.dark);
}

/// A high contrast theme for maximum legibility.
@immutable
final class HighContrastTheme extends LogTheme {
  /// Creates a [HighContrastTheme].
  const HighContrastTheme({
    super.colorScheme = LogColorScheme.highContrastScheme,
    super.levelStyle = const LogStyle(bold: true, inverse: true),
    super.timestampStyle = const LogStyle(bold: true),
    super.loggerNameStyle = const LogStyle(bold: true),
    super.messageStyle,
    super.borderStyle = const LogStyle(bold: true),
    super.stackFrameStyle,
    super.exceptionStyle = const LogStyle(bold: true),
    super.hierarchyStyle,
  }) : super(brightness: LogBrightness.dark);
}

final class _LegacyDarkTheme extends DarkTheme {
  const _LegacyDarkTheme({
    super.timestampStyle,
    super.loggerNameStyle,
    super.levelStyle,
    super.messageStyle,
    super.borderStyle,
    super.stackFrameStyle,
    super.exceptionStyle,
    super.hierarchyStyle,
  });
}

final class _LegacyLightTheme extends LightTheme {
  const _LegacyLightTheme({
    super.timestampStyle,
    super.loggerNameStyle,
    super.levelStyle,
    super.messageStyle,
    super.borderStyle,
    super.stackFrameStyle,
    super.exceptionStyle,
    super.hierarchyStyle,
  });
}
