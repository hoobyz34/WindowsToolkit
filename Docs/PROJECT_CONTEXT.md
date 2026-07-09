# WindowsToolkit Project Context

> This document is the canonical reference for the WindowsToolkit project.
>
> Any developer or AI assistant working on this repository should read this
> document before making architectural or implementation changes.

---

# Vision

WindowsToolkit is a modular Windows auditing, health assessment, and safe
optimization platform.

Its purpose is **not** to aggressively debloat Windows.

Its purpose is to:

- Understand the system.
- Explain findings.
- Recommend safe actions.
- Preserve stability.
- Never surprise the user.

The toolkit should become something that can be run after every Windows
installation to produce a trustworthy assessment.

---

# Primary Goals

1. Inventory the system.
2. Analyze findings.
3. Generate recommendations.
4. Produce professional reports.
5. Apply changes only after confirmation.
6. Support rollback whenever practical.

---

# Design Philosophy

## Audit First

Never change the system before understanding it.

Analysis always comes before optimization.

---

## Explain Every Recommendation

Every recommendation must answer:

- Why?
- What breaks?
- What is the benefit?
- What is the risk?

No unexplained suggestions.

---

## Safety First

Never recommend disabling:

- Microsoft Defender
- Windows Update
- Windows Store
- Windows Hello
- Core Windows services

unless explicitly requested.

---

## Data Driven

Knowledge belongs in JSON.

Logic belongs in PowerShell.

Avoid hardcoded vendor-specific rules whenever possible.

---

## Reusable Components

Modules should orchestrate.

Core modules should perform work.

Business logic belongs in Core.

---

# Current Architecture

WindowsToolkit/

    Start.ps1

    Core/
        Config.psm1
        Console.psm1
        Discovery.psm1
        Logger.psm1
        Models.psm1
        Recommendation.psm1
        Reporting.psm1
        Utility.psm1
        Version.psm1

    Modules/
        Audit.ps1
        Services.ps1
        Startup.ps1
        Software.ps1
        HP.ps1 (planned)
        Drivers.ps1 (planned)

    Data/
        Vendors.json
        Services.json
        Software.json
        Rules.json

    Profiles/
        HP_ZBook_Fury_G7.json

    Reports/
    Logs/
    Backups/

---

# Core Responsibilities

## Discovery

Find Windows objects.

Examples:

- Services
- Drivers
- Startup Items
- Software
- Scheduled Tasks

Discovery should not classify anything.

---

## Recommendation

Receives discovered objects.

Determines:

- Vendor
- Category
- Recommendation
- Risk
- Explanation

Uses JSON rules whenever possible.

---

## Models

Provides standard objects.

Every analyzer should return:

- Name
- Type
- Vendor
- Category
- Recommendation
- Risk
- Reason
- Source
- Version
- State

---

## Reporting

Responsible for:

- CSV
- JSON
- HTML (future)

Modules should not implement reporting logic.

---

# Coding Standards

## Modules

Modules should be thin.

Good module:

Discover

↓

Recommendation

↓

Finding

↓

Report

Modules should not contain large decision trees.

---

## PowerShell Style

Use:

- Verb-Noun naming
- Comment-based help
- One responsibility per function

Avoid:

Large monolithic scripts

Nested if/else chains

Hardcoded paths

Duplicate logic

---

## Git Workflow

One logical feature per commit.

Examples:

Add discovery engine

Refactor service analyzer

Add HP analyzer

Avoid commits like:

misc fixes

changes

update

---

## Versioning

Development:

v0.x

Stable:

v1.0

Create Git tags for milestones.

Example:

git tag v0.3.0

---

# Current User Preferences

Primary machine:

HP ZBook Fury G7

Windows:

Windows 11

Preserve:

- Windows Defender
- Windows Update
- Windows Store
- Windows Hello
- OneDrive
- Driver Easy

Review:

- HP telemetry
- HP analytics
- HP Insights
- HP Touchpoint

Avoid recommendations that contradict these preferences.

---

# Current Roadmap

Sprint 1

Completed

✓ Audit

✓ Services

✓ Startup

✓ Recommendation Engine

✓ Discovery Engine

Sprint 2

In Progress

- HP Analyzer
- Installed Software Analyzer
- Driver Analyzer

Sprint 3

- HTML Dashboard
- Health Score
- JSON Reporting

Sprint 4

- Safe Optimizer
- Restore Points
- Rollback

---

# Long-Term Vision

WindowsToolkit should become a professional Windows administration platform.

Goals:

- Accurate inventory
- Explainable recommendations
- Vendor-aware analysis
- Safe optimization
- Excellent reporting
- Extensible architecture

It should prioritize correctness and maintainability over cleverness.

Future contributors or AI assistants should extend the existing architecture rather than introducing parallel patterns.

When in doubt:

Keep modules simple.

Keep Core reusable.

Keep recommendations explainable.