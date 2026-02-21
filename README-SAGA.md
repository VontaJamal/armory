# Armory Crystal Saga Guide

## What Armory Is

Armory is a practical command toolkit for real operational work: security checks, backups, diagnostics, release validation, and agent workflows.

Crystal Saga Mode keeps the instructions clear, then adds light flavor so the experience still feels like Armory.

## 5-Minute Setup

```powershell
# 1) Receive the Crystal (level one)
powershell -ExecutionPolicy Bypass -File .\awakening.ps1

# Optional explicit command word
powershell -ExecutionPolicy Bypass -File .\awakening.ps1 -CommandWord crystal

# 2) Confirm Crystal Saga Mode
armory civs off
armory civs status

# 3) Run quick health/security path
powershell -ExecutionPolicy Bypass -File .\items\remedy\remedy.ps1
powershell -ExecutionPolicy Bypass -File .\weapons\scan\scan.ps1

# 4) Open dashboard in saga voice
powershell -ExecutionPolicy Bypass -File .\shop\open-dashboard.ps1
```

## Crystal Saga Workflow (Manual + Agent-First)

Manual path:

1. Scout tools in `shop/catalog.json` or dashboard.
2. Pick your loadout.
3. Generate installer from dashboard cart.
4. Run installer and verify outcome.

Agent-first path:

1. Agent refreshes local Armory clone: `git -C <armoryRepoRoot> pull --ff-only`.
2. Agent runs `quartermaster scout` and returns shortlist.
3. Agent runs `quartermaster plan` to build the cart/loadout.
4. Human approves equip, then agent runs `quartermaster equip -FromLastPlan -Approve`.
5. Agent runs `quartermaster report -FromLastPlan` in active mode tone.

### Same System, Two Voices

Crystal Saga and Civilian are the same system and commands.
Only language changes.

- `equip loadout` <-> `install selected tools`
- `battle-ready` <-> `installation complete`

## Ask Your Agent

Use prompts like:

1. `Scout Armory for this repo issue, shortlist the best options, and wait for my approval.`
2. `Equip remedy + chronicle after approval and report exactly what was installed.`
3. `If refresh or install fails, stop and give a tactical failure report.`

## Tool Selection And Equip Examples

| Situation | Suggested tool(s) | Example saga report |
|---|---|---|
| Need environment baseline | `remedy` | `Remedy used. Field conditions are stable.` |
| Need secret hygiene pass | `scan`, `truesight` | `Truesight cast. Hidden leaks exposed.` |
| Need release readiness | `alexander` | `Alexander's gate stands open. Preflight passed.` |
| Need repo pulse | `chronicle` | `Chronicle updated. Frontline status delivered.` |

## Mode Controls (`civs`)

```powershell
armory civs status
armory civs off   # Crystal Saga Mode (mode=saga)
armory civs on    # Civilian Mode (mode=civ)
```

Mode is shared across dispatcher, dashboard, installer, and agent reporting.

## Troubleshooting

1. `armory` command not found: re-run `awakening.ps1` (or `setup.ps1`), then open a new shell session.
2. Dashboard loads but no entries appear: rebuild manifest with `python3 scripts/build_armory_manifest.py --out docs/data/armory-manifest.v1.json`.
3. Agent cannot refresh Armory clone: verify repo path and remote access, then run `git -C <armoryRepoRoot> pull --ff-only` manually.
4. Installer hash mismatch: regenerate installer from current dashboard state and confirm manifest ref aligns with repository head.

## Validation Commands

```bash
python3 scripts/validate_shop_catalog.py
python3 scripts/build_armory_manifest.py --out docs/data/armory-manifest.v1.json
python3 scripts/ci/check_manifest_determinism.py
python3 scripts/ci/validate_readmes.py
python3 scripts/ci/secret_hygiene.py
python3 scripts/release/validate_release.py --mode ci
```

```powershell
pwsh -File .\scripts\ci\help-smoke.ps1
pwsh -File .\scripts\ci\mode-contract-smoke.ps1
pwsh -File .\scripts\ci\run-fixture-tests.ps1 -SevenZipPath "C:\Program Files\7-Zip\7z.exe"
pwsh -File .\scripts\ci\run-chronicle-tests.ps1
pwsh -File .\items\remedy\remedy.ps1 -Detailed
```

## Contracts And References

- [Root README](README.md)
- [Civilian Guide](README-CIV.md)
- [Agent contract](AGENTS.md)
- [Agent doctrine](agent-doctrine.yml)
- [Manifest](docs/data/armory-manifest.v1.json)
- [Telemetry contract](docs/TELEMETRY.md)
