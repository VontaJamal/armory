# Remedy (Environment Health Check)

## What This Does

Runs a read-only health check for Armory setup, command wrapper wiring, script presence, CI helper files, remote URL hygiene, and optional dependencies.

## Who This Is For

- Contributors who want a fast local preflight before opening a PR.
- Operators who need to verify Armory setup in one command.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\items\remedy\remedy.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\items\remedy\remedy.ps1
```

## Common Tasks

```powershell
# Full check set
powershell -ExecutionPolicy Bypass -File .\items\remedy\remedy.ps1

# Run only selected checks
powershell -ExecutionPolicy Bypass -File .\items\remedy\remedy.ps1 -Check config,wrapper,scripts

# Include detailed JSON payload
powershell -ExecutionPolicy Bypass -File .\items\remedy\remedy.ps1 -Detailed

# Save a report to disk
powershell -ExecutionPolicy Bypass -File .\items\remedy\remedy.ps1 -Output "$env:USERPROFILE\.armory\reports\remedy.txt"
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Check <name[]>` | all checks | Run only selected checks (`config`, `wrapper`, `scripts`, `repos`, `ci`, `shadow`, `remote`, `deps`) |
| `-Detailed` | off | Adds JSON-like detail payload to output |
| `-Output <path>` | none | Writes report text to a file |
| `-Sound` | off | Enables optional start/success/fail cues |
| `-NoSound` | off | Forces sound cues off |
| `-Help` | off | Prints usage and exits |

## Config

- `~/.armory/config.json` is used for command word, wrapper, and mode (`saga|civ`) checks.
- `~/.armory/repos.json` is used for repos allowlist checks.
- Repo files are resolved relative to the Armory repository root.

## Output And Exit Codes

- `0`: no FAIL checks were found.
- `1`: one or more FAIL checks were found.
- `WARN` checks do not make the command fail.

## Troubleshooting

- `config` fails: run `awakening.ps1` again to regenerate `~/.armory/config.json`.
- `wrapper` fails: verify `%USERPROFILE%\bin\<command-word>.cmd` exists and PATH includes install directory.
- `repos` fails: create/repair `~/.armory/repos.json` with a `repos` array.
- `shadow` warns: `governance/seven-shadow-system` not found in repo root.
- `remote` fails: remove embedded credentials from `git remote -v` URLs.

## Automation Examples

```powershell
# Nightly machine preflight report
powershell -ExecutionPolicy Bypass -File .\items\remedy\remedy.ps1 -Detailed -Output "$env:USERPROFILE\.armory\reports\remedy-nightly.txt"

# CI-adjacent quick check before pushing
powershell -ExecutionPolicy Bypass -File .\items\remedy\remedy.ps1 -Check scripts,ci,remote
```

## FAQ

**Does Remedy modify my repo or config?**
No. Remedy is read-only.

**Can I keep using doctor?**
Yes, as a temporary compatibility alias during migration.

## Migration Notes

- New primary command is `remedy`.
- `doctor.ps1` remains as a deprecated compatibility alias for two releases.
- Dispatcher alias `esuna` remains supported long-term and routes to Remedy.
