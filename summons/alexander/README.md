# Alexander (Preflight Gate)

## What This Does

Runs a read-only preflight gate for release readiness by executing Armory validation commands and summarizing pass/fail status.

## Who This Is For

- Maintainers preparing a release or merge.
- Contributors who want one command to validate local readiness.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\summons\alexander\alexander.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\summons\alexander\alexander.ps1
```

## Common Tasks

```powershell
# Run full preflight
powershell -ExecutionPolicy Bypass -File .\summons\alexander\alexander.ps1

# Skip long-running checks
powershell -ExecutionPolicy Bypass -File .\summons\alexander\alexander.ps1 -Skip fixtures,chronicle

# Include command output from each check
powershell -ExecutionPolicy Bypass -File .\summons\alexander\alexander.ps1 -Detailed

# Write report to a file
powershell -ExecutionPolicy Bypass -File .\summons\alexander\alexander.ps1 -Output "$env:USERPROFILE\.armory\reports\alexander.txt"
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Skip <name[]>` | none | Skip selected checks (`catalog`, `secrets`, `remote`, `smoke`, `fixtures`, `chronicle`, `release`, `remedy`) |
| `-Detailed` | off | Includes output payload for each invoked check |
| `-Output <path>` | none | Writes report text to disk |
| `-Sound` | off | Enables optional start/success/fail cues |
| `-NoSound` | off | Forces sound cues off |
| `-Help` | off | Prints usage and exits |

## Config

Alexander uses repo-local commands and scripts:

- `scripts/validate_shop_catalog.py`
- `scripts/ci/secret_hygiene.py`
- `scripts/ci/check_remote_url.ps1`
- `scripts/ci/help-smoke.ps1`
- `scripts/ci/run-fixture-tests.ps1`
- `scripts/ci/run-chronicle-tests.ps1`
- `scripts/release/validate_release.py --mode ci`
- `items/remedy/remedy.ps1`

It auto-detects `python3`/`python`, `powershell`/`pwsh`, and `7z`.

## Output And Exit Codes

- `0`: all non-skipped checks passed.
- `1`: one or more checks failed.
- `WARN` indicates a skipped check, not an automatic failure.

## Troubleshooting

- Missing Python: install Python and make `python3` or `python` available in PATH.
- Fixture failure due to 7-Zip: install 7-Zip or add `7z` to PATH.
- Remote credential failure: scrub embedded credentials from `git remote -v` URLs.

## Automation Examples

```powershell
# Release-day local gate (full)
powershell -ExecutionPolicy Bypass -File .\summons\alexander\alexander.ps1 -Detailed

# Faster gate for quick iteration
powershell -ExecutionPolicy Bypass -File .\summons\alexander\alexander.ps1 -Skip fixtures,chronicle
```

## FAQ

**Does Alexander create tags or push releases?**
No. It is read-only and only validates readiness.

**Can I run just one failing area repeatedly?**
Yes. Use `-Skip` to exclude unrelated checks while you iterate.

## Migration Notes

- New summon introduced in this wave.
- Dispatcher routes include themed `alexander` and plain alias `gate`.
