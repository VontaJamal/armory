# ❄️ Shiva

***Diamond Dust***

**Freeze your entire system state into a snapshot. Compare snapshots to see exactly what changed.**

Shiva captures everything about your system at this exact moment — services, disk space, git repos, running processes, open ports, environment variables. Save it. Come back later. Compare. Know exactly what changed and when.

## Works Anywhere

**No OpenClaw required.** Shiva snapshots any Windows machine. Use it before deployments, after changes, or just to have a record of what your system looks like right now.

## Usage

```powershell
# Take a snapshot
.\shiva.ps1

# Take a named snapshot
.\shiva.ps1 -Name "before-deploy"

# Compare two snapshots
.\shiva.ps1 -Diff "before-deploy"

# List all snapshots
.\shiva.ps1 -List
```

## What It Captures

- **Services** — every registered service and its state
- **Processes** — what's running right now (top 20 by memory)
- **Disk Space** — free/total on every drive
- **Ports** — all listening ports and which process owns them
- **Git Repos** — status of every repo (clean, dirty, branch, ahead/behind)
- **Environment Variables** — all user-level env vars (values masked)
- **Installed Software** — key tools and their versions (Node, Python, Git, 7-Zip, etc.)
- **Uptime** — how long since last reboot

## Output

```
  ❄️ Diamond Dust

  Snapshot: 2026-02-20_23-55-00

  SERVICES         4 running, 1 stopped
  PROCESSES        47 active, top: chrome (1.2 GB), node (340 MB)
  DISK             C: 11.3 GB (5.5%) | D: 89.2 GB (42%)
  PORTS            8 listening (18789, 8420, 3000...)
  GIT REPOS        8 clean, 2 dirty (armory +3, SyncLink +1)
  ENV VARS         12 user variables set
  TOOLS            node v24.13, python 3.11, git 2.44
  UPTIME           4 days 7 hours

  Saved to: ~/.armory/snapshots/2026-02-20_23-55-00.json
```

## Comparing Snapshots

```powershell
.\shiva.ps1 -Diff "before-deploy"
```

```
  ❄️ Diamond Dust — Diff

  Comparing: before-deploy → now

  SERVICES
    + TradingDashboard    STOPPED → RUNNING
  
  DISK
    C: 14.1 GB → 11.3 GB  (-2.8 GB)
  
  GIT REPOS
    armory               clean → dirty (+3 files)
    SyncLink             dirty → clean (pushed)
  
  ENV VARS
    + GITHUB_TOKEN        (added)
    ~ ANTHROPIC_API_KEY   (changed)
  
  PROCESSES
    + ollama.exe          (new, 2.1 GB)

  5 changes detected.
```

## Snapshot Storage

Snapshots are saved as JSON files in `~/.armory/snapshots/`. They're small (usually under 50KB) and stack up without taking meaningful disk space.

```
~/.armory/snapshots/
  2026-02-20_23-55-00.json
  before-deploy.json
  after-cleanup.json
```

## Use Cases

- **Before/after deployments** — snapshot before you change anything, compare after
- **Debugging** — "it was working yesterday" — compare today's snapshot to yesterday's
- **Auditing** — monthly system state records
- **Migration** — snapshot old machine, set up new machine, compare to make sure nothing's missing
- **Peace of mind** — you always know what your system looks like

## Pairs With

- **Ramuh** (Summon) — Ramuh diagnoses problems NOW. Shiva records state for LATER.
- **Odin** (Summon) — Snapshot before cleanup, snapshot after. See what Odin cut.
- **Bahamut** (Summon) — Snapshot the old machine before migrating. Compare after Bahamut deploys.

## Requirements

- PowerShell 5.1+
- Git (for repo status checks)
- No admin rights needed

---

*"Frozen in time." — Part of [The Armory](https://github.com/VontaJamal/armory)*
