/// Formatting dialects supported by `MarkdownEncoder` and Markdown formatters.
enum MarkdownDialect {
  /// GitHub-Flavored Markdown (GFM).
  ///
  /// Uses GitHub alert callouts (`> [!ERROR]`, `> [!NOTE]`), HTML
  /// `<details>/<summary>` collapsible blocks, and GFM tables.
  gfm,

  /// Pure CommonMark without GitHub alert extensions or raw HTML tags.
  ///
  /// Uses standard blockquotes (`> **Error:**`, `> **Note:**`) and plain
  /// markdown headings/fences for collapsible sections.
  commonmark,

  /// GitLab-Flavored Markdown (GLFM).
  ///
  /// Uses standard bold blockquotes for callouts and `<details>/<summary>`
  /// collapsible blocks compatible with GitLab merge requests and issues.
  gitlab,
}
