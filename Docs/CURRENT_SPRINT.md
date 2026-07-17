# Current Sprint

## Release

v0.7.1

## Goal

Normalize exact-service rollback metadata while preserving every Safe Optimizer identity and safety gate.

## Release Status

Service rollback metadata normalization and v0.7 artifact compatibility complete.

## Active Tasks

- [x] Exact `HpTouchpointAnalyticsService` JSON-allowlisted reversible service policy
- [x] Exact display-name, vendor, binary identity, dependency, and recovery validation
- [x] Dry-run, WhatIf, explicit Apply/confirmation, privilege, and rollback gates
- [x] Current preflight, live-state, and rollback-manifest validation
- [x] Standardized execution and rollback audit reporting
- [x] Deny-by-default artifact, policy, scope, and live-state hardening
- [x] Canonical delayed-start metadata comparison and hashing
- [x] Existing v0.7 execution and rollback-manifest compatibility

## Blockers

None

## Release Commit

Release v0.7.1

## Definition of Done

The menu exposes plan review and dry-run without making Apply the default; no menu or reporting path mutates Windows state.

The sole executable scope is the exact internal service `HpTouchpointAnalyticsService` with display name `HP Insights Analytics` and HP identity metadata bound by JSON policy.

Actual execution requires explicit Apply, confirmation, ShouldProcess approval, administrator privilege, restore readiness, a current eligible preflight result, a valid reversible rollback manifest, matching live state and hashes, and an exact JSON allowlist match.

Protected, unsupported, stale, blocked, non-reversible, unsafe-dependency, identity-drift, and incomplete actions are denied with precise audit reasons.

Every attempt produces CSV and JSON execution/rollback audit records with immutable before-state and rollback metadata. Rollback restores the captured startup, running, recovery, and delayed-start state, then verifies dependencies and exact service identity metadata.

Semantically equivalent disabled delayed-start representations are canonicalized for comparison and hashing. Existing v0.7 artifacts validate when every immutable safety field matches, and their gated rollback is available without weakening meaningful drift detection.

Git tag:

v0.7.1
