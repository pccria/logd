import 'dart:io' as io;

/// Reads the `GITHUB_STEP_SUMMARY` environment variable if present and non-empty.
String? readGitHubStepSummaryEnv() {
  final value = io.Platform.environment['GITHUB_STEP_SUMMARY'];
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

/// Appends [content] to the step summary file at [path], creating parent
/// directories if needed.
Future<void> appendStepSummaryFile(
  final String path,
  final String content,
) async {
  final file = io.File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content, mode: io.FileMode.append, flush: true);
}
