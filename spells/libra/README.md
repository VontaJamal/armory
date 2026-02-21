# 📊 Libra

**Automated daily intel report delivered to Telegram.**

Libra scans your system every night and delivers a full status report — storage, services, GitHub activity, and anything that needs attention. You wake up knowing exactly where things stand.

## What It Reports

- **System health** — CPU, memory, disk space, uptime
- **Service status** — all registered services running or not
- **Storage warnings** — flags drives under 15% free
- **GitHub pulse** — recent commits across your active repos
- **Maintenance items** — zombie processes, stale logs, cleanup opportunities

## Setup (OpenClaw Cron)

```json
{
  "name": "Libra — Daily Intel",
  "enabled": true,
  "schedule": { "cron": "0 23 * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Run the daily intel analysis. Check system health (disk space, services, uptime), recent GitHub commits across all active repos, and flag anything that needs attention. Deliver a clean summary.",
    "deliver": true,
    "channel": "telegram",
    "to": "channel:YOUR_CHANNEL_ID"
  }
}
```

## How It Works

This is an **agent-driven spell** — instead of a static script, it tells your OpenClaw agent to analyze and report. The agent uses its tools (exec, web_fetch, etc.) to gather data and writes a human-readable summary.

## Customization

Change the cron schedule to match your timezone and preference:
- `0 23 * * *` — 11 PM daily
- `0 7 * * *` — 7 AM daily (morning briefing style)
- `0 7,23 * * *` — twice daily

## Tips

- Use your strongest model for intel reports — the analysis quality matters
- Route to a dedicated channel so reports don't clutter your main chat
- Add custom checks by editing the message prompt

---

*"Reveals all stats." — Part of [The Armory](https://github.com/VontaJamal/armory)*
