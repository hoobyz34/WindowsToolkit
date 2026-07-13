# WindowsToolkit Agent Instructions

## Source of truth

Before making changes, read:

- `Docs/PROJECT_CONTEXT.md`
- `Docs/ARCHITECTURE.md`
- `Docs/CURRENT_SPRINT.md`
- `Docs/AI_INSTRUCTIONS.md`

Preserve the existing `Core` / `Modules` / `Data` / `Profiles` architecture.

## Development rules

- Keep analyzers read-only.
- Use the standard flow: Discovery → Recommendation → `New-ToolkitFinding` → Reporting.
- Keep reusable logic in `Core`.
- Keep recommendation knowledge and rules in JSON.
- Avoid unsafe broad matching.
- Protect Microsoft Defender, Windows Update, Microsoft Store, Windows Hello, OneDrive, Driver Easy, and core Windows components unless explicitly requested.
- Use focused tests while iterating, then run `.ToolsDev.ps1 -Action Verify` once for code changes.
- Fix routine, in-scope failures within the same task.
- Make one logical local commit after verification.
- Never push unless explicitly asked.
- Return short summaries only; provide full diffs only when requested.
