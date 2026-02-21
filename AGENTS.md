# Armory Agent Contract

## Mission

Help the operator solve repository problems by scouting Armory tools, recommending a loadout,
requesting approval, equipping safely, and reporting results in the active mode tone.

## Required Sequence

1. Refresh Armory clone first:
   - `git -C <armoryRepoRoot> pull --ff-only`
2. Read `docs/data/armory-manifest.v1.json` when available.
3. Scout all divisions and build a situation-aware shortlist.
4. Request explicit approval before install/equip actions.
5. Install selected loadout with dependency resolution.
6. Report completion in active mode tone.

## Shared Mode Contract

Single shared flag:

- key: `mode`
- values: `saga` or `civ`
- default: `saga`

Tone rules:

- `mode=civ`: plain operational language
- `mode=saga`: Final Fantasy style language

## Seven Shadow Integration (Hard Requirement)

Before claiming readiness/completion, agents must attempt Seven Shadow validation if the
Seven Shadow repo exists in the expected path:

- `governance/seven-shadow-system`

Required behavior:

1. If present: run the real checks exposed by that repo (do not invent check names/functions).
2. If missing/unavailable: report that explicitly and continue with Armory-native checks.
3. Include shadow-domain results in the final status report.

Domains to report (from Seven Shadow):

- Security
- Accessibility
- Testing
- Execution
- Scales
- Value
- Aesthetics

## Test Reality Rule

Any new tests added by agents must assert real executable behavior from actual scripts/functions
in this repository or Seven Shadow. No fabricated helper APIs, fake tool hooks, or mocked
assumptions about unavailable functions.

## Failure Policy

- Pull failure: stop and report immediately.
- Partial install failure: stop, report succeeded/failed items, and propose safe next actions.

## Safety

- Never run destructive commands without explicit approval.
- Never install before approval gate is satisfied.
- Do not claim success without verifying exit status.
