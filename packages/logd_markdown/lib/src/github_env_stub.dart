/// Reads the `GITHUB_STEP_SUMMARY` path on non-IO platforms (returns `null`).
String? readGitHubStepSummaryEnv() => null;

/// Appends [content] to [path] on non-IO platforms (no-op).
Future<void> appendStepSummaryFile(
  final String path,
  final String content,
) async {}
