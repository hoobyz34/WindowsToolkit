# Current Sprint

## Release

v0.7.0

## Goal

Add and harden the exact-identity HP Insights Analytics service capability on top of the gated Safe Optimizer executor.

## Release Status

Exact-identity HP Insights Analytics service capability and security hardening complete.

## Active Tasks

- [x] Exact `HpTouchpointAnalyticsService` JSON-allowlisted reversible service policy
- [x] Exact display-name, vendor, binary identity, dependency, and recovery validation
- [x] Dry-run, WhatIf, explicit Apply/confirmation, privilege, and rollback gates
- [x] Current preflight, live-state, and rollback-manifest validation
- [x] Standardized execution and rollback audit reporting
- [x] Deny-by-default artifact, policy, scope, and live-state hardening

## Blockers

None

## Release Commit

Finalize HP service optimizer release

## Definition of Done

The menu exposes plan review and dry-run without making Apply the default; no menu or reporting path mutates Windows state.

The sole executable scope is the exact internal service `HpTouchpointAnalyticsService` with display name `HP Insights Analytics` and HP identity metadata bound by JSON policy.

Actual execution requires explicit Apply, confirmation, ShouldProcess approval, administrator privilege, restore readiness, a current eligible preflight result, a valid reversible rollback manifest, matching live state and hashes, and an exact JSON allowlist match.

Protected, unsupported, stale, blocked, non-reversible, unsafe-dependency, identity-drift, and incomplete actions are denied with precise audit reasons.

Every attempt produces CSV and JSON execution/rollback audit records with immutable before-state and rollback metadata. Rollback restores the captured startup, running, recovery, and delayed-start state, then verifies dependencies and exact service identity metadata.

Git tag:

v0.7.0
