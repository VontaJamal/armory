# README-SAGA

## What Armory Is

Armory is a Mac-first command and automation repository designed for both humans and agents. Crystal Saga Mode keeps instructions technical and clear, with light Final Fantasy flavor for status and reporting.

## 5-Minute Setup

```bash
./awakening.sh
# Suggested command word: crystal
```

This installs your command shim into `~/.local/bin`, updates `~/.zshrc`, and writes config to `~/.armory/config.json`.

## Crystal Saga Workflow (Manual + Agent-First)

Manual flow:

```bash
crystal remedy --check config --check scripts
crystal chronicle --repo-path . --format table
crystal alexander
```

Agent-first flow:

```bash
crystal quartermaster scout --task "what are we stuck on in this repo"
crystal quartermaster plan --task "prepare the best loadout"
crystal quartermaster equip --from-last-plan --approve
crystal quartermaster report --from-last-plan
```

## Ask Your Agent

Prompt examples:

1. `Scout Armory for this issue, shortlist top 3, and explain tradeoffs.`
2. `Build a plan, wait for approval, then equip and report.`
3. `Refresh Armory first, then return only high-confidence picks.`

## Tool Selection And Equip Examples

- `remedy`: check local runtime health and config integrity.
- `chronicle`: inspect repo state and momentum.
- `alexander`: run preflight gate before high-risk changes.
- `quartermaster`: run scout -> approval -> equip -> report loop.

Example equip run:

```bash
crystal quartermaster plan --task "stabilize release checks"
crystal quartermaster equip --from-last-plan --approve
```

## Mode Controls (`civs`)

```bash
crystal civs status
crystal civs on    # switch to Civilian Mode wording
crystal civs off   # switch back to Crystal Saga wording
```

## Troubleshooting

1. `command not found`: open a new terminal or run `source ~/.zshrc`.
2. Wrong mode tone: run `crystal civs status` and adjust with `on/off`.
3. Armory path discovery failed: run `./setup.sh` once in the Armory root.
4. Quartermaster refresh failed: fix git auth/remote, then retry scout.

## Validation Commands

```bash
python3 scripts/validate_shop_catalog.py
python3 scripts/build_armory_manifest.py --out docs/data/armory-manifest.v1.json
python3 scripts/ci/check_manifest_determinism.py
python3 scripts/ci/validate_readmes.py
bash scripts/ci/mac-smoke.sh
bash scripts/ci/quartermaster-smoke.sh
```

## Contracts And References

- [Agent contract](AGENTS.md)
- [Agent doctrine](agent-doctrine.yml)
- [Quartermaster runtime](items/quartermaster/README.md)
- [Manifest](docs/data/armory-manifest.v1.json)
- [Catalog](shop/catalog.json)

Same System, Two Voices:
Commands and behavior are identical between modes. Language changes, logic does not.
`equip loadout` and `install selected tools` both map to the same runtime flow.
