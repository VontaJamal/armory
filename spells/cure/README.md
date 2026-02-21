# 💚 Cure

**Automated weekly backup verification.**

Cure checks that your backups are actually working — not just running, but producing valid, recent archives. Because a backup you never tested is just a prayer.

## What It Checks

- Backup files exist in the expected location
- Most recent backup is less than 48 hours old
- Archive is not empty or corrupted (size check)
- Rotation is working (old backups being cleaned up)

## Setup (OpenClaw Cron)

```json
{
  "name": "Cure — Backup Verification",
  "enabled": true,
  "schedule": { "cron": "0 6 * * 0" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Verify backups are working. Check that backup files exist, the most recent one is less than 48 hours old, file sizes are reasonable (not empty), and old backups are being rotated. Report any issues.",
    "deliver": true,
    "channel": "telegram",
    "to": "channel:YOUR_CHANNEL_ID"
  }
}
```

## Schedule

Runs every Sunday at 6 AM by default. Adjust to your preference:
- `0 6 * * 0` — Sunday 6 AM
- `0 6 * * 1` — Monday 6 AM
- `0 6 * * *` — Daily (if you're paranoid, and you should be)

## Pairs With

**Phoenix Down** (Weapon) — Phoenix Down creates the backups, Cure makes sure they're actually working.

---

*"Restores what was lost." — Part of [The Armory](https://github.com/VontaJamal/armory)*
