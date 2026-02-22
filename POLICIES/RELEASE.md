# Armory Release Policy

This policy defines how Armory releases are validated, tagged, and published.

## Release Versioning

Armory releases use semantic version tags in this exact format:

- `vMAJOR.MINOR.PATCH`

Examples:

- `v1.0.0`
- `v1.3.4`

## Release Trigger

Releases are created through manual GitHub Actions dispatch:

- Workflow: `.github/workflows/release.yml`
- Trigger: `workflow_dispatch`

Required inputs:

1. `version` (must match `^v\d+\.\d+\.\d+$`)
2. `target_branch` (default `main`)
3. `dry_run` (validation-only mode)

## Required Release Gates

A release is blocked unless all required checks passed for the target commit:

1. `docs-validate`
2. `catalog-validate`
3. `secret-hygiene`
4. `seven-shadow-trust-guard`
5. `mac-runtime-smoke`
6. `release-validate`

## Courtesy Checks (Non-Blocking)

These can run as informational checks but are not required release gates:

1. `powershell-smoke`
2. `fixture-tests`

## Changelog Requirements

Before release:

1. `CHANGELOG.md` must contain `## [Unreleased]`.
2. `CHANGELOG.md` must contain a section for the exact release tag, for example `## [v1.2.0]`.
3. Release section must not contain placeholders like `TODO` or `TBD`.

## Tagging Rules

1. Release tag must not already exist locally or on `origin`.
2. Signed tag creation is supported when signing is configured.
3. If signing is unavailable, workflow falls back to annotated unsigned tags.

## Release Notes Source

Published GitHub release notes are extracted from the matching version section in `CHANGELOG.md`.

## Preflight Commands (Local)

```bash
python3 scripts/ci/validate_readmes.py
python3 scripts/validate_shop_catalog.py
python3 scripts/ci/secret_hygiene.py
python3 scripts/ci/validate_trust_store.py
bash scripts/ci/mac-smoke.sh
python3 scripts/release/validate_release.py --mode ci
```

```powershell
pwsh -File .\scripts\ci\check_remote_url.ps1
pwsh -File .\scripts\ci\help-smoke.ps1
pwsh -File .\scripts\ci\run-fixture-tests.ps1 -SevenZipPath "C:\Program Files\7-Zip\7z.exe"
```
