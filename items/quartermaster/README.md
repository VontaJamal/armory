# Quartermaster

Agent-first Armory automation from any repository.

## What It Does

Quartermaster runs the required flow:

1. Refresh Armory clone (`git -C <armoryRepoRoot> pull --ff-only`)
2. Scout and shortlist tools for the current task
3. Build a dependency-aware cart
4. Enforce explicit approval before equip/install
5. Equip selected tools and report in active mode tone (`saga|civ`)

## Commands

```powershell
# Scout
powershell -ExecutionPolicy Bypass -File .\items\quartermaster\quartermaster.ps1 scout -Task "release readiness"

# Build cart/plan and persist it
powershell -ExecutionPolicy Bypass -File .\items\quartermaster\quartermaster.ps1 plan -Task "secret scan and repo status" -Top 3

# Equip from saved plan (approval required)
powershell -ExecutionPolicy Bypass -File .\items\quartermaster\quartermaster.ps1 equip -FromLastPlan -Approve

# Report status from saved plan
powershell -ExecutionPolicy Bypass -File .\items\quartermaster\quartermaster.ps1 report -FromLastPlan
```

## Discovery Rules

Armory root resolution order:

1. `-ArmoryRoot`
2. `~/.armory/config.json` (`repoRoot`)
3. `ARMORY_REPO_ROOT`
4. Common paths (`./armory`, `../armory`, `~/armory`, `~/Documents/Code Repos/armory`)
5. One-time prompt and persistence

## Saved Plan

Quartermaster persists the latest plan at:

- `~/.armory/quartermaster/last-plan.json`

Use `-FromLastPlan` to resume equip/report.
