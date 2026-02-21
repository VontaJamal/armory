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

# Override 7-Zip and password file paths
powershell -ExecutionPolicy Bypass -File .\spells\cure\cure.ps1 -SevenZipPath "C:\Program Files\7-Zip\7z.exe" -PasswordFile "$env:USERPROFILE\.openclaw\secrets\backup-password.txt"
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Dir <path>` | `%USERPROFILE%\.openclaw\backups` | Backup directory override |
| `-Telegram` | off | Send alert when backup is stale/corrupt |
| `-MaxAgeHours <n>` | `24` | Staleness threshold |
| `-SevenZipPath <path>` | `C:\Program Files\7-Zip\7z.exe` | 7-Zip executable override |
| `-PasswordFile <path>` | `%USERPROFILE%\.openclaw\secrets\backup-password.txt` | Password file override for encrypted archive tests |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Top config block contains Telegram defaults plus effective 7-Zip and password file paths.

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
