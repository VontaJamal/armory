# ❄️ Shiva

***Diamond Dust***

**Freeze your system state into a snapshot. Compare snapshots to see what changed.**

Something broke between yesterday and today? Take snapshots, diff them, find the ghost.

## What It Captures

- **Services** — name, status, start type for all registered services
- **Processes** — running process names and memory usage
- **Ports** — all listening TCP ports and their owning processes
- **Disk** — free space, total space, percent free per drive
- **Environment** — variable names (not values) that are set
- **Network** — active interfaces, IPs, gateway
- **System** — hostname, OS version, uptime, last boot time

## Works Anywhere

**No OpenClaw required.** Shiva works on any Windows machine with PowerShell 5.1+. Pure system introspection.

## Usage

```powershell
# Take a snapshot (saved to ~/.shiva/snapshots/)
.\shiva.ps1

# Compare the last two snapshots
.\shiva.ps1 --diff

# Compare two specific snapshots
.\shiva.ps1 --diff snapshot1.json snapshot2.json

# List all snapshots
.\shiva.ps1 --list
```

## Output

```
  ❄️ Diamond Dust

  Snapshot saved: ~/.shiva/snapshots/2026-02-21_00-30-00.json
  Captured: 47 services, 112 processes, 23 ports, 3 drives
```

### Diff Output

```
  ❄️ Diamond Dust — Diff

  Comparing: 2026-02-20_22-00-00 → 2026-02-21_00-30-00

  SERVICES
    + CryptoPipeline          STOPPED → RUNNING
    - TradingDashboard        RUNNING → STOPPED

  PORTS
    + :8420                   now listening (node.exe)
    - :3000                   no longer listening

  DISK
    C:  12.1 GB → 11.3 GB    (-0.8 GB)

  PROCESSES
    + 3 new: node, python, sshd
    - 2 gone: chrome, explorer
```

## Configuration

No config needed. Shiva reads the system directly.

Snapshots stored at `~/.shiva/snapshots/` — clean them up when you want.

## Pairs With

- **Ramuh** (Summon) — Ramuh checks if things work. Shiva records what things look like.
- **Odin** (Summon) — Diff to find bloat, then Odin cleans it.
- **Sentinel** (Weapon) — Sentinel alerts on change. Shiva shows you the full before/after.

## Requirements

- PowerShell 5.1+
- No admin rights needed (some service details may be limited)

---

*"Time stands still." — Part of [The Armory](https://github.com/VontaJamal/armory)*
