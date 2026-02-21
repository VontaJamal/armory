# 🗡️ Weapon #1: jutsu

**Vault and hot-swap AI provider API keys with one command.**

No more editing config files. No more copy-pasting keys. Register once, swap forever.

## The Problem

You've got multiple API keys across multiple providers — Anthropic, OpenAI, Google, Together. Every time you want to switch, you're digging through config files, updating environment variables, restarting services. It's tedious and error-prone.

## The Solution

```
armory jutsu add anthropic personal sk-ant-xxxxx
armory jutsu add anthropic work sk-ant-yyyyy
armory jutsu add openai main sk-proj-xxxxx
```

Register your keys once. They're vaulted in `~/.openclaw/secrets/jutsu-vault.json`.

From that point on:

```
armory jutsu anthropic work
```

One command. Key is set, environment variable updated, `openclaw.json` provider config swapped. Done.

## Commands

| Command | What It Does |
|---------|-------------|
| `armory jutsu add <provider> <name> <key>` | Register a named key |
| `armory jutsu <provider> <name>` | Swap to a named key |
| `armory jutsu <provider>` | Swap (auto-picks if only one key) |
| `armory jutsu list` | Show all registered keys (masked) |
| `armory jutsu remove <provider> <name>` | Remove a key from the vault |

## Supported Providers

| Provider | Env Variable | Default Model |
|----------|-------------|---------------|
| `anthropic` | `ANTHROPIC_API_KEY` | claude-opus-4-6 |
| `openai` | `OPENAI_API_KEY` | gpt-4o |
| `google` | `GOOGLE_API_KEY` | gemini-2.0-flash |
| `k2` | `TOGETHER_API_KEY` | k2-chat |

## What It Looks Like

```
> armory jutsu list

  Jutsu Scroll

  anthropic
    personal         sk-ant.....3kF  <- active
    work             sk-ant.....9mR

  openai
    main             sk-pro.....2bN
```

```
> armory jutsu anthropic work

  Jutsu activated. Chakra nature: anthropic (work)
  Model: anthropic/claude-opus-4-6
  Restart gateway to take effect.
```

## Installation

1. Copy `jutsu.ps1` to your scripts directory (or anywhere in your PATH)
2. Create a `.cmd` wrapper to call it:

```cmd
@echo off
powershell -ExecutionPolicy Bypass -File "C:\path\to\jutsu.ps1" %*
```

3. Run `armory jutsu add` to register your first key

## Customization

During `armory init`, you can set your own command word. The script adapts — `faye jutsu`, `shadow jutsu`, `sage jutsu` — whatever fits your setup.

## Security

- Keys are stored locally in `~/.openclaw/secrets/jutsu-vault.json`
- Keys are masked in all display output
- After the initial `add`, keys never appear in terminal history again
- The vault file should be excluded from version control (add to `.gitignore`)

---

*Part of [The Armory](https://github.com/VontaJamal/armory) — weapons for your terminal.*
