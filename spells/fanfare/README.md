# Fanfare

| | |
|---|---|
| **FF Name** | Fanfare |
| **Flavor Text** | *The victory theme plays. Your party has won the battle.* |
| **Plain English** | Play a completion sound when a task finishes — terminal bell, system beep, custom melody, or .wav file. Chain it after any command. |

## Usage

```powershell
# After any long-running command
long-task; fanfare

# Built-in melodies
fanfare --melody victory     # Ascending C-E-G-C chime
fanfare --melody levelup     # Full scale run (for big wins)
fanfare --melody alert       # Double beep (attention needed)
fanfare --melody error       # Descending tone (something broke)

# SSH-friendly (no sound card needed)
fanfare --bell               # Terminal bell character (\x07)
fanfare --beep               # System speaker beep

# Custom sound
fanfare --sound path/to/win.wav

# With Windows toast notification
fanfare --message "Build complete!"

# Pipe mode (pass stdin through, play when done)
npm run build 2>&1 | fanfare --pipe --melody victory
```

## Why

You kick off a task, switch tabs, forget about it. Ten minutes later you wonder if it's done. Fanfare solves that — chain it after any command and you'll *hear* when it finishes.

Works over SSH (use `--bell`), headless servers (use `--beep`), or full desktop (default melodies or custom `.wav`).

## Install

Copy `fanfare.ps1` to your scripts directory, or use it directly:

```powershell
. path/to/fanfare.ps1
```

## Melodies

| Name | Notes | Use Case |
|------|-------|----------|
| `victory` | C-E-G-C ascending | Default — task complete |
| `levelup` | Full C scale run | Big wins, deployments |
| `alert` | Double A beep | Needs attention |
| `error` | Descending A-E-A | Something failed |

## Requirements

- **Windows**: PowerShell 5.1+ (built-in `System.Media.SoundPlayer` + `[console]::beep`)
- **Toast notifications**: Windows 10/11 (gracefully skipped if unavailable)

---

*Part of [The Armory](https://github.com/VontaJamal/armory) — weapons for developers who ship.*

🏴‍☠️ [Sovereign](https://github.com/VontaJamal) — The Shadow Dominion.
