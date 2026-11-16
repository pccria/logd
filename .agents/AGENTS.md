# Repository Agent Rules

## Relative Paths Only
- **Never use full absolute paths**: Always use relative paths from the workspace root (e.g., `packages/logd/...`, `.agents/...`) in user communication, documentation, code comments, markdown links, scripts, and code in this repository. Never output or hardcode absolute paths like `/home/ono/Projects/...`.

## Public Documentation & Changelogs
- **Never mention store points, scores, or quotas**: Never write "pub points", "pub score", "160/160", or any gamified store metric in `CHANGELOG.md`, `README.md`, doc comments, commit messages, PR descriptions, or release notes. Always describe technical capabilities, bug fixes, backward compatibility, and platform support. See `.agents/rules/public-documentation-invariants.md`.

