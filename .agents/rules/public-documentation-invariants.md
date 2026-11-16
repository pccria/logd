---
trigger: always_on
---

# Public Documentation & Changelog Invariants

When authoring, updating, or reviewing public documentation, changelogs, READMEs, doc comments, commit messages, PR descriptions, and release notes:

## 1. Strictly Prohibited: Store Points & Gamification Metrics
- **Never mention store points, scores, or metrics**: Never use terms like "pub points", "pub score", "160/160", "110/110", "pana points", or any gamified store metric in `CHANGELOG.md`, `README.md`, doc comments, public documentation, commit messages, PR descriptions, or release notes.
- **Focus on Technical Invariants**: Frame all improvements around technical capabilities, platform support, bug fixes, backward compatibility, and standards compliance.
  - ❌ *Incorrect*: "Fix rotation call to restore full 160/160 pub points and pass downgrade analysis."
  - ✅ *Correct*: "Fix rotation call to ensure backward compatibility with `package:logd` 0.10.6 across all supported platforms (iOS, Android, Linux, macOS, Windows, Web)."

## 2. Audience & Tone
- Changelogs and release notes must be written for library consumers, focusing on API changes, behavioral improvements, defect resolution, and environmental compatibility.
