# âš”ï¸ cleanup

**Clean cut. One slash. Everything clean.**

cleanup sweeps through your system and cuts down everything that shouldn't be there â€” zombie processes, stale sessions, bloated logs, wasted disk space. One command, system purified.

## What It Cuts

- **Zombie Chrome processes** â€” headless browsers that never closed
- **Stale OpenClaw sessions** â€” `.deleted` files, expired completions
- **Bloated logs** â€” rotates and compresses, deletes anything over 7 days
- **Temp files** â€” Windows temp, npm cache, orphaned node_modules
- **Disk space report** â€” shows before/after so you see the damage

## Usage

```powershell
# Full sweep
.\cleanup.ps1

# Dry run (show what would be cut, don't actually delete)
.\cleanup.ps1 -DryRun

# Target specific areas
.\cleanup.ps1 -Chrome      # Kill zombie Chrome only
.\cleanup.ps1 -Sessions    # Clean stale sessions only
.\cleanup.ps1 -Logs        # Rotate logs only
.\cleanup.ps1 -Temp        # Clean temp files only
```

## What It Looks Like

```
  Clean cut.

  Chrome zombies:     12 killed
  Stale sessions:     47 purged (39 MB)
  Log rotation:       8 files compressed, 3 deleted
  Temp cleanup:       1.2 GB freed
  
  Before: 8.5 GB free (4.2%)
  After:  19.8 GB free (9.7%)

  Clean cut. 
```

## Schedule It

Pair cleanup with a cron job for automatic nightly cleanup:

```json
{
  "name": "cleanup â€” Nightly Cleanup",
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

- **Dry run by default in interactive mode** â€” shows what it'll cut before cutting
- **Never touches user files** â€” only targets known cleanup locations
- **Logs everything** â€” outputs exactly what was deleted and how much space was freed
- **Skips active processes** â€” only kills orphans, never your running work

## Requirements

- Windows (PowerShell 5.1+)
- Administrator not required for most operations

---

*"Clean cut." â€” Part of [The Armory](https://github.com/VontaJamal/armory)*

