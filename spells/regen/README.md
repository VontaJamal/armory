# ðŸ’« Regen

**Morning briefing delivered to your phone before you're out of bed.**

Regen starts your day with everything you need to know â€” weather, calendar, what your agents did overnight, open threads, and what's on deck today.

## What It Delivers

- **Weather** for your location
- **Calendar** â€” what's happening today and tomorrow
- **Agent activity** â€” what your agents did while you slept
- **Open threads** â€” unfinished tasks, pending items
- **Today's focus** â€” top priorities based on your current projects

## Setup (OpenClaw Cron)

```json
{
  "name": "Regen â€” Morning Briefing",
  "enabled": true,
  "schedule": { "cron": "0 7 * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Morning briefing. Check weather, today's calendar events, any overnight agent activity, and open tasks. Deliver a concise summary of what I need to know to start my day.",
    "deliver": true,
    "channel": "telegram",
    "to": "channel:YOUR_CHANNEL_ID"
  }
}
```

## Customization

Add or remove sections by editing the message prompt. Some ideas:
- Stock market pre-market movers
- News headlines in your industry
- Unread email count
- GitHub notifications

## Schedule

- `0 7 * * 1-5` â€” Weekday mornings only
- `0 7 * * *` â€” Every morning
- `0 8 * * 6,0` â€” Later on weekends (you deserve it)

## Tips

- Route to your DM, not a group channel â€” this is personal
- Use a mid-tier model (Sonnet/Haiku) to save costs on daily runs
- Keep the prompt focused â€” too many sections and you'll stop reading it

---

*Start every day informed. â€” Part of [The Armory](https://github.com/VontaJamal/armory)*

