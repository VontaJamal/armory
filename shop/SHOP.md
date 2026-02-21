# Armory Shop

This repository is the shopfront. Every useful Final Fantasy-themed tool can be listed here.

Use this file as the human-readable shelf and [`catalog.json`](catalog.json) as the machine-readable source.

## Browse The Catalog

```powershell
# Default table view
powershell -ExecutionPolicy Bypass -File .\shop\list-shop.ps1

# Show only ideas
powershell -ExecutionPolicy Bypass -File .\shop\list-shop.ps1 -IdeasOnly

# Filter by class and status
powershell -ExecutionPolicy Bypass -File .\shop\list-shop.ps1 -Class weapon -Status active

# Export JSON for automation
powershell -ExecutionPolicy Bypass -File .\shop\list-shop.ps1 -Format json

# Markdown output for docs or PR comments
powershell -ExecutionPolicy Bypass -File .\shop\list-shop.ps1 -Format markdown
```

## How To Add Something

1. If you have a script now, follow full-tool flow in [`ADD-TO-SHOP.md`](ADD-TO-SHOP.md).
2. If you only have an idea, add an idea entry now so others can build it later.
3. Use [`../materia-forge.ps1`](../materia-forge.ps1) for guided scaffolding.

## Active Highlights

## Alexander (Summon)

- Plain description: Read-only local release preflight gate that runs Armory validation commands and reports pass/fail.
- Flavor line: A fortress gate that tests your readiness before deployment.
- Script: [`../summons/alexander/alexander.ps1`](../summons/alexander/alexander.ps1)

## Chronicle (Spell)

- Plain description: Cross-repo git intelligence with branch status, ahead/behind, dirty state, and recent commits.
- Flavor line: A living record of every front in your codebase.
- Script: [`../spells/chronicle/chronicle.ps1`](../spells/chronicle/chronicle.ps1)

## Remedy (Item)

- Plain description: Read-only environment health checker for Armory config, wrappers, scripts, CI files, remotes, and dependencies.
- Flavor line: A field medicine kit for your local toolchain.
- Script: [`../items/remedy/remedy.ps1`](../items/remedy/remedy.ps1)

## Current Idea Shelf

## Mognet (Idea)

- Plain description: Unified notification relay for tool outputs, with channel routing, retries, and digest formatting.
- Flavor line: A reliable message network for operational updates.
- Status: idea-only (not implemented yet).

## Categories

- `summon`: larger workflow or orchestration tools
- `weapon`: direct-use operational or security utilities
- `spell`: scheduled automation tools
- `item`: docs and helper assets
- `audio`: sound/theme helpers
- `idea`: unimplemented but useful proposals

## Catalog Stubs (Auto-Generated)

`materia-forge.ps1` appends or updates short catalog stub lines in this section.

- `chronicle` (spell/active): Cross-repo git intelligence with branch status, ahead/behind, dirty state, and recent commits.
- `alexander` (summon/active): Read-only local release preflight gate that runs Armory validation commands and reports pass/fail.
- `remedy` (item/active): Read-only environment health checker for Armory config, wrappers, scripts, CI files, remotes, and dependencies.
- `mognet` (idea/idea): Unified notification relay for tool outputs, with channel routing, retries, and digest formatting.
