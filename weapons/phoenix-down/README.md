# Phoenix Down (Encrypted Backups)

## What This Does

Creates encrypted backup archives and provides companion setup for restore workflows.

## Who This Is For

- You want reliable encrypted local backups.
- You need quick recovery with predictable scripts.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\weapons\phoenix-down\phoenix-down.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\weapons\phoenix-down\phoenix-down.ps1
powershell -ExecutionPolicy Bypass -File .\weapons\phoenix-down\phoenix-down.ps1 -List
```

## Common Tasks

```powershell
# Verify latest backup integrity
powershell -ExecutionPolicy Bypass -File .\weapons\phoenix-down\phoenix-down.ps1 -Verify

# Setup restore command and scheduler
powershell -ExecutionPolicy Bypass -File .\weapons\phoenix-down\save-point.ps1 -Name "faye"
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-BackupSource <path>` | `%USERPROFILE%\.openclaw` | Source directory to back up |
| `-BackupDest <path>` | `%USERPROFILE%\.openclaw\backups` | Backup output directory |
| `-PasswordFile <path>` | `%USERPROFILE%\.openclaw\secrets\backup-password.txt` | Password file |
| `-MaxBackups <n>` | `10` | Rotation count |
| `-List` | off | List existing backups |
| `-Verify` | off | Validate latest backup integrity |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

No separate config file required. Uses flags and environment defaults.

## Output And Exit Codes

- `0`: backup/list/verify succeeded.
- `1`: backup, verify, or dependency failure.

## Troubleshooting

- 7-Zip missing: install `choco install 7zip`.
- Password file missing: create file and rerun.
- Verify failed: test with `7z t <file>` and inspect archive source.

## Automation Examples

```powershell
# Daily backup task
powershell -ExecutionPolicy Bypass -File .\weapons\phoenix-down\phoenix-down.ps1 -BackupSource "D:\Work" -BackupDest "D:\Backups"
```

## FAQ

**Can I back up non-OpenClaw folders?**
Yes, use `-BackupSource` and `-BackupDest`.

## Migration Notes

- New bootstrap name: `save-point.ps1`
- Legacy alias retained: `setup-rebirth.ps1` (one release)
