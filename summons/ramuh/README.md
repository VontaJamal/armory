# Ramuh (System Diagnostic)

## What This Does

Runs diagnostic checks for network, services, API key presence, disk health, and listening ports.

## Who This Is For

- You need a one-command health report.
- You are debugging service or connectivity issues.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\summons\ramuh\ramuh.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\summons\ramuh\ramuh.ps1
```

## Common Tasks

```powershell
# Service checks only
powershell -ExecutionPolicy Bypass -File .\summons\ramuh\ramuh.ps1 -Services

# API key visibility checks only
powershell -ExecutionPolicy Bypass -File .\summons\ramuh\ramuh.ps1 -Keys
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Network` | off | Network and SSH checks |
| `-Services` | off | Service checks |
| `-Keys` | off | API key checks |
| `-Disk` | off | Disk checks |
| `-All` | off | Run all checks |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Built-in config section controls services, key names, and threshold values.

## Output And Exit Codes

- `0`: Checks completed (may still contain warnings in output).
- `1`: Fatal script failure.

## Troubleshooting

- Missing commands (for example, `nssm`): install dependency or ignore optional checks.
- Network failures: validate target hosts and firewall rules.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\summons\ramuh\ramuh.ps1 -All
```

## FAQ

**Does this restart services?**
No. This tool is diagnostic only.

## Migration Notes

No rename for this tool.
