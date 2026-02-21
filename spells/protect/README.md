# Protect (Scheduled Security Scan)

## What This Does

Runs security scan logic on a schedule-friendly path with quiet output and clear exit codes.

## Who This Is For

- You need automated secret scanning.
- You want cron/task integration with alerting when findings appear.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\spells\protect\protect.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\spells\protect\protect.ps1 -Verbose
```

## Common Tasks

```powershell
# Scan specific directories
powershell -ExecutionPolicy Bypass -File .\spells\protect\protect.ps1 -Dirs "D:\Code Repos,D:\Infra"

# Alert via Telegram
powershell -ExecutionPolicy Bypass -File .\spells\protect\protect.ps1 -Telegram
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Dirs <a,b,c>` | configured defaults | Directories to scan |
| `-Telegram` | off | Send findings summary to Telegram |
| `-Verbose` | off | Print output even when no findings |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Top config block contains scan dirs, ignore patterns, and Telegram defaults.

## Output And Exit Codes

- `0`: clean scan.
- `1`: findings detected or fatal failure.

## Troubleshooting

- Too many false positives: tune ignore patterns.
- Scan too slow: narrow configured directories.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\spells\protect\protect.ps1 -Dirs "D:\Code Repos"
```

## FAQ

**How is this different from Scan?**
Scan is manual and quick. Protect is automation-focused and quiet by default.

## Migration Notes

No rename for this tool.
