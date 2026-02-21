# The Armory

Practical command-line tools for backups, security checks, service health, diagnostics, and scheduled automation.

Themed names are for personality. Instructions are plain-language first.

[![Armory CI](https://github.com/VontaJamal/armory/actions/workflows/armory-ci.yml/badge.svg)](https://github.com/VontaJamal/armory/actions/workflows/armory-ci.yml)

## Pick The Right Tool

| You need to... | Use this tool | Why |
|---|---|---|
| Set up a command word like `faye` | [`awakening.ps1`](awakening.ps1) | One-time setup for command routing and PATH |
| Save encrypted backups | [`weapons/phoenix-down/phoenix-down.ps1`](weapons/phoenix-down/phoenix-down.ps1) | Creates encrypted backup archives |
| Bootstrap backup automation | [`weapons/phoenix-down/save-point.ps1`](weapons/phoenix-down/save-point.ps1) | Sets up recurring backup + restore command |
| Verify backup health | [`spells/cure/cure.ps1`](spells/cure/cure.ps1) | Detects stale/corrupt backups and returns strict exit codes |
| Check services now | [`weapons/aegis/aegis.ps1`](weapons/aegis/aegis.ps1) | Service monitor with optional alerts |
| Scan repos for leaked secrets | [`weapons/scan/scan.ps1`](weapons/scan/scan.ps1) | Fast manual security scan |
| Run deeper security scan | [`weapons/truesight/truesight.ps1`](weapons/truesight/truesight.ps1) | Broader and deeper security checks |
| Schedule security scans | [`spells/protect/protect.ps1`](spells/protect/protect.ps1) | Quiet cron-friendly scanner |
| Get daily ops intelligence | [`spells/libra/libra.ps1`](spells/libra/libra.ps1) | Operations health summary (not secret scanning) |
| Get a morning briefing | [`spells/regen/regen.ps1`](spells/regen/regen.ps1) | Weather + key daily status summary |
| Add optional sound cues | [`bard/bard.ps1`](bard/bard.ps1) | Start/success/fail cues across tools |

## Tools By Category

## Summons (full workflows)

- [`summons/bahamut/`](summons/bahamut/) - restore a full environment from encrypted backup.
- [`summons/ifrit/`](summons/ifrit/) - create and register a new specialist agent.
- [`summons/odin/`](summons/odin/) - run cleanup for stale logs/temp/session files.
- [`summons/ramuh/`](summons/ramuh/) - run an all-in-one system diagnostic.
- [`summons/shiva/`](summons/shiva/) - capture and compare machine snapshots.

## Weapons (manual tools)

- [`weapons/masamune/`](weapons/masamune/) - manage and swap provider API keys.
- [`weapons/phoenix-down/`](weapons/phoenix-down/) - create encrypted backups and setup restore flows.
- [`weapons/aegis/`](weapons/aegis/) - service health checks.
- [`weapons/scan/`](weapons/scan/) - fast security scan.
- [`weapons/truesight/`](weapons/truesight/) - deep security scan.
- [`weapons/jutsu/`](weapons/jutsu/) - macOS zsh key-swap and gateway helper.
- `weapons/warp/` (planned) - one-command SSH into any machine. No memorizing IPs or keys.

## Spells (scheduled automation)

- [`spells/libra/`](spells/libra/) - daily operations report.
- [`spells/cure/`](spells/cure/) - backup verification.
- [`spells/protect/`](spells/protect/) - scheduled security scan.
- [`spells/regen/`](spells/regen/) - morning briefing.

## Audio Layer

- [`bard/`](bard/) - optional sound effects and themes.

## Quick Start (Windows PowerShell 5.1)

```powershell
# Install command dispatcher
powershell -ExecutionPolicy Bypass -File .\awakening.ps1

# Browse shop catalog
powershell -ExecutionPolicy Bypass -File .\shop\list-shop.ps1

# Run a backup check
powershell -ExecutionPolicy Bypass -File .\spells\cure\cure.ps1
```

## Shopfront And Contribution Path

This repository is the shopfront.

1. Browse catalog docs: [`shop/SHOP.md`](shop/SHOP.md)
2. Browse catalog data: [`shop/catalog.json`](shop/catalog.json)
3. Add new entries: [`shop/ADD-TO-SHOP.md`](shop/ADD-TO-SHOP.md)
4. Scaffold a new tool: `powershell -ExecutionPolicy Bypass -File .\materia-forge.ps1`

Examples:

```powershell
# Table view
powershell -ExecutionPolicy Bypass -File .\shop\list-shop.ps1

# JSON output for automation
powershell -ExecutionPolicy Bypass -File .\shop\list-shop.ps1 -Format json

# Scaffold a weapon tool
powershell -ExecutionPolicy Bypass -File .\materia-forge.ps1 -Category weapon -Name "Aero Guard" -Description "Monitors service restarts"

# Add an idea-only entry
powershell -ExecutionPolicy Bypass -File .\materia-forge.ps1 -Category idea -Name "Mognet" -Description "Unified notification relay for tool outputs" -FlavorLine "A reliable message network for operational updates."
```

## CI And Validation

CI runs five required checks:

1. `catalog-validate` (`scripts/validate_shop_catalog.py`)
2. `secret-hygiene` (`scripts/ci/secret_hygiene.py` + `scripts/ci/check_remote_url.ps1`)
3. `powershell-smoke` (`scripts/ci/help-smoke.ps1`)
4. `fixture-tests` (`scripts/ci/run-fixture-tests.ps1`)
5. `release-validate` (`scripts/release/validate_release.py --mode ci`)

Local commands:

```bash
python3 scripts/validate_shop_catalog.py
python3 scripts/ci/secret_hygiene.py
python3 scripts/release/validate_release.py --mode ci
```

```powershell
pwsh -File .\scripts\ci\check_remote_url.ps1
pwsh -File .\scripts\ci\help-smoke.ps1
pwsh -File .\scripts\ci\run-fixture-tests.ps1 -SevenZipPath "C:\Program Files\7-Zip\7z.exe"
```

## Release Flow

Releases are manual and gated.

1. Add a semver section to `CHANGELOG.md` (for example `## [v1.2.0]`).
2. Run preflight checks locally.
3. Run GitHub workflow `Armory Release` with:
4. `version` set to `vMAJOR.MINOR.PATCH`.
5. `target_branch` set to `main` (default).
6. `dry_run` first, then real release.

Policy docs:

- [`POLICIES/RELEASE.md`](POLICIES/RELEASE.md)
- [`POLICIES/BRANCH-PROTECTION.md`](POLICIES/BRANCH-PROTECTION.md)

## Compatibility Aliases (One Release)

- `init.ps1` -> `awakening.ps1`
- `weapons/sentinel/sentinel.ps1` -> `weapons/aegis/aegis.ps1`
- `weapons/scan/deep-scan.ps1` -> `weapons/truesight/truesight.ps1`
- `weapons/phoenix-down/setup-rebirth.ps1` -> `weapons/phoenix-down/save-point.ps1`

Deprecation lifecycle is documented in [`POLICIES/DEPRECATION.md`](POLICIES/DEPRECATION.md) and tracked in [`CHANGELOG.md`](CHANGELOG.md).

## Tool Categories

- Summons: [`summons/`](summons/) - full workflows and orchestration commands.
- Weapons: [`weapons/`](weapons/) - direct-use operational and security utilities.
- Spells: [`spells/`](spells/) - scheduler-friendly recurring checks.
- Items: [`items/`](items/) - practical reference guides.
- Audio: [`bard/`](bard/) - optional sound themes.

## Contributor Docs

- Contribution workflow: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- README contract for each tool: [`DOCS-CONTRACT.md`](DOCS-CONTRACT.md)
- Deprecation lifecycle policy: [`POLICIES/DEPRECATION.md`](POLICIES/DEPRECATION.md)
- Release lifecycle policy: [`POLICIES/RELEASE.md`](POLICIES/RELEASE.md)
- Branch protection baseline: [`POLICIES/BRANCH-PROTECTION.md`](POLICIES/BRANCH-PROTECTION.md)
