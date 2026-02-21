# The Armory

Practical command-line tools for backups, security checks, service health, diagnostics, release hygiene, and agent-driven automation.

[![Armory CI](https://github.com/VontaJamal/armory/actions/workflows/armory-ci.yml/badge.svg)](https://github.com/VontaJamal/armory/actions/workflows/armory-ci.yml)

## First Run (Mac, 10 Seconds)

```bash
# Civilian start (plain language onboarding)
./setup.sh

# Crystal Saga start (Receive the Crystal)
./awakening.sh
```

## Choose Your Path

| Crystal Saga Mode | Civilian Mode |
|---|---|
| Final Fantasy flavor with clear technical instructions. | Plain-language onboarding for fast operational use. |
| [Open Crystal Saga Guide](README-SAGA.md) | [Open Civilian Guide](README-CIV.md) |
| [Dashboard (Saga)](https://vontajamal.github.io/armory/?mode=saga) | [Dashboard (Civ)](https://vontajamal.github.io/armory/?mode=civ) |

## Shared Essentials

```bash
# 1) Civilian-first bootstrap
./setup.sh --mode civ --command-word armory

# 2) Crystal Saga bootstrap (power-user lane)
./setup.sh --mode saga --command-word crystal

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

```bash
armory quartermaster scout --task "release readiness for this repo"
armory quartermaster plan --task "release readiness for this repo"
armory quartermaster equip --from-last-plan --approve
armory quartermaster report --from-last-plan
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
- [OpenClaw ecosystem references](references/openclaw-ecosystem.md)
- [Agent contract](AGENTS.md)
- [Agent doctrine](agent-doctrine.yml)
- [Telemetry contract](docs/TELEMETRY.md)
- [Contributing](CONTRIBUTING.md)
- [Documentation contract](DOCS-CONTRACT.md)
- [Policies](POLICIES/RELEASE.md), [Branch protection](POLICIES/BRANCH-PROTECTION.md), [Deprecation](POLICIES/DEPRECATION.md)

---

## Protected by the [Seven Shadows](https://github.com/VontaJamal/seven-shadow-system)

[Explore the Vault ->](https://github.com/VontaJamal/shadow-vault)

Part of [Sovereign](https://github.com/VontaJamal) - The Shadow Dominion.
