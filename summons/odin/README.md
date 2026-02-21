# Odin (System Cleanup)

## What This Does

Cleans stale temp files, old logs, stale session artifacts, and optional zombie browser processes.

## Who This Is For

- You need fast storage cleanup.
- You want safe dry-run output before deleting files.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\summons\odin\odin.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\summons\odin\odin.ps1 -DryRun
```

## Common Tasks

```powershell
# Full cleanup
powershell -ExecutionPolicy Bypass -File .\summons\odin\odin.ps1

# Temp-only cleanup
powershell -ExecutionPolicy Bypass -File .\summons\odin\odin.ps1 -Temp
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-DryRun` | off | Show what would be deleted |
| `-Chrome` | off | Only cleanup zombie Chrome processes |
| `-Sessions` | off | Only cleanup stale session files |
| `-Logs` | off | Only cleanup stale logs |
| `-Temp` | off | Only cleanup temp files |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

No external config file required. Uses standard Windows temp paths and `%USERPROFILE%\.openclaw` paths.

## Output And Exit Codes

- `0`: Cleanup run completed.
- `1`: Critical runtime failure.

## Troubleshooting

- Access denied: run terminal as Administrator for protected paths.
- No changes: use `-DryRun` to confirm eligible files exist.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\summons\odin\odin.ps1 -Logs
```

## FAQ

**Is this safe to run often?**
Yes, start with `-DryRun`, then schedule selected scopes.

## Migration Notes

No rename for this tool.
