# WindowsToolkit Agent Instructions

## Source of Truth

Read these files before changing code:

1. Docs/PROJECT_CONTEXT.md
2. Docs/ARCHITECTURE.md
3. Docs/CODING_STANDARDS.md
4. Docs/ROADMAP.md
5. Docs/CURRENT_SPRINT.md
6. Docs/AI_INSTRUCTIONS.md
7. CHANGELOG.md

Do not redesign the architecture or create parallel patterns.

## Purpose

WindowsToolkit is a modular PowerShell Windows audit, health assessment,
and safe optimization platform.

It is not a generic debloat script.

## Architecture

- Modules orchestrate.
- Core modules provide reusable functionality.
- Discovery is read-only.
- Recommendation knowledge belongs in Data/*.json.
- Analyzer modules produce New-ToolkitFinding objects.
- Reporting goes through Core/Reporting.psm1.
- Analyzer modules must remain read-only unless explicitly working on a future optimizer feature.

## Existing APIs

Use the existing names:

- Write-Section
- Write-Success
- Save-CsvReport
- New-ToolkitFinding
- Get-ToolkitRecommendation -Text <text> -Type <type>
- Get-ToolkitServices
- Get-ToolkitDrivers
- Get-ToolkitInstalledSoftware
- Get-ToolkitScheduledTasks
- Get-ToolkitStartupCommands
- Get-ToolkitWindowsFeatures
- Get-ToolkitAppxPackages

Do not invent replacement APIs unless the task explicitly requests a refactor.

## Safety

Never recommend disabling these by default:

- Microsoft Defender
- Windows Update
- Microsoft Store
- Windows Hello
- OneDrive
- Driver Easy
- Core Windows services
- HP functionality required for hotkeys, audio, thermal management, BIOS interfaces, or firmware

Every recommendation must explain:

- Reason
- Benefit
- Risk
- Potential breakage

## Paths

Never hardcode C:\WindowsToolkit in reusable code.

Resolve paths from $PSScriptRoot or existing toolkit path helpers.

Reports, logs, tests, and temporary artifacts must remain inside the repository
or approved temporary test directories.

## Development Workflow

Make one logical change at a time.

Before editing:

1. Run git status.
2. Require a clean working tree.
3. Inspect the relevant existing files.
4. Preserve existing conventions.

After editing:

1. Run .\Tools\Dev.ps1 -Action Verify
2. Review git diff.
3. Stage only files related to the task.
4. Use a clear imperative commit message.
5. Do not commit generated Reports, Logs, or Backups.

## Testing

All existing tests must pass.

Add or update Pester tests for behavior changes.

Do not weaken or delete tests merely to make a change pass.

Avoid tests that depend on destructive system changes.

Use mocks for privileged, filesystem, transcript, or system-changing behavior
when practical.

## Output Expectations

For each completed task, report:

- Files changed
- Behavior changed
- Tests run
- Test result
- Exact commit message

Do not perform unrelated cleanup.
