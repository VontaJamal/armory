# ðŸ›¡ï¸ healthcheck

**Automated service health monitoring with Telegram alerts.**

healthcheck watches your services so you don't have to. If something goes down, you know immediately.

## What It Does

- Checks Windows services (NSSM or native) via `sc query`
- Sends Telegram alerts when a service is stopped or missing
- Runs on a schedule (cron job, Task Scheduler, or OpenClaw cron)
- Reports all-clear or lists exactly what's down

## Usage

```powershell
# Check services and alert if anything is down
.\healthcheck.ps1
```

## Configuration

Edit the script to set your services and Telegram details:

```powershell
$services = @("CryptoPipeline", "OpenClawGateway", "YourService")
$telegramToken = "your-bot-token"
$chatId = "your-chat-id"
```

## Recommended Schedule

Run every 15-30 minutes via OpenClaw cron:

```json
{
  "name": "healthcheck Health Check",
  "enabled": true,
  "schedule": { "cron": "*/30 * * * *" },
  "payload": {
    "kind": "agentTurn",
    "message": "Run service health check"
  }
}
```

## Requirements

- Windows with services registered (NSSM or native)
- Telegram bot token + chat ID for alerts

---

*Always watching. â€” Part of [The Armory](https://github.com/VontaJamal/armory)*

