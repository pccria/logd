import 'dart:io';

void main() async {
  final readmeFiles = Directory('packages')
      .listSync()
      .whereType<Directory>()
      .map((final d) => File('${d.path}/README.md'))
      .where((final f) => f.existsSync())
      .toList()
    ..sort((final a, final b) => a.path.compareTo(b.path));

  final scratchDir = Directory('.dart_tool/readme_scratch');
  final testDir = Directory('${scratchDir.path}/test');
  if (testDir.existsSync()) {
    testDir.deleteSync(recursive: true);
  }
  testDir.createSync(recursive: true);

  // Create pubspec.yaml for the scratch package
  File('${scratchDir.path}/pubspec.yaml').writeAsStringSync('''
name: readme_scratch
publish_to: none
environment:
  sdk: '>=3.6.0 <4.0.0'

dependencies:
  logd:
    path: ../../packages/logd
  logd_dio:
    path: ../../packages/logd_dio
  logd_html:
    path: ../../packages/logd_html
  logd_linters:
    path: ../../packages/logd_linters
  logd_markdown:
    path: ../../packages/logd_markdown
  logd_network:
    path: ../../packages/logd_network
  logd_sqlite:
    path: ../../packages/logd_sqlite
  logd_toon:
    path: ../../packages/logd_toon
  dio: ^5.7.0
  shelf: ^1.4.2
  test: ^1.25.0

dependency_overrides:
  logd:
    path: ../../packages/logd
  logd_dio:
    path: ../../packages/logd_dio
  logd_html:
    path: ../../packages/logd_html
  logd_linters:
    path: ../../packages/logd_linters
  logd_markdown:
    path: ../../packages/logd_markdown
  logd_network:
    path: ../../packages/logd_network
  logd_sqlite:
    path: ../../packages/logd_sqlite
  logd_toon:
    path: ../../packages/logd_toon
''');

  File('${scratchDir.path}/analysis_options.yaml').writeAsStringSync('''
analyzer:
  errors:
    todo: ignore
''');

  // Resolve dependencies in the scratch package
  final pubGet = await Process.run(
    'dart',
    ['pub', 'get'],
    workingDirectory: scratchDir.path,
  );
  if (pubGet.exitCode != 0) {
    stderr
      ..writeln('Failed to resolve scratch package dependencies:')
      ..writeln(pubGet.stderr);
    exit(1);
  }

  const defaultImports = [
    "import 'dart:async';",
    "import 'dart:io';",
    "import 'dart:typed_data';",
    "import 'package:logd/logd.dart';",
    "import 'package:logd_dio/logd_dio.dart';",
    "import 'package:logd_html/logd_html.dart';",
    "import 'package:logd_markdown/logd_markdown.dart';",
    "import 'package:logd_network/logd_network.dart';",
    "import 'package:logd_sqlite/logd_sqlite.dart';",
    "import 'package:logd_toon/logd_toon.dart';",
  ];

  const preludeImport = "import '../../../tool/readme_prelude.dart';";

  final snippetMap = <String, _SnippetMetadata>{};
  var snippetIndex = 0;
  var skippedCount = 0;

  for (final readme in readmeFiles) {
    final lines = readme.readAsLinesSync();
    var inBlock = false;
    var blockSkipped = false;
    var startLine = 0;
    final blockLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (!inBlock && trimmed.startsWith('```dart')) {
        inBlock = true;
        startLine = i + 1; // 1-indexed line of ```dart
        blockLines.clear();

        // Check if previous non-empty line was a skip marker
        blockSkipped = false;
        for (var j = i - 1; j >= 0; j--) {
          final prev = lines[j].trim();
          if (prev.isEmpty) {
            continue;
          }
          if (prev == '<!-- readme-check: skip -->') {
            blockSkipped = true;
          }
          break;
        }

        if (blockSkipped) {
          skippedCount++;
        }
      } else if (inBlock && trimmed == '```') {
        inBlock = false;
        if (blockSkipped) {
          continue;
        }
        snippetIndex++;

        final code = blockLines.join('\n');
        final hasImports = blockLines.any(
          (final l) => l.trim().startsWith('import '),
        );
        final hasMain = code.contains('void main(') || code.contains('main()');
        final hasClass = RegExp(
          r'\b(class|mixin|extension|enum|typedef)\b',
        ).hasMatch(code);
        final hasFunc = RegExp(
          r'^\s*(void|Future<[^>]+>|[A-Z]\w+)\s+\w+\s*\(',
          multiLine: true,
        ).hasMatch(code);

        final importLines = <String>[];
        final bodyLines = <String>[];
        for (final bl in blockLines) {
          if (bl.trim().startsWith('import ')) {
            importLines.add(bl);
          } else {
            bodyLines.append(bl);
          }
        }

        final fileLines = <String>['// SOURCE: ${readme.path}:$startLine'];

        int headerCount;
        final bool isWrapped;

        if (hasImports) {
          if (hasMain || hasClass || hasFunc) {
            fileLines
              ..addAll(importLines)
              ..add(preludeImport)
              ..addAll(bodyLines);
            headerCount = 1;
            isWrapped = false;
          } else {
            fileLines
              ..addAll(importLines)
              ..add(preludeImport)
              ..add('void main() async {');
            headerCount = 1 + importLines.length + 2;
            for (final bl in bodyLines) {
              final trimmedBl = bl.trim();
              if (trimmedBl.isNotEmpty &&
                  !trimmedBl.startsWith('//') &&
                  trimmedBl.endsWith(')') &&
                  !trimmedBl.endsWith(');')) {
                fileLines.add('$bl;');
              } else {
                fileLines.add(bl);
              }
            }
            fileLines.add('}');
            isWrapped = true;
          }
        } else {
          if (hasMain || hasClass || hasFunc) {
            fileLines
              ..addAll(defaultImports)
              ..add(preludeImport);
            headerCount = 1 + defaultImports.length + 1;
            fileLines.addAll(blockLines);
            isWrapped = false;
          } else {
            fileLines
              ..addAll(defaultImports)
              ..add(preludeImport)
              ..add('void main() async {');
            headerCount = 1 + defaultImports.length + 2;
            for (final bl in blockLines) {
              final trimmedBl = bl.trim();
              if (trimmedBl.isNotEmpty &&
                  !trimmedBl.startsWith('//') &&
                  trimmedBl.endsWith(')') &&
                  !trimmedBl.endsWith(');')) {
                fileLines.add('$bl;');
              } else {
                fileLines.add(bl);
              }
            }
            fileLines.add('}');
            isWrapped = true;
          }
        }

        final fileName =
            'snippet_${snippetIndex.toString().padLeft(3, '0')}.dart';
        File('${testDir.path}/$fileName')
            .writeAsStringSync('${fileLines.join('\n')}\n');

        snippetMap[fileName] = _SnippetMetadata(
          file: readme.path,
          startLine: startLine,
          headerCount: headerCount,
          isWrapped: isWrapped,
          hasImports: hasImports,
          importCount: importLines.length,
        );
      } else if (inBlock) {
        blockLines.add(line);
      }
    }
  }

  // Run analyzer over all snippets in the scratch package
  final analyze = await Process.run(
    'dart',
    ['analyze', '--format=machine'],
    workingDirectory: scratchDir.path,
  );

  final failures = <_SnippetFailure>[];
  final stdoutStr = analyze.stdout as String;

  for (final line in stdoutStr.split('\n')) {
    if (line.isEmpty) {
      continue;
    }
    final parts = line.split('|');
    if (parts.length >= 8 && parts[0] == 'ERROR') {
      final snippetPath = parts[3];
      final fileName = snippetPath.split(Platform.pathSeparator).last;
      final lineInFile = int.tryParse(parts[4]) ?? 0;
      final message = parts[7];

      final meta = snippetMap[fileName];
      if (meta != null) {
        final int originalLine;
        if (meta.hasImports && !meta.isWrapped) {
          originalLine = meta.startLine + (lineInFile - 1);
        } else if (meta.hasImports && meta.isWrapped) {
          if (lineInFile <= 1 + meta.importCount) {
            originalLine = meta.startLine + (lineInFile - 1);
          } else {
            originalLine = meta.startLine +
                (lineInFile - meta.headerCount + meta.importCount);
          }
        } else {
          originalLine = meta.startLine + (lineInFile - meta.headerCount);
        }

        failures.add(
          _SnippetFailure(
            file: meta.file,
            line: originalLine,
            message: message,
          ),
        );
      }
    }
  }

  // Print results
  print('Checked ${readmeFiles.length} README files, '
      '$snippetIndex code blocks ($skippedCount skipped).');

  if (failures.isEmpty) {
    print('All README code examples compiled successfully.');
    exit(0);
  } else {
    print('Found ${failures.length} compilation error(s):');
    for (final f in failures) {
      print('${f.file}:${f.line}: ${f.message}');
    }
    exit(1);
  }
}

extension on List<String> {
  void append(final String item) => add(item);
}

class _SnippetMetadata {
  const _SnippetMetadata({
    required this.file,
    required this.startLine,
    required this.headerCount,
    required this.isWrapped,
    required this.hasImports,
    required this.importCount,
  });

  final String file;
  final int startLine;
  final int headerCount;
  final bool isWrapped;
  final bool hasImports;
  final int importCount;
}

class _SnippetFailure {
  const _SnippetFailure({
    required this.file,
    required this.line,
    required this.message,
  });

  final String file;
  final int line;
  final String message;
}
