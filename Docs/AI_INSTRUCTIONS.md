# AI Development Instructions

Any AI assistant working on WindowsToolkit should read these first:

1. `Docs/PROJECT_CONTEXT.md`
2. `Docs/ARCHITECTURE.md`
3. `Docs/CODING_STANDARDS.md`
4. `Docs/CURRENT_SPRINT.md`

## Core Rules

- Do not invent a new architecture.
- Follow the existing Core / Modules / Data / Profiles structure.
- Modules orchestrate.
- Core modules contain reusable logic.
- Data-driven rules belong in JSON.
- Analyzer modules must be read-only.
- Never hardcode `C:\WindowsToolkit`.
- Never recommend disabling Defender, Windows Update, Store, Windows Hello, or core Windows services by default.

## Analyzer Pattern

1. Discover objects.
2. Ask the recommendation engine.
3. Create `New-ToolkitFinding` objects.
4. Export reports.

## Git

Use one logical commit per feature.

Good commits:

- `Add HP Analyzer`
- `Refactor Startup Analyzer to use recommendation engine`
- `Add HTML dashboard generator`

Bad commits:

- `stuff`
- `fix`
- `update`