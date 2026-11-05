import 'package:characters/characters.dart';
import 'package:meta/meta.dart';

import 'path_helper_stub.dart' if (dart.library.io) 'path_helper_io.dart'
    as path_helper;

/// Internal utility for list equality.
@internal
bool listEquals<T>(final List<T>? a, final List<T>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

/// Internal utility for map equality.
@internal
bool mapEquals<K, V>(final Map<K, V>? a, final Map<K, V>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (final K key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) {
      return false;
    }
  }
  return true;
}

/// Internal utility for set equality.
bool setEquals<T>(final Set<T>? a, final Set<T>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (final T value in a) {
    if (!b.contains(value)) {
      return false;
    }
  }
  return true;
}

/// Extension for ANSI-aware string manipulations.
@internal
extension AnsiStringExtension on String {
  static final _ansiRegex = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');
  static const _ansiReset = '\x1B[0m';

  /// Estimates terminal width of a string.
  ///
  /// ANSI escape sequences are stripped before calculation.
  /// TAB (\t) is counted as the distance to the next tab stop (default 8).
  /// Wide characters (CJK, Emojis) are counted as 2 cells, others as 1.
  /// If the string contains newlines, returns the width of the longest line.
  int get visibleLength {
    final lines = stripAnsi.split(RegExp(r'\r?\n'));
    int maxWidth = 0;
    for (final line in lines) {
      int width = 0;
      for (final char in line.characters) {
        if (char == '\t') {
          width += 8 - (width % 8);
        } else {
          width += isWide(char) ? 2 : 1;
        }
      }
      if (width > maxWidth) {
        maxWidth = width;
      }
    }
    return maxWidth;
  }

  /// Pads this string on the right to [width] visible characters,
  /// preserving leading ANSI sequences and ensuring padding is styled.
  String padRightVisiblePreserveAnsi(
    final int width, [
    final String padding = ' ',
  ]) {
    final safeWidth = width.clamp(1, 10000);
    final visible = visibleLength;
    if (visible >= safeWidth) {
      return this;
    }
    final ansiRegex = RegExp(r'^(?:\x1B\[[0-?]*[ -/]*[@-~])+');
    final match = ansiRegex.firstMatch(this);
    final ansiPrefix = match?.group(0) ?? '';
    final visibleText = stripAnsi;
    final paddedText = visibleText.padRight(safeWidth, padding);
    return '$ansiPrefix$paddedText$_ansiReset';
  }

  /// Removes all ANSI escape sequences from the string.
  String get stripAnsi => replaceAll(_ansiRegex, '');

  /// Wraps this string into multiple lines based on visible terminal width.
  Iterable<String> wrapVisible(final int width) sync* {
    final safeWidth = width.clamp(1, 10000);
    final lines = stripAnsi.split(RegExp(r'\r?\n'));

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        yield '';
        continue;
      }
      yield* _wrapSingleLine(line, safeWidth);
    }
  }

  Iterable<String> _wrapSingleLine(final String text, final int width) sync* {
    final chars = text.characters.toList();
    var current = 0;

    while (current < chars.length) {
      int accumulatedWidth = 0;
      int breakIndex = current;
      int? lastBreakableIndex;

      for (int i = current; i < chars.length; i++) {
        final char = chars[i];
        final int charWidth;
        if (char == '\t') {
          charWidth = 8 - (accumulatedWidth % 8);
        } else {
          charWidth = isWide(char) ? 2 : 1;
        }

        if (accumulatedWidth + charWidth > width) {
          break;
        }

        accumulatedWidth += charWidth;
        breakIndex = i + 1;
        if (char == ' ' || char == '\t') {
          lastBreakableIndex = i;
        }
      }

      if (accumulatedWidth == 0) {
        final char = chars[current];
        yield char;
        current++;
      } else {
        if (lastBreakableIndex != null && breakIndex < chars.length) {
          breakIndex = lastBreakableIndex + 1;
        }

        final chunk = chars.sublist(current, breakIndex).join();
        yield _trimSpacesRight(chunk);
        current = breakIndex;
      }

      while (current < chars.length && chars[current] == ' ') {
        current++;
      }
    }
  }

  String _trimSpacesRight(final String s) {
    var end = s.length;
    while (end > 0 && s[end - 1] == ' ') {
      end--;
    }
    return s.substring(0, end);
  }

  /// Wraps this string preserving ANSI escape codes across line breaks.
  Iterable<String> wrapVisiblePreserveAnsi(final int width) sync* {
    final safeWidth = width.clamp(1, 10000);
    final lines = split(RegExp(r'\r?\n'));

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final ansiRegex = RegExp(r'^(?:\x1B\[[0-?]*[ -/]*[@-~])+');
      final match = ansiRegex.firstMatch(line);
      final ansiPrefix = match?.group(0) ?? '';
      final visibleText = line.stripAnsi;
      if (visibleText.isEmpty) {
        if (ansiPrefix.isEmpty) {
          yield '';
        } else {
          yield '$ansiPrefix$_ansiReset';
        }
        continue;
      }

      final wrappedLines = _wrapSingleLine(visibleText, safeWidth).toList();
      for (var j = 0; j < wrappedLines.length; j++) {
        if (wrappedLines[j].isEmpty) {
          continue;
        }
        if (ansiPrefix.isEmpty) {
          yield wrappedLines[j];
        } else {
          yield '$ansiPrefix${wrappedLines[j]}$_ansiReset';
        }
      }
    }
  }
}

