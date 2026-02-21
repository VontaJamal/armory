# 🛡️ Protect

**Scheduled security audit that runs automatically.**

Protect casts Scan on a schedule — checking your repos for leaked secrets, exposed environment files, and security drift. You don't have to remember to audit. It remembers for you.

## What It Does

- Runs the Scan weapon automatically on a schedule
- Checks all repos for accidentally committed secrets
- Verifies `.env` files aren't tracked in public repos
- Alerts you immediately if anything is exposed

## Setup (OpenClaw Cron)

```json
{
  "name": "Protect — Security Audit",
  "enabled": true,
  "schedule": { "cron": "0 7 * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Run a security audit. Scan all git repos for leaked secrets (API keys, tokens, passwords). Check if any .env files are tracked in public repos. Check for exposed credentials in recent commits. Report findings.",
    "deliver": true,
    "channel": "telegram",
    "to": "channel:YOUR_CHANNEL_ID"
  }
}
```

## Schedule

- `0 7 * * *` — Daily at 7 AM (catch overnight mistakes)
- `0 7 * * 1` — Weekly Monday (lighter touch)

## Pairs With

**Scan** (Weapon) — Scan is the manual audit. Protect is the automated version.

## Why Both?

Scan is for when you want to check RIGHT NOW. Protect is the safety net that catches what you forgot. Belt and suspenders. You want both.

---

*"Reduces incoming damage." — Part of [The Armory](https://github.com/VontaJamal/armory)*
