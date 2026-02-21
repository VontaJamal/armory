# Aegis (Service Health Monitor)

## What This Does

Checks service status and optionally sends Telegram alerts when services are unhealthy.

## Who This Is For

- You run local services and want quick health checks.
- You need cron/task-friendly monitoring with clean exit codes.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\weapons\aegis\aegis.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\weapons\aegis\aegis.ps1
```

## Common Tasks

```powershell
# Monitor specific services
powershell -ExecutionPolicy Bypass -File .\weapons\aegis\aegis.ps1 -Services "OpenClawGateway,CryptoPipeline"

# Silent mode for scheduler
powershell -ExecutionPolicy Bypass -File .\weapons\aegis\aegis.ps1 -Silent
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Services <a,b,c>` | configured defaults | Override default service list |
| `-Silent` | off | Minimal output, exit-code oriented |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Top config block includes:

- `services`
- `telegramBotToken`
- `telegramChatId`

If Telegram config is missing, local checks still run.

## Output And Exit Codes

- `0`: all monitored services healthy.
- `1`: one or more services unhealthy or query failed.

## Troubleshooting

- Service not found: verify exact service name in `sc.exe query`.
- No Telegram alerts: validate `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\weapons\aegis\aegis.ps1 -Silent
```

## FAQ

**Does Aegis restart services?**
No. It monitors and alerts only.

## Migration Notes

- New primary name: `aegis.ps1`
- Legacy alias: `..\sentinel\sentinel.ps1` (one release)