/// Whether the character is likely to take 2 terminal cells (Wide/Emoji).
@internal
bool isWide(final String char) {
  if (char.length > 1) {
    return true;
  }
  final code = char.codeUnitAt(0);
  return (code >= 0x1100 &&
          (code <= 0x115f ||
              code == 0x2329 ||
              code == 0x232a ||
              (code >= 0x2e80 && code <= 0xa4cf && code != 0x303f) ||
              (code >= 0xac00 && code <= 0xd7a3) ||
              (code >= 0xf900 && code <= 0xfaff) ||
              (code >= 0xfe10 && code <= 0xfe19) ||
              (code >= 0xfe30 && code <= 0xfe6f) ||
              (code >= 0xff00 && code <= 0xff60) ||
              (code >= 0xffe0 && code <= 0xffe6) ||
              (code >= 0x20000 && code <= 0x2fffd) ||
              (code >= 0x30000 && code <= 0x3fffd))) ||
      false;
}

/// Estimates terminal width of a string.
@internal
int getVisibleLength(final String text) => text.visibleLength;

final Map<String, int> _visibleLengthCache = {};

/// Estimates terminal width of a static string, caching the result to avoid
/// re-parsing overhead.
@internal
int getCachedVisibleLength(final String text) {
  if (_visibleLengthCache.length > 1000) {
    _visibleLengthCache.clear();
  }
  return _visibleLengthCache[text] ??= text.visibleLength;
}

/// Truncates a string to a specific visible length.
@internal
String truncateVisible(final String text, final int maxLength) {
  if (text.visibleLength <= maxLength) {
    return text;
  }
  final chars = text.characters;
  var result = '';
  var resultWidth = 0;
  for (final char in chars) {
    final charWidth = isWide(char) ? 2 : 1;
    if (resultWidth + charWidth > maxLength) {
      break;
    }
    result += char;
    resultWidth += charWidth;
  }
  return result;
}

/// Wraps a collection of text chunks into multiple lines, where each chunk
/// has associated style data.
@internal
Iterable<List<(String, T)>> wrapWithData<T>(
  final Iterable<(String, T)> parts,
  final int width, {
  final int? subsequentWidth,
}) sync* {
  if (width <= 0) {
    yield parts.toList();
    return;
  }

  final subWidth = (subsequentWidth ?? width).clamp(1, 10000);
  var currentLimit = width;
  var currentLine = <(String, T)>[];
  var currentX = 0;

  for (final part in parts) {
    final rawText = part.$1;
    final data = part.$2;

    final textSegments = rawText.split(RegExp(r'\r?\n'));

    for (int i = 0; i < textSegments.length; i++) {
      var text = textSegments[i];

      if (i > 0) {
        yield currentLine;
        currentLine = [];
        currentX = 0;
        currentLimit = subWidth;
      }

      if (text.isEmpty && textSegments.length > 1) {
        continue;
      }

      var iterations = 0;
      while (text.isNotEmpty) {
        if (iterations++ > 5000) {
          yield [...currentLine, (text, data)];
          currentLine = [];
          currentX = 0;
          currentLimit = subWidth;
          text = '';
          break;
        }
        final available = currentLimit - currentX;

        final textWidth = text.visibleLength;
        if (textWidth <= available) {
          // Fast-path: segment fits entirely, preserve exact text
          // (including spaces)
          currentLine.add((text, data));
          currentX += textWidth;
          text = '';
          continue;
        }

        final wrappingResult = text.wrapVisible(available).toList();

        if (wrappingResult.isEmpty || wrappingResult[0].isEmpty) {
          final forceChar = text.characters.first;
          currentLine.add((forceChar, data));
          currentX += isWide(forceChar) ? 2 : 1;
          text = text.substring(forceChar.length);

          if (currentX >= currentLimit) {
            yield currentLine;
            currentLine = [];
            currentX = 0;
            currentLimit = subWidth;
            while (text.startsWith(' ')) {
              text = text.substring(1);
            }
          }
          continue;
        }

        final chunk = wrappingResult[0];
        currentLine.add((chunk, data));
        currentX += chunk.visibleLength;

        if (chunk.length < text.length) {
          yield currentLine;
          currentLine = [];
          currentX = 0;
          currentLimit = subWidth;
          text = text.substring(chunk.length);
          if (text.startsWith(' ')) {
            text = text.substring(1);
          }
        } else {
          text = '';
        }
      }
    }
  }

  if (currentLine.isNotEmpty) {
    yield currentLine;
  }
}

