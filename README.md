# The Armory

Practical command-line tools for backups, security checks, service health, diagnostics, release hygiene, and scheduled automation.

Themed names stay for personality. Instructions stay plain-language first.

[![Armory CI](https://github.com/VontaJamal/armory/actions/workflows/armory-ci.yml/badge.svg)](https://github.com/VontaJamal/armory/actions/workflows/armory-ci.yml)

## What's New (Latest Wave)

- Added `chronicle` for cross-repo git intelligence (plus plain alias `status`).
- Added easy command-word rename utility: `rename-command-word.ps1`.
- Added release hardening workflows and policies (`release.yml`, release validator, branch protection baseline).
- Expanded CI with secret hygiene and release validation checks.
- Added `remedy` as the primary one-command environment health checker.
- Added `alexander` summon as a read-only release preflight gate (plain alias `gate`).
- Deprecated `doctor` as an alias to `remedy` (two-release window). `esuna` remains a supported alias.
- Added `civs` command for Civilian alias mode (`on`, `off`, `status`).
- Civilian aliases are ON by default across commands. Jump to `Civilian Alias Map (for the uninitiated)` below.
- Cross-platform support is preferred, but platform-specific tools are allowed when clearly documented.

## Start Here In 5 Minutes

```powershell
# 1) Install your command word dispatcher (example: armory)
powershell -ExecutionPolicy Bypass -File .\awakening.ps1 -CommandWord armory

# 2) Quick security scan
powershell -ExecutionPolicy Bypass -File .\weapons\scan\scan.ps1

# 3) Backup health check
powershell -ExecutionPolicy Bypass -File .\spells\cure\cure.ps1

# 4) Cross-repo status (uses ~/.armory/repos.json)
powershell -ExecutionPolicy Bypass -File .\spells\chronicle\chronicle.ps1

# 5) Run one-command environment health checks
powershell -ExecutionPolicy Bypass -File .\items\remedy\remedy.ps1

# 6) Rename command word later (example: armory -> faye)
powershell -ExecutionPolicy Bypass -File .\rename-command-word.ps1 faye

# 7) Check Civilian alias mode
<command-word> civs status
```

## Command Word Lifecycle

1. First setup: run `awakening.ps1` to create `%USERPROFILE%\bin\<commandWord>.cmd`.
2. Daily use: run commands like `<command-word> scan` or `<command-word> chronicle`.
3. Rename later:
4. direct script: `powershell -ExecutionPolicy Bypass -File .\rename-command-word.ps1 newword`
5. dispatcher route: `<command-word> rename newword`
6. Keep old alias when needed: `-KeepOldAlias`.
7. Chronicle alias: `<command-word> status` routes to `chronicle`.
8. Alexander alias: `<command-word> gate` routes to `alexander`.
9. Civilian alias controls: `<command-word> civs on|off|status`.

## Civilian Alias Map (for the uninitiated)

Every command has a welcoming, plain-language path so anyone can use Armory without memorizing lore names first.

Use this if you're new:

```powershell
<command-word> secret-scan
<command-word> backup
<command-word> preflight
<command-word> repo-status
<command-word> health -Detailed
```

Civilian mode controls:

```powershell
<command-word> civs status
<command-word> civs off
<command-word> civs on
```

| Primary command | Civilian alias |
|---|---|
| `awakening` / `init` | `setup` |
| `shop` | `catalog` |
| `forge` / `materia-forge` | `scaffold` |
| `rename` / `rename-word` | `rename-cmd` |
| `remedy` | `health` |
| `reload` | `restart` |
| `swap` / `masamune` | `keys` |
| `list` | `keys-list` |
| `bahamut` | `restore` |
| `ifrit` | `create-agent` |
| `odin` | `cleanup` |
| `ramuh` | `diagnose` |
| `shiva` | `snapshot` |
| `alexander` / `gate` | `preflight` |
| `phoenix-down` | `backup` |
| `save-point` | `backup-bootstrap` |
| `aegis` | `services` |
| `scan` | `secret-scan` |
| `truesight` | `deep-security-scan` |
| `libra` | `ops-report` |
| `cure` | `backup-check` |
| `protect` | `scheduled-scan` |
| `regen` | `morning-report` |
| `chronicle` / `status` | `repo-status` |
| `bard` | `audio` |

## Operations Quick Paths

### Daily

```powershell
<command-word> remedy
<command-word> libra
<command-word> chronicle
```

### Weekly

```powershell
<command-word> protect
<command-word> cure
<command-word> scan
```

### Release Day

```bash
python3 scripts/validate_shop_catalog.py
python3 scripts/ci/secret_hygiene.py
python3 scripts/release/validate_release.py --mode ci
```

```powershell
pwsh -File .\scripts\ci\check_remote_url.ps1
pwsh -File .\scripts\ci\help-smoke.ps1
pwsh -File .\scripts\ci\run-fixture-tests.ps1 -SevenZipPath "C:\Program Files\7-Zip\7z.exe"
pwsh -File .\scripts\ci\run-chronicle-tests.ps1
pwsh -File .\summons\alexander\alexander.ps1
```

### Incident

```powershell
<command-word> aegis
<command-word> truesight
<command-word> remedy -Detailed
```

## Release Day Checklist

1. Ensure `CHANGELOG.md` has a semver section like `## [v1.2.0]`.
2. Run local preflight commands above.
3. Run GitHub workflow `Armory Release` in dry run mode.
4. Re-run without dry run to publish tag and release notes.

Policy references:

- [`POLICIES/RELEASE.md`](POLICIES/RELEASE.md)
- [`POLICIES/BRANCH-PROTECTION.md`](POLICIES/BRANCH-PROTECTION.md)
- [`POLICIES/DEPRECATION.md`](POLICIES/DEPRECATION.md)

## Pick The Right Tool

Every dispatcher command also has a Civilian alias listed in the map above.

| You need to... | Use this tool | Why |
|---|---|---|
| Set up a command word | [`awakening.ps1`](awakening.ps1) | One-time setup for dispatcher + PATH |
| Toggle Civilian alias mode | [`civs.ps1`](civs.ps1) | Turns Civilian aliases on/off and shows current mode |
| Rename command word later | [`rename-command-word.ps1`](rename-command-word.ps1) | Move to any new command word quickly |
| Run one-command environment checks | [`items/remedy/remedy.ps1`](items/remedy/remedy.ps1) | Validates config, wrapper, scripts, CI files, remotes, deps |
| Keep old environment-check alias during migration | [`doctor.ps1`](doctor.ps1) | Deprecated alias forwarding to Remedy |
| Run a one-command release preflight gate | [`summons/alexander/alexander.ps1`](summons/alexander/alexander.ps1) | Runs local validation suite and returns pass/fail |
| Save encrypted backups | [`weapons/phoenix-down/phoenix-down.ps1`](weapons/phoenix-down/phoenix-down.ps1) | Creates encrypted backup archives |
| Verify backup health | [`spells/cure/cure.ps1`](spells/cure/cure.ps1) | Stale/corrupt detection with strict exit codes |
| Check service health now | [`weapons/aegis/aegis.ps1`](weapons/aegis/aegis.ps1) | Fast service monitor |
| Run fast secret scan | [`weapons/scan/scan.ps1`](weapons/scan/scan.ps1) | Manual security scan |
| Run deeper secret scan | [`weapons/truesight/truesight.ps1`](weapons/truesight/truesight.ps1) | Broader and deeper checks |
| Schedule security scans | [`spells/protect/protect.ps1`](spells/protect/protect.ps1) | Scheduler-friendly security workflow |
| Get daily ops intelligence | [`spells/libra/libra.ps1`](spells/libra/libra.ps1) | Ops report with optional repo pulse |
| Get cross-repo git intelligence | [`spells/chronicle/chronicle.ps1`](spells/chronicle/chronicle.ps1) | Branch/dirty/ahead-behind + recent commits |
| Use plain alias for chronicle | Dispatcher `status` | Easier language for regular users |
| Use plain alias for Alexander preflight | Dispatcher `gate` | Easier language for regular users |
| Use welcoming aliases across the full suite | Civilian Alias Map (above) | Maximum symbiosis for new and experienced users |
| Add sound cues | [`bard/bard.ps1`](bard/bard.ps1) | Start/success/fail cues across tools |

## Tool Catalog

### Summons (full workflows)

- [`summons/alexander/`](summons/alexander/) - read-only release preflight gate.
- [`summons/bahamut/`](summons/bahamut/) - restore full environment from encrypted backup.
- [`summons/ifrit/`](summons/ifrit/) - create and register specialist agent.
- [`summons/odin/`](summons/odin/) - clean stale logs/temp/session files.
- [`summons/ramuh/`](summons/ramuh/) - all-in-one system diagnostic.
- [`summons/shiva/`](summons/shiva/) - capture and compare machine snapshots.

### Weapons (manual tools)

- [`weapons/masamune/`](weapons/masamune/) - provider API key swapping.
- [`weapons/phoenix-down/`](weapons/phoenix-down/) - encrypted backup workflows.
- [`weapons/aegis/`](weapons/aegis/) - service health checks.
- [`weapons/scan/`](weapons/scan/) - fast security scan.
- [`weapons/truesight/`](weapons/truesight/) - deep security scan.
- [`weapons/jutsu/`](weapons/jutsu/) - macOS zsh swap + gateway helper.
- `weapons/warp/` (planned) - one-command SSH into any machine.

### Spells (scheduled/automation-focused)

- [`spells/libra/`](spells/libra/) - daily operations report.
- [`spells/cure/`](spells/cure/) - backup verification.
- [`spells/protect/`](spells/protect/) - scheduled security scan.
- [`spells/regen/`](spells/regen/) - morning briefing.
- [`spells/chronicle/`](spells/chronicle/) - cross-repo git intelligence.

### Items (utility helpers)

- [`items/remedy/`](items/remedy/) - one-command environment health checks.

### Audio Layer

- [`bard/`](bard/) - optional sound effects and themes.

## Shopfront And Contributions

This repository is the shopfront.

1. Browse catalog docs: [`shop/SHOP.md`](shop/SHOP.md)
2. Browse catalog data: [`shop/catalog.json`](shop/catalog.json)
3. Add ideas or tools: [`shop/ADD-TO-SHOP.md`](shop/ADD-TO-SHOP.md)
4. Scaffold with: `powershell -ExecutionPolicy Bypass -File .\materia-forge.ps1`

## CI And Local Validation

Required CI checks:

1. `catalog-validate`
2. `secret-hygiene`
3. `powershell-smoke`
4. `fixture-tests`
5. `release-validate`

Local validation commands:

```bash
python3 scripts/validate_shop_catalog.py
python3 scripts/ci/secret_hygiene.py
python3 scripts/release/validate_release.py --mode ci
```

```powershell
pwsh -File .\scripts\ci\check_remote_url.ps1
pwsh -File .\scripts\ci\help-smoke.ps1
pwsh -File .\scripts\ci\run-fixture-tests.ps1 -SevenZipPath "C:\Program Files\7-Zip\7z.exe"
pwsh -File .\scripts\ci\run-chronicle-tests.ps1
pwsh -File .\items\remedy\remedy.ps1 -Detailed
pwsh -File .\summons\alexander\alexander.ps1
```

## Compatibility Aliases

- `init.ps1` -> `awakening.ps1`
- `weapons/sentinel/sentinel.ps1` -> `weapons/aegis/aegis.ps1`
- `weapons/scan/deep-scan.ps1` -> `weapons/truesight/truesight.ps1`
- `weapons/phoenix-down/setup-rebirth.ps1` -> `weapons/phoenix-down/save-point.ps1`
- `doctor.ps1` -> `items/remedy/remedy.ps1` (deprecated for two releases)
- dispatcher `esuna` -> `items/remedy/remedy.ps1` (supported alias)

## Docs And Policies

- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`DOCS-CONTRACT.md`](DOCS-CONTRACT.md)
- [`POLICIES/DEPRECATION.md`](POLICIES/DEPRECATION.md)
- [`POLICIES/RELEASE.md`](POLICIES/RELEASE.md)
- [`POLICIES/BRANCH-PROTECTION.md`](POLICIES/BRANCH-PROTECTION.md)
- [`CHANGELOG.md`](CHANGELOG.md)

---

## Protected by the [Seven Shadows](https://github.com/VontaJamal/seven-shadow-system)

Part of [Sovereign](https://github.com/VontaJamal) — The Shadow Dominion.