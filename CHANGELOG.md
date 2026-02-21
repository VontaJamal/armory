# Changelog

All notable changes to this repository are tracked here.

This file is also the release counter for deprecation windows (see `POLICIES/DEPRECATION.md`).

## [Unreleased]

### Added
- CI baseline with catalog validation, help smoke checks, and fixture tests.
- Shop validator, `materia-forge`, and `shop/list-shop` command support.
- Release hardening workflows: manual release dispatch, release validation, and secret hygiene enforcement.
- Branch protection and release policy docs.
- `chronicle` spell for cross-repo git intelligence with allowlist support.
- Command-word rename utility (`rename-command-word.ps1`) plus dispatcher routes.
- `remedy` item command for one-command environment health checks.
- `alexander` summon command for read-only release preflight gating (plus dispatcher alias `gate`).
- `civs` command to manage Civilian alias mode (`on`, `off`, `status`).

### Changed
- Documentation expanded for contributor workflow and policy references.
- CI required checks expanded to include `secret-hygiene` and `release-validate`.
- Fixture coverage expanded with Chronicle scenarios.
- Root README rewritten into onboarding-first flow with quick paths and release checklist.
- Dispatcher routes now include `remedy`, `alexander`, and `gate`.
- `esuna` now routes to Remedy as a supported long-term alias.
- Added full dispatcher-wide Civilian alias layer with mode control via `civs`.
- New scripts in this wave target Windows + macOS PowerShell compatibility.

### Deprecated
- `doctor.ps1` is now a compatibility alias to `items/remedy/remedy.ps1` and begins a two-release deprecation window.

## [2026-02-21] - Baseline

### Added
- Shop contribution framework and initial `mognet` idea entry.

### Deprecation Tracking
- Compatibility aliases are active and covered by two-release policy.