/// Resolves absolute file:/// URIs in a string to workspace-relative paths.
@internal
String resolveFileUris(final String input) {
  if (!input.contains('file:///')) {
    return input;
  }
  final regex = RegExp(r'file:\/\/\/[^\s\)]+');
  return input.replaceAllMapped(regex, (final match) {
    final absoluteUriStr = match.group(0)!;
    try {
      final uri = Uri.parse(absoluteUriStr);
      final filePath = uri.toFilePath();
      final currentDir = path_helper.getCurrentDirectory();
      if (filePath.startsWith(currentDir)) {
        var rel = filePath.substring(currentDir.length);
        if (rel.startsWith(path_helper.getPathSeparator())) {
          rel = rel.substring(1);
        }
        return rel;
      }
      const projectDir = 'logd';
      if (filePath.contains(projectDir)) {
        final index = filePath.indexOf(projectDir);
        return filePath.substring(index + projectDir.length + 1);
      }
    } catch (_) {}
    return absoluteUriStr;
  });
}

final _sgrRegex = RegExp(r'^\x1B\[[0-9;]*m');

/// Neutralizes destructive control characters and terminal escape codes
/// in untrusted text to prevent log injection and terminal hijacking.
@internal
String sanitizeControlCharacters(
  final String input, {
  final bool isRaw = false,
}) {
  if (isRaw || input.isEmpty) {
    return input;
  }

  // Fast-path: check if any character requires neutralization
  bool hasControls = false;
  for (var i = 0; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    if ((code < 0x20 && code != 0x09 && code != 0x0A) ||
        code == 0x7F ||
        (code >= 0x80 && code <= 0x9F) ||
        code == 0x2028 ||
        code == 0x2029 ||
        code == 0x200E ||
        code == 0x200F ||
        (code >= 0x202A && code <= 0x202E) ||
        (code >= 0x2066 && code <= 0x2069)) {
      hasControls = true;
      break;
    }
  }
  if (!hasControls) {
    return input;
  }

  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    if (code == 0x1B) {
      final match = _sgrRegex.firstMatch(input.substring(i));
      if (match != null) {
        // Safe ANSI SGR styling/color code
        final sgr = match.group(0)!;
        buffer.write(sgr);
        i += sgr.length - 1;
      } else {
        // Neutralize dangerous escape sequence starter to visible notation
        buffer.write('^[');
      }
    } else if (code == 0x0D) {
      // Carriage return: normalize to newline to prevent line overwrite forging
      if (i + 1 < input.length && input.codeUnitAt(i + 1) == 0x0A) {
        continue;
      }
      buffer.write('\n');
    } else if (code == 0x85 || code == 0x2028 || code == 0x2029) {
      // Normalize C1 Next Line (NEL) and Unicode line/paragraph separators to newline
      buffer.write('\n');
    } else if (code == 0x09 || code == 0x0A) {
      // Preserve tab and newline
      buffer.writeCharCode(code);
    } else if (code < 0x20 ||
        code == 0x7F ||
        (code >= 0x80 && code <= 0x9F) ||
        code == 0x200E ||
        code == 0x200F ||
        (code >= 0x202A && code <= 0x202E) ||
        (code >= 0x2066 && code <= 0x2069)) {
      // Strip other destructive C0/C1 control codes and Unicode bidi overrides
      continue;
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}
