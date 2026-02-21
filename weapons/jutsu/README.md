# ⚔️ Masamune / Jutsu

***The One Cut***

**Vault and hot-swap AI provider API keys with one command. Restarts your gateway automatically — even on a remote machine.**

Got 3 Anthropic keys and need to rotate? One command swaps the key and bounces the gateway, wherever it lives.

## What It Does

- **Named key vault** — store multiple keys per provider (`anthropic/work`, `anthropic/personal`)
- **One-command swap** — changes the active key and restarts the gateway
- **SSH-aware restart** — gateway on another machine? It SSHs over and restarts it there
- **Setup wizard** — first run asks where your gateway lives, remembers forever

## Works Anywhere

**No OpenClaw required** for key management. The gateway restart feature works with OpenClaw but the vault stands alone.

## Versions

| Platform | File | Status |
|----------|------|--------|
| macOS/Linux (zsh) | `jutsu.sh` | ✅ Alpha |
| Windows (PowerShell) | `jutsu.ps1` | ✅ Stable |

## Usage (zsh — Alpha)

```bash
# First time — tell it where your gateway runs
jutsu setup

# Add keys to the vault
jutsu add anthropic work sk-ant-abc123...
jutsu add anthropic personal sk-ant-xyz789...
jutsu add openai main sk-openai-...

# List stored keys
jutsu list

# Swap key + restart gateway (one command)
jutsu swap anthropic work

# Just restart gateway (no key swap)
jutsu reload

# Remove a key
jutsu remove anthropic old-key
```

## Setup

```bash
# Copy to your path
cp jutsu.sh /usr/local/bin/jutsu
chmod +x /usr/local/bin/jutsu

# Or alias it to your command word
echo 'alias faye="/path/to/jutsu.sh"' >> ~/.zshrc
```

### Gateway Config

On first `jutsu setup`:

```
  Where does your gateway run?
  (If it's this machine, just press Enter)

  Gateway host [local]: 192.168.1.188
  SSH user: devon
  SSH key path (optional): ~/.ssh/id_ed25519

  ✓ Gateway set to devon@192.168.1.188 via SSH
```

Config saved to `~/.jutsu/config`. Edit anytime or re-run setup.

## How It Works

1. Keys stored in `~/.jutsu/vault.json` (base64-encoded, chmod 600)
2. `swap` decodes the key → exports to env var → restarts gateway
3. Gateway restart checks config: local = `openclaw gateway restart`, remote = SSH + restart
4. Provider → env var mapping: `anthropic` → `ANTHROPIC_API_KEY`, `openai` → `OPENAI_API_KEY`, etc.

## Pairs With

- **Ramuh** (Summon) — After swapping, run Ramuh to verify the new key works
- **Sentinel** (Weapon) — Sentinel will catch if a key swap breaks something

## Requirements

- zsh (macOS default) or bash
- python3 (for JSON vault operations)
- SSH client (for remote gateway restart)
- OpenClaw (optional, for gateway restart)

---

*"One cut. Clean." — Part of [The Armory](https://github.com/VontaJamal/armory)*
