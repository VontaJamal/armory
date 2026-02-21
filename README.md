# The Armory

Practical command-line tools for backups, security checks, service health, system diagnostics, and scheduled automation.

Themed names are kept for personality, but every tool below includes a plain-language purpose.

## Pick The Right Tool

| You Need To... | Use This Tool | Why |
|---|---|---|
| Set up a command word like `faye` | [`awakening.ps1`](awakening.ps1) | One-time setup for command routing and PATH |
| Save encrypted backups | [`weapons/phoenix-down/phoenix-down.ps1`](weapons/phoenix-down/phoenix-down.ps1) | Creates encrypted backup archives |
| Bootstrap backup automation | [`weapons/phoenix-down/save-point.ps1`](weapons/phoenix-down/save-point.ps1) | Sets up recurring backup + restore command |
| Verify backup health | [`spells/cure/cure.ps1`](spells/cure/cure.ps1) | Detects stale/corrupt backups and returns clear exit codes |
| Check services now | [`weapons/aegis/aegis.ps1`](weapons/aegis/aegis.ps1) | Service monitor with optional Telegram alerts |
| Scan repos for leaked secrets | [`weapons/scan/scan.ps1`](weapons/scan/scan.ps1) | Fast manual security scan |
| Run deeper secret scan | [`weapons/truesight/truesight.ps1`](weapons/truesight/truesight.ps1) | Broader and deeper security checks |
| Schedule security scans | [`spells/protect/protect.ps1`](spells/protect/protect.ps1) | Quiet cron-friendly scanner |
| Get a daily ops report | [`spells/libra/libra.ps1`](spells/libra/libra.ps1) | Operations health summary (not secret scanning) |
| Get a morning briefing | [`spells/regen/regen.ps1`](spells/regen/regen.ps1) | Weather + key daily status summary |
| Spawn/recover OpenClaw setups | Summons in [`summons/`](summons) | Purpose-built setup and diagnostics commands |
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

## Spells (scheduled automation)

- [`spells/libra/`](spells/libra/) - daily operations report.
- [`spells/cure/`](spells/cure/) - backup verification.
- [`spells/protect/`](spells/protect/) - scheduled security scan.
- [`spells/regen/`](spells/regen/) - morning briefing.

## Audio Layer

- [`bard/`](bard/) - optional sound effects and themes.

## Quick Start (Windows PowerShell 5.1)

```powershell
# 1) Pick your command word and install dispatcher
powershell -ExecutionPolicy Bypass -File .\awakening.ps1

# 2) Create a backup
powershell -ExecutionPolicy Bypass -File .\weapons\phoenix-down\phoenix-down.ps1

# 3) Run a service health check
powershell -ExecutionPolicy Bypass -File .\weapons\aegis\aegis.ps1

# 4) Run a security scan
powershell -ExecutionPolicy Bypass -File .\weapons\scan\scan.ps1
```

## Compatibility Aliases (One Release)

- `init.ps1` -> `awakening.ps1`
- `weapons/sentinel/sentinel.ps1` -> `weapons/aegis/aegis.ps1`
- `weapons/scan/deep-scan.ps1` -> `weapons/truesight/truesight.ps1`
- `weapons/phoenix-down/setup-rebirth.ps1` -> `weapons/phoenix-down/save-point.ps1`

## Armory Shopfront

The whole repository is the shopfront.

- Use [`shop/SHOP.md`](shop/SHOP.md) to browse the catalog.
- Use [`shop/catalog.json`](shop/catalog.json) for machine-readable entries.
- Use [`shop/ADD-TO-SHOP.md`](shop/ADD-TO-SHOP.md) to add a full tool or an idea-only entry.

## Contributing

Use [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full contribution flow.

Use [`DOCS-CONTRACT.md`](DOCS-CONTRACT.md) for all tool README updates.
