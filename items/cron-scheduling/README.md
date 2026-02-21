# Cron Scheduling in OpenClaw

Common gotchas and patterns for reliable cron jobs.

## The Basics

```json
{
  "name": "My Job",
  "enabled": true,
  "schedule": { "cron": "0 9 * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Do the thing",
    "deliver": true,
    "channel": "telegram",
    "to": "channel:YOUR_CHANNEL_ID"
  }
}
```

## Gotchas That Will Waste Your Time

### 1. `enabled: true` is required
Jobs created without it are disabled by default and will never fire. Always include it.

### 2. Discord/Telegram targets need a prefix
Use `channel:ID` or `user:ID`, not just the raw ID.

```
âœ… "to": "channel:1467271397540630621"
âŒ "to": "1467271397540630621"
```

### 3. Updating a job may skip same-day runs
If you update a job's schedule, the next run might jump to tomorrow. If you need it to fire today, delete and recreate.

### 4. Gateway crashes nuke cron jobs
After ANY gateway restart, check your cron list and recreate anything missing:
```
openclaw cron list
```

### 5. One-shot `at` jobs can be unreliable
Prefer `cron` type for reliability. Use `at` only for true one-offs.

### 6. Check for hidden disabled jobs
Disabled jobs don't show in normal listings:
```
openclaw cron list --includeDisabled
```

### 7. Keep isolated job payloads simple
Don't tell isolated cron sessions to read files or check context. They start fresh with no workspace awareness. Keep the message self-contained.

## Timezone Tips

- Cron expressions run in the gateway's local timezone
- If your gateway is on a server in UTC but you think in Eastern, offset your hours
- Always verify with a test job before relying on timing

