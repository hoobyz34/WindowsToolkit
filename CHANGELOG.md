# Changelog

## v0.7.0

### Added

- Added a narrowly scoped, JSON-allowlisted reversible action for the exact `HpTouchpointAnalyticsService` (`HP Insights Analytics`) service.
- Added strict service identity, vendor/binary signature, dependency, recovery, live-state, manifest, privilege, confirmation, and rollback validation; dry-run remains the default and all other action types remain denied.

## v0.6.0

### Added

- Gated Safe Optimizer executor with dry-run/WhatIf defaults, explicit Apply and confirmation gates, current-state and rollback-manifest validation, and standardized CSV/JSON audit records.
- Deny-by-default executor hardening for forged or mismatched artifacts, protected components, policy integrity, HP scheduled-task scope, live-state drift, and conservative post-action reconciliation.

## v0.5.0

### Added

- Read-only optimization preflight validation with safety, state, privilege, restore-point readiness, and confirmation checks.
- Stable rollback manifests with before-state snapshots, reversibility metadata, and CSV/JSON reports.

## v0.4.0

### Added

- Safe Optimizer plan-only workflow that converts standardized findings into deterministic, confirmation-required plan entries.
- JSON-driven optimization action and protected-item policy with CSV and JSON plan reports.

## v0.3.0

### Added

- Standardized Startup, Installed Software, Driver, and HP analyzers through the discovery, recommendation, finding, and reporting pipeline.
- Added HP JSON recommendation data and focused analyzer coverage.
- Added focused recommendation boundary tests and fixed standalone Pester path resolution.

## v0.2.0

### Added

- Modular project architecture
- Git integration
- Audit module
- Service Analyzer
- Startup Analyzer
- Recommendation engine
- Configuration profiles
- Data-driven rule files
- Console UI
