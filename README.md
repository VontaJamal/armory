# The Armory âš”ï¸

Battle-tested tools and guides for [OpenClaw](https://github.com/openclaw/openclaw) and multi-agent AI setups.

Everything here was built solving real problems in production. No theory. No tutorials. Just tools that work.

---

## ðŸ‰ Summons

Full systems deployed with one command.

| Name | What It Does |
|------|-------------|
| [**spawn**](summons/spawn/) | Create a fully configured AI agent â€” workspace, personality, memory, config, ready to go |
| [**cleanup**](summons/cleanup/) | One-command system cleanup â€” zombie processes, stale sessions, bloated logs, temp files |

## âš”ï¸ Weapons

Standalone tools you run yourself.

| Name | What It Does |
|------|-------------|
| [**swap**](weapons/swap/) | Vault and hot-swap AI provider API keys with one command |
| [**backup**](weapons/backup/) | Encrypted backup + 3-command restore for your entire setup |
| [**healthcheck**](weapons/healthcheck/) | Service health monitoring with Telegram alerts |
| [**scan**](weapons/scan/) | Security audit â€” find leaked secrets across all your repos |

## ðŸ”® Spells

Automations that run themselves on a schedule.

| Name | What It Does |
|------|-------------|
| [**intel**](spells/intel/) | Daily system report â€” health, storage, GitHub activity, delivered to Telegram |
| [**verify-backup**](spells/verify-backup/) | Weekly check that your backups are actually working |
| [**auto-audit**](spells/auto-audit/) | Scheduled security scan â€” catches leaked secrets automatically |
| [**briefing**](spells/briefing/) | Morning summary â€” weather, calendar, agent activity, today's priorities |

## ðŸ§ª Items

Guides and reference docs that save you hours.

| Name | What You'll Learn |
|------|-----------------|
| [**multi-machine**](items/multi-machine/) | Run one agent across two machines â€” setup, sync, and common pitfalls |
| [**cron-scheduling**](items/cron-scheduling/) | Every scheduling gotcha that'll waste your time (so you don't have to) |
| [**telegram-setup**](items/telegram-setup/) | Chat IDs, channel routing, group config, bot permissions |
| [**nssm-services**](items/nssm-services/) | Register any process as a Windows service that survives reboots |
| [**multi-agent**](items/multi-agent/) | Set up multiple agents that communicate and coordinate |

---

## How to Use

**Summons:** Run the script. It builds everything for you.

**Weapons:** Copy the script, run it. Each one is self-contained.

**Spells:** Copy the cron config into your OpenClaw setup. They run themselves after that.

**Items:** Read the guide, follow the steps. Most things are solved in under 5 minutes.

## Custom Command Word

Name your CLI anything you want during setup:

```
armory init

  What's your command word?
  > shadow

  Done. "shadow swap", "shadow scan" are now live.
```

## Contributing

Built something useful? Open a PR. Keep it practical, keep it tested, keep it documented.

---

*Arm your terminal.*

