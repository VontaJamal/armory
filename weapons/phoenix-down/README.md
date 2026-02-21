# 🔥 Phoenix Down

**Encrypted backup and one-command restore for your entire OpenClaw setup.**

Your system died? Use a Phoenix Down. Three commands and you're back.

## What It Backs Up

- `openclaw.json` (your full config)
- Secrets and credentials
- All agent configs and workspaces
- Scripts, cron jobs, LaunchAgents
- Sync scripts, custom tools
- Everything that makes your setup YOUR setup

## How It Works

```
# First time — set your encryption password
.\setup-rebirth.ps1

# Runs automatically every 2 hours, keeps last 5 backups
# Or run manually:
.\phoenix-down.ps1
```

## Restore (3 Commands)

```powershell
# 1. Decrypt
7z x backup.7z.enc -p"your-password"

# 2. Extract
7z x backup.7z -o"C:\Users\you\.openclaw"

# 3. Run restore
.\RESTORE.ps1
```

That's it. Full setup restored — configs, secrets, agents, everything.

## Security

- AES-256 encryption via 7-Zip
- Password never stored in the script
- Backups rotate automatically (keeps last 5)
- Exclude from version control

## Requirements

- Windows with 7-Zip installed (`choco install 7zip`)
- PowerShell 5.1+

---

*"KO'd? Not anymore." — Part of [The Armory](https://github.com/VontaJamal/armory)*
