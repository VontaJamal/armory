# The Armory

Practical command-line tools for backups, security checks, service health, diagnostics, release hygiene, and scheduled automation.

[![Armory CI](https://github.com/VontaJamal/armory/actions/workflows/armory-ci.yml/badge.svg)](https://github.com/VontaJamal/armory/actions/workflows/armory-ci.yml)

## First Run (10 Seconds)

```powershell
# Civilian start (plain language onboarding)
powershell -ExecutionPolicy Bypass -File .\setup.ps1

# Crystal Saga start (Receive the Crystal)
powershell -ExecutionPolicy Bypass -File .\awakening.ps1
```

## Choose Your Path

| Crystal Saga Mode | Civilian Mode |
|---|---|
| Final Fantasy flavor with clear technical instructions. | Plain-language onboarding for fast operational use. |
| [Open Crystal Saga Guide](README-SAGA.md) | [Open Civilian Guide](README-CIV.md) |
| [Dashboard (Saga)](https://vontajamal.github.io/armory/?mode=saga) | [Dashboard (Civ)](https://vontajamal.github.io/armory/?mode=civ) |

## Shared Essentials

```powershell
# 1) Civilian-first bootstrap
powershell -ExecutionPolicy Bypass -File .\setup.ps1

# 2) Crystal Saga bootstrap (power-user lane)
powershell -ExecutionPolicy Bypass -File .\awakening.ps1 -CommandWord crystal

# 3) Check active mode
armory civs status

# 4) Switch modes
armory civs off   # Crystal Saga Mode (mode=saga)
armory civs on    # Civilian Mode (mode=civ)
```

Single shared mode contract across dispatcher, dashboard, installer, and agent reports:

- key: `mode`
- values: `saga | civ`
- default: `saga`

## Agent-First Prompt Pattern

Use this pattern with Codex/OpenClaw:

`Scout Armory for this task, return a shortlist, wait for my approval, equip selected tools, and report back in active mode.`

Concrete CLI route:

```powershell
armory quartermaster scout -Task "release readiness for this repo"
armory quartermaster plan -Task "release readiness for this repo"
armory quartermaster equip -FromLastPlan -Approve
armory quartermaster report -FromLastPlan
```

## Full Guides

1. [Crystal Saga Guide](README-SAGA.md)
2. [Civilian Guide](README-CIV.md)

Both guides use the same commands and system behavior; only language/presentation differs by mode.

## Core References

- [Machine manifest](docs/data/armory-manifest.v1.json)
- [Shop catalog](shop/catalog.json)
- [Dashboard app](docs/index.html)
- [Quartermaster automation](items/quartermaster/README.md)
- [Agent contract](AGENTS.md)
- [Agent doctrine](agent-doctrine.yml)
- [Telemetry contract](docs/TELEMETRY.md)
- [Contributing](CONTRIBUTING.md)
- [Documentation contract](DOCS-CONTRACT.md)
- [Policies](POLICIES/RELEASE.md), [Branch protection](POLICIES/BRANCH-PROTECTION.md), [Deprecation](POLICIES/DEPRECATION.md)

---

## Protected by the [Seven Shadows](https://github.com/VontaJamal/seven-shadow-system)

Part of [Sovereign](https://github.com/VontaJamal) - The Shadow Dominion.
