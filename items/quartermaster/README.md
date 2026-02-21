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

```bash
# Via installed command shim (recommended from any repo)
armory quartermaster scout --task "release readiness"
armory quartermaster plan --task "secret scan and repo status" --top 3
armory quartermaster equip --from-last-plan --approve
armory quartermaster report --from-last-plan

# Scout
bash ./items/quartermaster/quartermaster.sh scout --task "release readiness"

# Build cart/plan and persist it
bash ./items/quartermaster/quartermaster.sh plan --task "secret scan and repo status" --top 3

# Equip from saved plan (approval required)
bash ./items/quartermaster/quartermaster.sh equip --from-last-plan --approve

# Report status from saved plan
bash ./items/quartermaster/quartermaster.sh report --from-last-plan
```

## Discovery Rules

Armory root resolution order:

1. `--armory-root`
2. `~/.armory/config.json` (`repoRoot`)
3. `ARMORY_REPO_ROOT`
4. Common paths (`./armory`, `../armory`, `~/armory`, `~/Documents/Code Repos/armory`)
5. One-time prompt and persistence

## Saved Plan

Quartermaster persists the latest plan at:

- `~/.armory/quartermaster/last-plan.json`

Use `--from-last-plan` to resume equip/report.
