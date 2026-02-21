# Bard (Optional Audio Layer)

## What This Does

Adds optional sound cues and theme playback for Armory scripts.

## Who This Is For

- You want audible start/success/fail feedback.
- You want themed local audio playback from your own files.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\bard\bard.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\bard\bard.ps1 list
powershell -ExecutionPolicy Bypass -File .\bard\bard.ps1 test
```

## Common Tasks

```powershell
# Enable sound globally
powershell -ExecutionPolicy Bypass -File .\bard\bard.ps1 enable

# Play a specific cue file
powershell -ExecutionPolicy Bypass -File .\bard\bard.ps1 play -File "C:\Users\you\.armory\bard\assets\sfx\success.wav"

# Set theme mapping
powershell -ExecutionPolicy Bypass -File .\bard\bard.ps1 theme -Set "default" -File "C:\Users\you\.armory\bard\assets\themes\default.mp3"
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Help` | off | Print usage and exit |
| `list` | n/a | Show discovered assets and config |
| `play -File <path>` | n/a | Play a specific audio file |
| `test` | n/a | Play start/success/fail test cues |
| `enable` | n/a | Enable sound globally |
| `disable` | n/a | Disable sound globally |
| `theme -Set <name> -File <path>` | n/a | Map a theme name to an audio file |
| `config` | n/a | Print current bard config |

## Config

Primary config path: `~/.armory/bard/config.json`

Default asset search order:

1. `~/.armory/bard/assets`
2. repo fallback `./bard/assets`

Supported formats:

- `.wav` (primary)
- `.mp3` (fallback via Windows media COM)

## Output And Exit Codes

- `0`: command completed.
- `1`: invalid args, file missing, or playback failure.

## Troubleshooting

- No sound: verify OS audio output and file path.
- MP3 not playing: use WAV or verify Windows media COM availability.

## Automation Examples

```powershell
# In scheduler: scripts remain silent unless -Sound is set or Bard is enabled
powershell -ExecutionPolicy Bypass -File .\weapons\aegis\aegis.ps1 -Silent
```

## FAQ

**Is sound required?**
No. All scripts work without Bard.

## Migration Notes

Bard is a new module in this release.
