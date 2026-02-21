# Bahamut (Full Environment Restore)

## What This Does

Restores an OpenClaw-style environment from an encrypted backup archive, including workspace folders, config, and related setup artifacts.

## Who This Is For

- You are moving to a new machine.
- You need disaster recovery after a crash.
- You want to recover quickly from a known-good backup.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\summons\bahamut\bahamut.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\summons\bahamut\bahamut.ps1 -BackupPath "C:\Backups\openclaw-backup-2026-02-20.7z"
```

## Common Tasks

```powershell
# Interactive restore
powershell -ExecutionPolicy Bypass -File .\summons\bahamut\bahamut.ps1

# Non-interactive restore
powershell -ExecutionPolicy Bypass -File .\summons\bahamut\bahamut.ps1 -BackupPath "C:\Backups\latest.7z" -Password "example-password"
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-BackupPath <path>` | none | Path to encrypted backup archive |
| `-Password <text>` | none | Archive password for non-interactive restore |
| `-Sound` | off | Enable start/success/fail sound cues |
| `-NoSound` | off | Explicitly disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

No config file is required. Script uses:

- `C:\Program Files\7-Zip\7z.exe`
- `%USERPROFILE%\.openclaw`

## Output And Exit Codes

- `0`: Restore completed or help printed.
- `1`: Restore failed (archive missing, bad password, dependencies missing, or copy failure).

## Troubleshooting

- `7-Zip required`: install with `choco install 7zip`.
- `Backup not found`: verify `-BackupPath` exists and is accessible.
- `Wrong password`: rerun with correct `-Password` or use interactive mode.

## Automation Examples

```powershell
# Example nightly verification after backup creation
powershell -ExecutionPolicy Bypass -File .\summons\bahamut\bahamut.ps1 -BackupPath "C:\Backups\nightly.7z" -Password "***"
```

## FAQ

**Does this restore every external dependency?**
No. It restores local files and config; external installs (Node, OpenClaw, 7-Zip) must exist.

**Can I run this without OpenClaw installed?**
You can extract files, but service registration and runtime checks may be limited.

## Migration Notes

No rename for this tool.
