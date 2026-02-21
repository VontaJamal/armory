# ⚡ Ramuh

***Judgment Bolt***

**Full system diagnostic in one command. Every connection, every service, every key — tested in seconds.**

Something feels off but you don't know what? Summon Ramuh. He checks everything and tells you exactly where the problem is.

## What It Checks

- **Network** — ping all configured machines, measure latency
- **SSH** — can you actually connect to your remote machines?
- **Services** — every registered service running or not
- **API Keys** — validates keys against each provider (Anthropic, OpenAI, GitHub, Google)
- **Disk Space** — flags any drive under 15% free
- **Gateway** — is OpenClaw gateway responding? (optional, skipped if not installed)
- **Telegram** — is your bot token valid and responding? (optional)
- **Ports** — checks expected ports are listening
- **Sync** — when did your sync script last run?

## Works Anywhere

**No OpenClaw required.** Ramuh works on any Windows machine with PowerShell. The OpenClaw-specific checks (gateway, Telegram, agents) are optional — Ramuh skips them if they're not configured.

## Usage

```powershell
# Full diagnostic
.\ramuh.ps1

# Check specific areas only
.\ramuh.ps1 -Network        # Network + SSH only
.\ramuh.ps1 -Services       # Services only
.\ramuh.ps1 -Keys           # API key validation only
.\ramuh.ps1 -Disk           # Disk space only
.\ramuh.ps1 -All            # Everything (default)
```

## Output

```
  ⚡ Judgment Bolt

  NETWORK
    192.168.1.188 (local)     ✓  <1ms
    192.168.1.165 (mac)       ✓  3ms

  SSH
    devon@192.168.1.188       ✓  connected
    vonta@192.168.1.165       ✓  connected

  SERVICES
    OpenClawGateway           ✓  RUNNING
    CryptoPipeline            ✓  RUNNING
    CryptoAlertForwarder      ✓  RUNNING
    TradingDashboard          ✗  STOPPED

  API KEYS
    ANTHROPIC_API_KEY         ✓  valid
    GITHUB_TOKEN              ✗  expired or invalid
    OPENAI_API_KEY            -  not set

  DISK
    C:  11.3 GB free (5.5%)   ⚠  low
    D:  89.2 GB free (42%)    ✓  healthy

  GATEWAY
    Port 18789                ✓  listening

  TELEGRAM
    Bot token                 ✓  responding

  ─────────────────────────
  2 issues found:
    ✗ TradingDashboard is STOPPED
    ✗ GITHUB_TOKEN is expired
```

## Configuration

Edit the config section at the top of the script to match your setup:

```powershell
$config = @{
    machines = @(
        @{ name = "local"; host = "192.168.1.188" },
        @{ name = "mac"; host = "192.168.1.165"; sshUser = "vonta" }
    )
    services = @("OpenClawGateway", "CryptoPipeline")
    apiKeys = @("ANTHROPIC_API_KEY", "GITHUB_TOKEN", "OPENAI_API_KEY")
    diskWarningPercent = 15
    gatewayPort = 18789
    telegramBotToken = "$env:TELEGRAM_BOT_TOKEN"  # optional
}
```

## Pairs With

- **Sentinel** (Weapon) — Sentinel monitors continuously. Ramuh is the on-demand deep check.
- **Odin** (Summon) — Run Ramuh to find problems, Odin to clean them up.
- **Scan** (Weapon) — Ramuh checks infrastructure. Scan checks code security.

## Requirements

- PowerShell 5.1+
- SSH client (for remote machine checks)
- No admin rights needed

---

*"The wise elder sees all." — Part of [The Armory](https://github.com/VontaJamal/armory)*
