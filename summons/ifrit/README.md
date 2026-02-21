# 🔥 Ifrit

**Summon a fully configured AI agent in one command.**

Ifrit doesn't just create a file. It builds an entire agent — workspace, personality, memory system, Telegram channel, cron jobs, and registers it in your OpenClaw config. One summon. A new soldier on the field.

## What It Creates

```
~/.openclaw/
  workspace-{name}/
    SOUL.md              ← Agent personality and directives
    AGENTS.md            ← Operating instructions
    MEMORY.md            ← Long-term memory (empty, ready)
    TOOLS.md             ← Agent-specific tool notes
    IDENTITY.md          ← Name, role, archetype
    memory/              ← Daily memory logs directory
  agents/{name}/agent/   ← Auth and agent-specific config
```

## What It Configures

- Registers the agent in `openclaw.json` (agents.list)
- Sets model tier (Sonnet for routine, Opus for heavy analysis)
- Configures heartbeat schedule and active hours
- Enables agent-to-agent communication
- Creates a dedicated Telegram channel (optional)
- Sets up cron jobs for the agent's domain

## Usage

```powershell
.\ifrit.ps1 -Name "cipher" -Role "Crypto intelligence" -Model "claude-sonnet-4-20250514"
```

Or interactive:
```powershell
.\ifrit.ps1

  Agent name: cipher
  Role: Crypto intelligence and pipeline monitoring
  Model [sonnet]: 
  Heartbeat interval [55m]: 30m
  Active hours [08:00-23:00]: 
  Telegram channel? [y/N]: y

  Summoning...

  🔥 Ifrit has answered.
  
  Agent: cipher
  Workspace: ~/.openclaw/workspace-cipher/
  Session key: agent:cipher:main
  Heartbeat: every 30m, 8AM-11PM
  
  Ready for orders.
```

## The SOUL.md Template

Every agent gets a starter soul that you customize:

```markdown
# SOUL.md — Who You Are

## Name: {name}
## Role: {role}

You are a specialist agent in the Shadow Court.
You report to the orchestrator. You execute your domain.

## Core Directives
- Own your domain completely
- Report results, not problems
- Verify before claiming success
- Post start/finish pings to your Telegram channel

## Personality
(Customize this — give your agent a real personality)
```

## After Summoning

1. Edit the SOUL.md to give your agent real personality
2. Add domain-specific files to the workspace
3. Send your first message: `sessions_send(sessionKey="agent:{name}:main", message="You're live. Report status.")`
4. Watch it work

## Architecture

Ifrit follows the hub-and-spoke pattern:
- **Orchestrator** (your main agent) dispatches tasks
- **Specialists** (summoned agents) execute their domain
- Each agent has its own workspace, memory, and identity
- Communication via `sessions_send` with session keys

## Requirements

- OpenClaw installed and configured
- `openclaw.json` with agents section
- Telegram bot (optional, for dedicated channels)

---

*"Hellfire." — Part of [The Armory](https://github.com/VontaJamal/armory)*
