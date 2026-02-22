# 221B

| | |
|---|---|
| **FF Name** | 221B |
| **Flavor Text** | *"When you have eliminated the impossible, whatever remains, however improbable, must be the truth."* |
| **Plain English** | Point it at a project, repo, or service and it deduces what's wrong — stale configs, contradictions, missing files, silent failures. Sherlock Holmes for your codebase. |

## Usage

```powershell
# Analyze current directory
221b

# Analyze a specific project
221b --path D:\Code Repos\armory

# Analyze a running service
221b --service CryptoPipeline

# Analyze a remote machine
221b --ssh devon@192.168.1.188

# Focus on specific deduction categories
221b --focus config        # Config contradictions only
221b --focus health        # Service health only
221b --focus deps          # Dependency issues only
221b --focus git           # Git repo hygiene only

# Output as report
221b --report deductions.md
```

## What It Deduces

### 🔍 Config Deductions
- Env vars that reference files that don't exist
- Config values that contradict each other (e.g., `mode=production` but `debug=true`)
- Secrets in plaintext that should be encrypted
- Stale config referencing removed services or old paths
- Duplicate env vars with different values across `.env` files

### 🏥 Service Health Deductions
- Services that haven't been restarted in 30+ days
- Processes consuming abnormal memory or CPU
- Ports that are LISTENING but nothing is connecting
- Services with stale PID files (ghost processes)
- Log files that stopped writing (silent failures)

### 📦 Dependency Deductions
- `node_modules` older than `package.json` (stale install)
- Lock file conflicts (package-lock.json vs yarn.lock)
- Dependencies with known vulnerabilities (CVE check)
- Unused dependencies still in package.json
- Version mismatches between what's declared and what's installed

### 🌿 Git Deductions
- Branches older than 30 days with no activity
- Uncommitted changes sitting for days
- Remote branches that were deleted but still tracked locally
- Merge conflicts in progress that were forgotten
- `.gitignore` missing common patterns for the project type

### 🔗 Cross-Reference Deductions
- Scripts that reference commands not in PATH
- Import paths pointing to files that were moved or deleted
- README docs referencing features that no longer exist
- Cron jobs pointing to scripts that were removed
- Symlinks pointing to dead targets

## Output

```
╔══════════════════════════════════════════════════╗
║  221B — Deduction Report                        ║
║  Project: D:\Code Repos\armory                  ║
║  Scanned: 2026-02-21 20:45 ET                   ║
╚══════════════════════════════════════════════════╝

🔍 ELEMENTARY — 3 deductions

  1. CONFIG CONTRADICTION
     openclaw.json declares gateway port 18789
     but TOOLS.md references port 8420 for dashboard
     → These are different services, but the docs don't clarify this

  2. STALE BRANCH
     Branch 'sovereign-badge' last commit: 4 days ago
     Main has moved 23 commits ahead
     → This branch is likely abandoned. Delete or merge.

  3. GHOST REFERENCE
     scripts/deploy.ps1 line 14 references 'CryptoBot' service
     No service named 'CryptoBot' exists (did you mean 'CryptoPipeline'?)
     → Renamed service, script not updated

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  3 deductions. 0 critical. 2 worth fixing. 1 informational.
  "The game is afoot."
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Severity Levels

| Level | Meaning | Example |
|-------|---------|---------|
| 🔴 **Critical** | Something is actively broken or dangerous | Secrets in plaintext, dead service with stale PID |
| 🟡 **Worth Fixing** | Not broken but will cause problems | Stale branches, config contradictions |
| 🔵 **Informational** | Observation, not a problem | Long-running service, large log files |

## The Method

221B doesn't guess. It cross-references:
- File system state against config declarations
- Running processes against service definitions
- Git state against workflow expectations
- Documentation against actual code
- Dependencies declared vs installed vs used

Every deduction cites its evidence. No hunches. Just facts that lead to conclusions.

## Requirements

- **Windows**: PowerShell 5.1+
- **Optional**: `git` in PATH (for git deductions), SSH access (for remote analysis)
- **No external dependencies** — uses only built-in PowerShell + standard CLI tools

## Install

```powershell
# Add to PATH or call directly
.\221b.ps1

# Or through Faye CLI
faye 221b
```

---

*"The world is full of obvious things which nobody by any chance ever observes." — Sherlock Holmes*

*Part of [The Armory](https://github.com/VontaJamal/armory) — weapons for developers who ship.*

🏴‍☠️ [Sovereign](https://github.com/VontaJamal) — The Shadow Dominion.
