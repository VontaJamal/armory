# Regen (Morning Briefing)

## What This Does

Builds a concise morning briefing with weather and key daily system status.

## Who This Is For

- You want a short start-of-day report.
- You prefer one script that summarizes key context.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\spells\regen\regen.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\spells\regen\regen.ps1
```

## Common Tasks

```powershell
# Override weather city
powershell -ExecutionPolicy Bypass -File .\spells\regen\regen.ps1 -City "Dallas"

# Send briefing to Telegram
powershell -ExecutionPolicy Bypass -File .\spells\regen\regen.ps1 -Telegram
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-City <name>` | configured default city | Weather location override |
| `-Telegram` | off | Send summary to Telegram |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Top config block includes city, Telegram settings, git repo dirs, and optional calendar credential path.

## Output And Exit Codes

- `0`: summary generated.
- `1`: fatal runtime failure.

## Troubleshooting

- Weather unavailable: check internet connectivity or wttr.in availability.
- Calendar skipped: ensure optional credentials are configured.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\spells\regen\regen.ps1 -City "Austin" -Telegram
```

## FAQ

**Is Regen a security scan?**
No. Security scanning belongs to Scan/Truesight/Protect.

## Migration Notes

No rename for this tool.
