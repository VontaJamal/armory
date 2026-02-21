# The Armory

Practical command-line tools for backups, security checks, service health, diagnostics, release hygiene, and scheduled automation.

[![Armory CI](https://github.com/VontaJamal/armory/actions/workflows/armory-ci.yml/badge.svg)](https://github.com/VontaJamal/armory/actions/workflows/armory-ci.yml)

## Choose Your Path

| Crystal Saga Mode | Civilian Mode |
|---|---|
| Final Fantasy flavor with clear technical instructions. | Plain-language onboarding for fast operational use. |
| [Open Crystal Saga Guide](README-SAGA.md) | [Open Civilian Guide](README-CIV.md) |
| [Dashboard (Saga)](https://vontajamal.github.io/armory/?mode=saga) | [Dashboard (Civ)](https://vontajamal.github.io/armory/?mode=civ) |

## Shared Essentials

```powershell
# 1) Install dispatcher
powershell -ExecutionPolicy Bypass -File .\awakening.ps1 -CommandWord armory

# 2) Check active mode
armory civs status

# 3) Switch modes
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

## Full Guides

1. [Crystal Saga Guide](README-SAGA.md)
2. [Civilian Guide](README-CIV.md)

Both guides use the same commands and system behavior; only language/presentation differs by mode.

## Core References

- [Machine manifest](docs/data/armory-manifest.v1.json)
- [Shop catalog](shop/catalog.json)
- [Dashboard app](docs/index.html)
- [Agent contract](AGENTS.md)
- [Agent doctrine](agent-doctrine.yml)
- [Telemetry contract](docs/TELEMETRY.md)
- [Contributing](CONTRIBUTING.md)
- [Documentation contract](DOCS-CONTRACT.md)
- [Policies](POLICIES/RELEASE.md), [Branch protection](POLICIES/BRANCH-PROTECTION.md), [Deprecation](POLICIES/DEPRECATION.md)
