# 🐉 Bahamut

***Megaflare***

**Full empire deployment. One command. Everything stands up.**

New machine? Fresh install? Disaster recovery? Summon Bahamut. Your entire multi-agent setup — every agent, every workspace, every config, every channel, every cron job — deployed from a single script.

Ifrit summons one agent. Bahamut summons the kingdom.

## What It Deploys

- **OpenClaw configuration** — full `openclaw.json` with all providers, models, and settings
- **All agents** — each with their own workspace, SOUL.md, AGENTS.md, MEMORY.md, IDENTITY.md
- **Agent-to-agent communication** — session keys, allow lists, relay protocols
- **Telegram channels** — bot config, group routing, DM policies
- **Cron jobs** — every scheduled automation restored
- **Gateway service** — registered as NSSM service (Windows) or LaunchAgent (Mac)
- **Sync scripts** — workspace sync between machines configured and running
- **Secrets** — API keys restored from encrypted vault (requires your Phoenix Down backup)
- **Custom CLI** — your command word and all weapons available from any terminal

## Usage

```powershell
# Full deployment from backup
.\bahamut.ps1 -BackupPath "C:\path\to\phoenix-down-backup.7z" -Password "your-encryption-password"

# Interactive mode
.\bahamut.ps1

  Summoning Bahamut...

  Backup archive: C:\backups\openclaw-2026-02-20.7z
  Encryption password: ********

  [1/8] Extracting archive...           done
  [2/8] Restoring openclaw.json...      done
  [3/8] Restoring secrets vault...      done
  [4/8] Deploying agent workspaces...   4 agents restored
  [5/8] Registering gateway service...  done
  [6/8] Configuring Telegram...         done
  [7/8] Restoring cron jobs...          7 jobs registered
  [8/8] Setting up sync scripts...      done

  🐉 Megaflare.

  Agents:    Faye, Cipher, Poly, Kai
  Gateway:   RUNNING (port 18789)
  Telegram:  connected
  Cron jobs: 7 active
  Sync:      Mac → Windows (60s interval)

  Your empire is restored. Restart the gateway to go live.
```

## Prerequisites

- A **Phoenix Down** backup archive (encrypted .7z)
- 7-Zip installed (`choco install 7zip` on Windows)
- Node.js and OpenClaw installed
- Telegram bot token (stored in your encrypted backup)

## How It Works

Bahamut is built on top of the other summons and weapons:
1. Uses **Phoenix Down** to decrypt and extract your full backup
2. Calls **Ifrit** for each agent that needs to be restored
3. Runs **Sentinel** to verify all services are healthy after deployment
4. Casts **Protect** to run an immediate security audit on the fresh deploy

The summons chain together. That's the power of the Armory.

## When to Summon Bahamut

- New machine or fresh OS install
- Migrating to a new server
- Disaster recovery after a crash
- Setting up a second deployment (home + office, etc.)
- Onboarding someone else to your exact setup

## Pairs With

- **Phoenix Down** (Weapon) — creates the backup that Bahamut restores from
- **Ifrit** (Summon) — Bahamut calls Ifrit internally for each agent
- **Sentinel** (Weapon) — post-deploy health verification
- **Protect** (Spell) — post-deploy security audit

---

*"The king of summons. The dragon god. When Bahamut answers, everything changes."*

*Part of [The Armory](https://github.com/VontaJamal/armory)*
