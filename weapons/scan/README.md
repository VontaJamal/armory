# 👁️ Scan

**Security audit for your repos and secrets.**

Cast Scan on your codebase and see everything exposed — leaked API keys, tracked `.env` files, secrets in git history.

## What It Checks

- All local git repos for tracked secrets (API keys, tokens, passwords)
- `.env` files — are they gitignored or accidentally committed?
- Public vs private repo classification
- Environment variable exposure
- Common secret patterns (AWS, Anthropic, OpenAI, Stripe, etc.)

## Usage

```powershell
# Scan all repos in a directory
.\scan.ps1 -RepoPath "D:\Code Repos"

# Deep scan — checks git history too
.\deep-scan.ps1 -RepoPath "D:\Code Repos"
```

## Output

```
SECRETS SCAN REPORT
═══════════════════
Public repos:  16 — CLEAN
Private repos:  3 — .env present but NOT tracked
Local only:     4 — not on GitHub

Leaked secrets: 0
Exposed .env:   0

Status: ALL CLEAR
```

## What It Catches

- API keys in source code (Anthropic, OpenAI, Google, AWS, Stripe, Twilio)
- Bot tokens (Telegram, Discord, Slack)
- Database connection strings
- Private keys and certificates
- `.env` files committed to git

## Requirements

- PowerShell 5.1+
- Git installed

---

*"Reveals enemy weaknesses." — Part of [The Armory](https://github.com/VontaJamal/armory)*
