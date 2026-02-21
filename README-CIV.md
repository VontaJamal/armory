# README-CIV

## What Armory Is

Armory is a Mac-first command and automation repository for practical repo operations. Civilian Mode uses plain language while keeping the same behavior and command surface as Crystal Saga Mode.

## 5-Minute Setup

```bash
./setup.sh --mode civ --command-word armory
```

This installs your command shim into `~/.local/bin`, updates `~/.zshrc`, and writes config to `~/.armory/config.json`.

## Civilian Workflow (Manual + Agent-First)

Manual flow:

```bash
armory remedy --check config --check scripts
armory chronicle --repo-path . --format table
armory alexander
```

Agent-first flow:

```bash
armory quartermaster scout --task "what are we blocked on"
armory quartermaster plan --task "build the best install plan"
armory quartermaster equip --from-last-plan --approve
armory quartermaster report --from-last-plan
```

## Ask Your Agent

Prompt examples:

1. `Check Armory for tools that match this task and report top options.`
2. `Build a plan, wait for my approval, then install and report.`
3. `Refresh Armory first, then give me a concise recommendation.`

## Tool Selection And Install Examples

- `remedy`: validate local runtime and config.
- `chronicle`: inspect repository state.
- `alexander`: run release preflight checks.
- `quartermaster`: automate scout -> approval -> install -> report.

Example install run:

```bash
armory quartermaster plan --task "stabilize release checks"
armory quartermaster equip --from-last-plan --approve
```

## Mode Controls (`civs`)

```bash
armory civs status
armory civs on    # plain-language reporting
armory civs off   # crystal-saga flavored reporting
```

## Troubleshooting

1. `command not found`: open a new terminal or run `source ~/.zshrc`.
2. Wrong report tone: run `armory civs status` and switch with `on/off`.
3. Armory path discovery failed: run `./setup.sh` in Armory root once.
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
Commands and behavior are identical between modes. Wording changes, implementation does not.
`equip loadout` and `install selected tools` point to the same runtime actions.
