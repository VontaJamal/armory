# Libra (Daily Operations Report)

## What This Does

Builds a daily operations intelligence report: disk, services, memory-heavy processes, uptime, updates, git working tree health, and key presence checks.

Libra is operations-focused. It does not run secret scanning.

## Who This Is For

- You want a daily infrastructure pulse.
- You need a short operations report for morning or evening review.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\spells\libra\libra.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\spells\libra\libra.ps1
```

## Common Tasks

```powershell
# Save report to file
powershell -ExecutionPolicy Bypass -File .\spells\libra\libra.ps1 -Output "C:\Reports\libra.txt"

# Send report to Telegram
powershell -ExecutionPolicy Bypass -File .\spells\libra\libra.ps1 -Telegram

# Skip repo pulse when you only need host/service summary
powershell -ExecutionPolicy Bypass -File .\spells\libra\libra.ps1 -NoRepoSummary
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Output <path>` | none | Write report to file instead of stdout |
| `-Telegram` | off | Send report to configured Telegram chat |
| `-NoRepoSummary` | off | Skip the Chronicle-derived repo pulse section |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Top config block controls:

- Telegram token/chat id
- repos allowlist file (`~/.armory/repos.json`) for repo pulse
- API key variable names to check

## Output And Exit Codes

- `0`: report generated.
- `1`: fatal collection or output failure.

## Troubleshooting

- Missing update count on older systems: script reports unavailable status.
- Telegram send failed: verify token/chat id.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\spells\libra\libra.ps1 -Output "C:\Reports\daily-libra.txt"
```

## FAQ

**Why no security findings here?**
Security scanning belongs to Scan/Truesight/Protect to keep roles clear.

## Migration Notes

Libra scope is now strictly operations intelligence.
