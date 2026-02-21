# Ifrit (Agent Bootstrap)

## What This Does

Creates a new agent workspace, writes starter identity files, and registers the agent in `openclaw.json`.

## Who This Is For

- You need to add a specialist agent quickly.
- You want a standard workspace and memory layout.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\summons\ifrit\ifrit.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\summons\ifrit\ifrit.ps1 -Name "cipher" -Role "Security analyst"
```

## Common Tasks

```powershell
# Interactive mode
powershell -ExecutionPolicy Bypass -File .\summons\ifrit\ifrit.ps1

# Set model and heartbeat
powershell -ExecutionPolicy Bypass -File .\summons\ifrit\ifrit.ps1 -Name "ops" -Role "Platform ops" -Model "claude-sonnet-4-20250514" -Heartbeat "30m"
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Name <id>` | none | Agent id/name |
| `-Role <text>` | none | Agent role description |
| `-Model <id>` | `claude-sonnet-4-20250514` | Primary model id |
| `-Heartbeat <interval>` | `55m` | Agent heartbeat schedule |
| `-ActiveStart <HH:mm>` | `08:00` | Active window start |
| `-ActiveEnd <HH:mm>` | `23:00` | Active window end |
| `-NoTelegram` | off | Skip Telegram-oriented text/setup hints |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Requires `%USERPROFILE%\.openclaw\openclaw.json` with an `agents.list` section.

## Output And Exit Codes

- `0`: Agent created or already exists.
- `1`: Invalid config, missing required values, or write failure.

## Troubleshooting

- `openclaw.json not found`: install/configure OpenClaw first.
- `Parser error`: pull latest version, this script now avoids apostrophe parser issues.
- `Agent exists`: pick a new `-Name` or update the existing entry manually.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\summons\ifrit\ifrit.ps1 -Name "nightwatch" -Role "Overnight checks" -Heartbeat "20m"
```

## FAQ

**Does this create cron jobs?**
It creates workspace and registration; cron policies are managed separately.

**Can I re-run for an existing agent?**
Yes. Existing registration is detected and skipped.

## Migration Notes

No rename for this tool.
