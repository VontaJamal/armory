# BUILD SPECS - The Armory (Current)

This file tracks the current implementation targets and naming.

All PowerShell scripts target PowerShell 5.1 and should:

- Run with `powershell -ExecutionPolicy Bypass -File <script>`
- Support `-Help`
- Return clear exit codes (`0` success, `1` failure/findings)
- Avoid parser-risk strings and non-essential script crashes

## Naming Updates In This Release

- `init.ps1` -> `awakening.ps1` (legacy alias retained)
- `weapons/sentinel/sentinel.ps1` -> `weapons/aegis/aegis.ps1` (legacy alias retained)
- `weapons/scan/deep-scan.ps1` -> `weapons/truesight/truesight.ps1` (legacy alias retained)
- `weapons/phoenix-down/setup-rebirth.ps1` -> `weapons/phoenix-down/save-point.ps1` (legacy alias retained)

## Tool Boundaries

- `Libra`: operations intelligence only (system/service/update/git status)
- `Scan` and `Truesight`: security scanning only
- `Protect`: scheduled security scanner (quiet by default)
- `Cure`: backup verification and integrity checks
- `Regen`: morning summary

## Implemented Build Scope

## Broken fixes

1. `summons/bahamut/bahamut.ps1`
- parser-risk text cleaned
- `-Help` behavior aligned

2. `summons/ifrit/ifrit.ps1`
- parser-risk text cleaned
- no-args path prints usage cleanly

3. `weapons/scan/scan.ps1` and `weapons/truesight/truesight.ps1`
- scan logic uses safe file reads for looped scans

## Thin upgrades

4. `weapons/phoenix-down/phoenix-down.ps1`
- help, list, verify, configurable source/destination/password paths
- graceful dependency handling for 7-Zip

5. `weapons/aegis/aegis.ps1`
- help, services override, silent mode
- optional Telegram alerts

## New spells

6. `spells/libra/libra.ps1`
7. `spells/cure/cure.ps1`
8. `spells/protect/protect.ps1`
9. `spells/regen/regen.ps1`

## New command setup

10. `awakening.ps1`
- interactive command word setup
- `%USERPROFILE%\bin\<command>.cmd` dispatcher generation
- config saved at `~/.armory/config.json`

## Bard module

11. `bard/`
- `bard.ps1`
- `lib/bard-core.ps1`
- `lib/bard-hooks.ps1`
- user asset resolution order:
  1. `~/.armory/bard/assets`
  2. repo fallback `./bard/assets`

## Warp (`weapons/warp/`)

One-command SSH into any machine. No memorizing IPs, users, or key paths.

**Files:** `warp.sh` (zsh, Mac/Linux primary), `warp.ps1` (Windows), `README.md`

**Commands:**
```bash
warp                         # SSH into default machine (interactive shell)
warp "openclaw pairing"      # Run one command on default machine, come back
warp <name>                  # SSH into a named machine
warp <name> "command"        # Run command on named machine
warp add <name>              # Interactive: add a machine (host, user, key, set as default?)
warp list                    # Show all saved machines
warp remove <name>           # Remove a machine
warp set-default <name>      # Change default machine
```

**Config:** `~/.warp/machines.json`
```json
{
  "default": "windows",
  "machines": {
    "windows": { "host": "192.168.1.188", "user": "devon", "key": "~/.ssh/id_ed25519" },
    "pi": { "host": "192.168.1.50", "user": "pi" },
    "vps": { "host": "my.server.com", "user": "root", "port": 2222 }
  }
}
```

**Behavior:**
- No args = SSH into default machine (interactive session)
- With quoted command = run on default, print output, return to local shell
- `warp add` = interactive wizard: host, user, key path (optional), set as default?
- First machine added becomes default automatically
- If no key specified, rely on ssh-agent or system default
- Custom port support via config
- Colored output: machine name in cyan, connection status

**Standalone:** Works without OpenClaw. Pure SSH wrapper. Anyone with two machines benefits.

---

## Sound Integration

Optional sound cues are supported with:

- `-Sound` to enable on demand
- `-NoSound` to force disable

Integrated scripts initialize sound as optional behavior. Missing audio files do not block tool execution.
