# BUILD SPEC: Armory Crystal Saga / Civilian Mode

## Summary

Armory uses one shared mode flag across dispatcher behavior, dashboard copy, installer output,
and agent report tone.

- Config key: `mode`
- Allowed values: `saga` or `civ`
- Default: `saga`

When mode is `saga`, Armory uses Final Fantasy-style phrasing.
When mode is `civ`, Armory uses plain operational phrasing.

## Canonical Resolution Order

1. Explicit runtime flag (`--civ` / `--saga`) when supported
2. Shared config (`~/.armory/config.json`)
3. Repo config (`.sovereign.json`)
4. Environment variable (`ARMORY_MODE`, then `SOVEREIGN_MODE`)
5. Default `saga`

## Migration Rules

Armory must normalize old values on read/write:

- `mode=lore` -> `mode=saga`
- `mode=crystal` -> `mode=saga`
- legacy `civilianAliases=true` -> `mode=civ`
- legacy `civilianAliases=false` -> `mode=saga`

After normalization, persist canonical `mode`.

## Agent Workflow Contract

### Required flow

1. Refresh local Armory clone (`git -C <armoryRoot> pull --ff-only`)
2. Scout catalog/manifest and shortlist by task context
3. Request explicit approval
4. Equip approved loadout
5. Report result in active mode tone

### Failure behavior

- If refresh fails: stop and report immediately.
- If install partially fails: stop, report successes/failures, propose safe next actions.

## Report Tone Contract

- `mode=civ`: plain language only
- `mode=saga`: Final Fantasy style is allowed and expected

## Validation Criteria

1. No-config default resolves to `saga`.
2. Legacy values are normalized to `saga|civ`.
3. Dashboard toggle persists mode (`URL > local storage > default`).
4. Agent report tone follows active mode.
5. Installer report tone follows active mode.
6. Approval gate required before install actions.
7. Manifest includes mode metadata and dependency graph.
8. Telemetry payload includes `mode` and supports opt-out.
