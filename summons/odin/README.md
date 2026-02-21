# ⚔️ Odin

**Zantetsuken. One slash. Everything clean.**

Odin sweeps through your system and cuts down everything that shouldn't be there — zombie processes, stale sessions, bloated logs, wasted disk space. One command, system purified.

## What It Cuts

- **Zombie Chrome processes** — headless browsers that never closed
- **Stale OpenClaw sessions** — `.deleted` files, expired completions
- **Bloated logs** — rotates and compresses, deletes anything over 7 days
- **Temp files** — Windows temp, npm cache, orphaned node_modules
- **Disk space report** — shows before/after so you see the damage

## Usage

```powershell
# Full sweep
.\odin.ps1

# Dry run (show what would be cut, don't actually delete)
.\odin.ps1 -DryRun

# Target specific areas
.\odin.ps1 -Chrome      # Kill zombie Chrome only
.\odin.ps1 -Sessions    # Clean stale sessions only
.\odin.ps1 -Logs        # Rotate logs only
.\odin.ps1 -Temp        # Clean temp files only
```

## What It Looks Like

```
  Zantetsuken.

  Chrome zombies:     12 killed
  Stale sessions:     47 purged (39 MB)
  Log rotation:       8 files compressed, 3 deleted
  Temp cleanup:       1.2 GB freed
  
  Before: 8.5 GB free (4.2%)
  After:  19.8 GB free (9.7%)

  Clean cut. 
```

## Schedule It

Pair Odin with a cron job for automatic nightly cleanup:

```json
{
  "name": "Odin — Nightly Cleanup",
  "enabled": true,
  "schedule": { "cron": "0 3 * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Run system cleanup. Kill zombie Chrome processes, purge stale OpenClaw sessions (.deleted files), rotate logs older than 7 days, clean Windows temp files. Report what was cleaned and disk space freed."
  }
}
```

## Safety

- **Dry run by default in interactive mode** — shows what it'll cut before cutting
- **Never touches user files** — only targets known cleanup locations
- **Logs everything** — outputs exactly what was deleted and how much space was freed
- **Skips active processes** — only kills orphans, never your running work

## Requirements

- Windows (PowerShell 5.1+)
- Administrator not required for most operations

---

*"Zantetsuken." — Part of [The Armory](https://github.com/VontaJamal/armory)*
