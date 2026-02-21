# Cure (Backup Verification)

## What This Does

Checks whether backups are recent, non-empty, and restorable.

## Who This Is For

- You need confidence that backups are usable.
- You want scheduler-friendly health checks with strict exit codes.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\spells\cure\cure.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\spells\cure\cure.ps1
```

## Common Tasks

```powershell
# Check custom backup directory
powershell -ExecutionPolicy Bypass -File .\spells\cure\cure.ps1 -Dir "D:\Backups"

# Alert via Telegram when stale/corrupt
powershell -ExecutionPolicy Bypass -File .\spells\cure\cure.ps1 -Telegram
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Dir <path>` | `%USERPROFILE%\.openclaw\backups` | Backup directory override |
| `-Telegram` | off | Send alert when backup is stale/corrupt |
| `-MaxAgeHours <n>` | `24` | Staleness threshold |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Top config block contains Telegram defaults and expected backup pattern.

## Output And Exit Codes

- `0`: backup healthy.
- `1`: missing/stale/corrupt backup or fatal runtime failure.

## Troubleshooting

- No backups found: verify path and backup file naming.
- Integrity test fails: recreate backup and retest.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\spells\cure\cure.ps1 -Dir "D:\Backups"
```

## FAQ

**Does Cure create backups?**
No. Phoenix Down creates backups; Cure verifies them.

## Migration Notes

No rename for this tool.
