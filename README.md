# The Armory ⚔️

Battle-tested terminal tools for developers. API key management, system diagnostics, encrypted backups, service monitoring, and more.

Works with any terminal setup. Extra features for [OpenClaw](https://github.com/openclaw/openclaw) and multi-agent AI users, but everything here stands on its own.

---

## 🐉 Summons

Full systems deployed with one command.

| Summon | Flavor | What It Does |
|--------|--------|-------------|
| [**Bahamut**](summons/bahamut/) | *Megaflare* | Full empire deployment — every agent, every config, every channel, restored from one backup |
| [**Ifrit**](summons/ifrit/) | *Hellfire* | Spawn a fully configured AI agent — workspace, personality, memory, config, ready for orders |
| [**Odin**](summons/odin/) | *Zantetsuken* | One-slash system cleanup — zombie processes, stale sessions, bloated logs, all cut |
| [**Ramuh**](summons/ramuh/) | *Judgment Bolt* | Full system diagnostic — network, services, API keys, disk space, all checked in seconds |
| [**Shiva**](summons/shiva/) | *Diamond Dust* | Freeze your system state into a snapshot. Compare snapshots to see what changed |

## ⚔️ Weapons

Standalone tools you wield yourself.

| Weapon | Flavor | What It Does |
|--------|--------|-------------|
| [**Masamune**](weapons/masamune/) | *The One Cut* | Vault and hot-swap AI provider API keys with one command |
| [**Phoenix Down**](weapons/phoenix-down/) | *Rise Again* | Encrypted backup + 3-command restore for your entire setup |
| [**Sentinel**](weapons/sentinel/) | *The Watch* | Service health monitoring with Telegram alerts |
| [**Scan**](weapons/scan/) | *Know Thy Enemy* | Security audit — find leaked secrets across all your repos |
| [**Warp**](weapons/warp/) | *Be There Now* | One-command SSH into any machine — no memorizing IPs or keys |

## 🔮 Spells

Automations that cast themselves on a schedule.

| Spell | Flavor | What It Does |
|-------|--------|-------------|
| [**Libra**](spells/libra/) | *Read the Field* | Daily system report — health, storage, GitHub activity, delivered to Telegram |
| [**Cure**](spells/cure/) | *Trust but Verify* | Weekly check that your backups are actually working |
| [**Protect**](spells/protect/) | *Shield Wall* | Scheduled security scan — catches leaked secrets automatically |
| [**Regen**](spells/regen/) | *New Day* | Morning summary — weather, calendar, agent activity, today's priorities |

## 🧪 Items

Guides and reference docs that save you hours.

| Item | Flavor | What You'll Learn |
|------|--------|-----------------|
| [**Teleport**](items/teleport/) | *Be in Two Places* | Run one agent across two machines — setup, sync, and common pitfalls |
| [**Cron Scheduling**](items/cron-scheduling/) | *Time Magic* | Every scheduling gotcha that'll waste your time (so you don't have to) |
| [**Telegram Setup**](items/telegram-setup/) | *Open Comms* | Chat IDs, channel routing, group config, bot permissions |
| [**NSSM Services**](items/nssm-services/) | *Undying* | Register any process as a Windows service that survives reboots |
| [**Agent Comms**](items/agent-comms/) | *Party Chat* | Set up multiple agents that communicate and coordinate |

---

## How to Use

**Summons:** Run the script. It builds everything for you.

**Weapons:** Copy the script, run it. Each one is self-contained with its own README.

**Spells:** Copy the cron config into your OpenClaw setup. They run themselves after that.

**Items:** Read the guide, follow the steps. Most things are solved in under 5 minutes.

## Custom Command Word

Instead of typing `armory swap`, `armory reload`, etc. — pick a short alias that feels like yours:

```
armory init

  ⚔️  Armory Setup

  Pick a command name. This is the word you'll type
  to run any Armory tool from your terminal.

  Examples: armory, ops, forge, faye, kit

  Command name: faye

  ✓ Alias created.

  You can now run:
    faye swap anthropic work    Swap an API key
    faye reload                 Restart your gateway
    faye list                   Show stored keys
    faye help                   See all commands
```

Don't like your name? Run `armory init` again anytime.

## Contributing

Built something? Open a PR. Keep it practical, keep it tested, keep it documented.

If you don't like the names, you don't gotta use it.

---

*Arm your terminal.*
