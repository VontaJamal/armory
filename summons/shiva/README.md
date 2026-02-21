# Shiva (Snapshot And Diff)

## What This Does

Captures a machine state snapshot and compares snapshots to show what changed over time.

## Who This Is For

- You need before/after visibility during incident response.
- You want quick diffs for services, ports, and resource changes.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\summons\shiva\shiva.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\summons\shiva\shiva.ps1
powershell -ExecutionPolicy Bypass -File .\summons\shiva\shiva.ps1 --diff
```

## Common Tasks

```powershell
# List snapshots
powershell -ExecutionPolicy Bypass -File .\summons\shiva\shiva.ps1 --list

# Diff specific files
powershell -ExecutionPolicy Bypass -File .\summons\shiva\shiva.ps1 --diff "C:\Users\you\.shiva\snapshots\a.json" "C:\Users\you\.shiva\snapshots\b.json"
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `--list` | off | List saved snapshots |
| `--diff [a b]` | off | Compare last two snapshots or provided files |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Snapshots are stored under `%USERPROFILE%\.shiva\snapshots`.

## Output And Exit Codes

- `0`: Snapshot/diff completed.
- `1`: Invalid diff request or fatal failure.

## Troubleshooting

- Need at least two snapshots for diff mode.
- If JSON parse fails, delete corrupted snapshot and create a new one.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\summons\shiva\shiva.ps1
```

## FAQ

**Does this modify services?**
No. Shiva is read-only state capture and comparison.

## Migration Notes

No rename for this tool.
