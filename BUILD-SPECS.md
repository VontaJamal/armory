# BUILD SPECS — The Armory

Everything that needs to be built or fixed. Each spec has enough detail to hand to an agent and get back working code.

All scripts are **PowerShell 5.1** unless noted. All must:
- Run with `powershell -ExecutionPolicy Bypass -File <script>`
- Show colored output (Green=pass, Red=fail, Yellow=warn)
- Show help with `-Help` flag or no args
- Handle errors gracefully (no crashes on missing config)
- **NO fancy unicode** in Write-Host (no ─, ✓, ✗, ⚡, ❄️ etc.) — use plain ASCII (`---`, `pass`, `FAIL`, `x`, `[ok]`)
- **NO apostrophes inside strings** — PowerShell chokes on `don't`, `You're`, etc. Reword or escape.
- **NO `-Raw` flag on `Get-Content`** in loops — use `[System.IO.File]::ReadAllText($path)` instead
- Test every script: `powershell -ExecutionPolicy Bypass -File <script> -Help` must not error

---

## ❌ BROKEN — Fix These

### 1. Bahamut (`summons/bahamut/bahamut.ps1`)
**Problem:** Apostrophe in string literal (`don't`) breaks PowerShell parser at line 131.
**Fix:** Find every string with apostrophes and reword them. Check every `Write-Host` line.
**Test:** `.\bahamut.ps1 -Help` should print usage and exit clean.

### 2. Ifrit (`summons/ifrit/ifrit.ps1`)  
**Problem:** `You're` on line 176 has an apostrophe inside a string, breaks parser.
**Fix:** Same — find all apostrophes in strings, reword. `"You are live"` not `"You're live"`.
**Test:** `.\ifrit.ps1` with no args should print usage and exit clean.

### 3. Scan (`weapons/scan/scan.ps1`)
**Problem:** Uses `Get-Content -Raw` in a loop scanning files. Errors in some PS environments.
**Fix:** Replace `Get-Content $f.FullName -Raw` with `[System.IO.File]::ReadAllText($f.FullName)` everywhere.
**Also:** The deep-scan.ps1 likely has the same issue — check and fix both.
**Test:** `.\scan.ps1` should run against `D:\Code Repos\armory\` itself without errors.

---

## ⚠️ THIN — Needs More

### 4. Phoenix Down (`weapons/phoenix-down/phoenix-down.ps1`) — 50 lines
**What it is:** Encrypted backup using 7-Zip.
**What it needs:**
- Help screen (`-Help` flag) explaining what it does, what it backs up, where it saves
- Colored output matching the Armory style (banner, status lines)
- `-Verify` flag that tests the backup can be extracted (Cure spell logic)
- `-List` flag showing existing backups with dates and sizes
- Configurable backup paths (not hardcoded to `.openclaw`)
- Graceful error if 7-Zip not installed (tell user `choco install 7zip`)
- Should work for ANY directory backup, not just OpenClaw
**Keep:** The setup-rebirth.ps1 companion is fine at 184 lines.
**Test:** `.\phoenix-down.ps1 -Help` prints usage. `.\phoenix-down.ps1 -List` shows backups or "none found".

### 5. Sentinel (`weapons/sentinel/sentinel.ps1`) — 45 lines
**What it is:** Service health check with Telegram alerting.
**What it needs:**
- Help screen (`-Help`)
- Colored output with banner
- `-Services` param to override default service list
- `-Silent` flag (no output, just exit code — for cron use)
- When Telegram is not configured, still works as local check (just prints, no alert)
- Show last-checked timestamp
- Config section at top (like Ramuh has) for services list, Telegram bot token, chat ID
**Test:** `.\sentinel.ps1 -Help` prints usage. `.\sentinel.ps1` checks services and prints colored status.

---

## 🔮 SPELLS — Need Real Scripts

All 4 spells are README-only (cron config templates). Each needs an actual script that does the work.

### 6. Libra (`spells/libra/libra.ps1`)
**What it does:** Daily system intel report. The "morning newspaper" for your infrastructure.
**Script should:**
- Collect: disk space, service status, top 5 memory-consuming processes, uptime, last boot, pending Windows updates count
- Collect: git repos status (any uncommitted changes in configured dirs)
- Collect: API key status (set or not, like Ramuh does)
- Format as a clean text report
- `-Telegram` flag: sends report to configured Telegram chat (bot token + chat ID from config)
- `-Output <path>` flag: save to file instead of stdout
- Without flags: prints to terminal
- Config section at top: telegram bot token, chat ID, git repo dirs to check, API key env var names
**Test:** `.\libra.ps1` prints a full system report to terminal.

### 7. Cure (`spells/cure/cure.ps1`)
**What it does:** Verifies backups are actually restorable. Trust but verify.
**Script should:**
- Find latest backup in configured backup dir (default: `~/.openclaw/backups/`)
- Check: file exists, not zero bytes, modified within expected window (default 24h)
- If 7-Zip backup: test archive integrity (`7z t <archive>`)
- Report: last backup date, size, age, integrity pass/fail
- `-Telegram` flag: alert if backup is stale or corrupt
- `-Dir <path>` to override backup directory
- Exit code 0 = healthy, 1 = problem found (for cron)
**Test:** `.\cure.ps1` checks backup directory and reports.

### 8. Protect (`spells/protect/protect.ps1`)
**What it does:** Scheduled security scan. Same as Scan weapon but designed for cron (quieter output, alerts on findings).
**Script should:**
- Run the same secret-detection logic as `scan.ps1` but against configured directories
- Only output if findings are found (quiet by default for cron)
- `-Telegram` flag: send alert with findings summary
- `-Dirs <path1>,<path2>` to specify what to scan
- `-Verbose` flag: show full output even when clean
- Config section: dirs to scan, telegram config, patterns to ignore
- Exit code 0 = clean, 1 = findings
**Test:** `.\protect.ps1 -Verbose` scans and shows output.

### 9. Regen (`spells/regen/regen.ps1`)
**What it does:** Morning briefing. Combines key info into a "start your day" summary.
**Script should:**
- Collect: current weather (wttr.in curl for configured city), disk space summary, service health, any failed cron jobs (if openclaw installed)
- Collect: calendar events today (optional — if Google Calendar API configured)
- Collect: git repos with uncommitted changes
- Format as a brief, readable morning summary
- `-Telegram` flag: deliver to chat
- `-City <name>` to override weather location
- Config section: city, telegram config, git repo dirs, optional Google Calendar creds path
**Test:** `.\regen.ps1` prints morning briefing to terminal.

---

## 🏗️ NOT YET BUILT

### 10. `armory init` (root level `init.ps1`)
**What it does:** Sets up a custom command alias so users can type `faye swap` instead of `armory swap`.
**Script should:**
- Interactive prompt: "Pick a command name. This is the word you type to run Armory tools."
- Show examples: `armory, ops, forge, faye, kit`
- Create a .cmd wrapper in a PATH directory (or add to PATH)
- On Windows: creates `<name>.cmd` in `%USERPROFILE%\bin\` and adds to User PATH if needed
- On Mac/Linux (future): creates shell alias in `~/.zshrc` or `~/.bashrc`
- Save config to `~/.armory/config.json`: `{ "commandWord": "faye", "installDir": "..." }`
- Show confirmation with example commands they can now run
**Test:** `.\init.ps1` walks through setup interactively.

### 11. Bard Shop (`bard/`)
**Status:** Concept only. Music/audio division.
**Plan:** Anime OSTs, terminal sound effects, agent entrance themes. Not building scripts yet — this needs creative direction first. Skip for now.

---

### 12. Warp (`weapons/warp/`)
**What it does:** One-command SSH into a remote machine. No remembering IPs, users, or key paths.
**Why it matters:** Most developers have 2+ machines. Typing `ssh -i ~/.ssh/id_ed25519 devon@192.168.1.188` every time is painful. Warp stores your machines and gets you there instantly.
**Files:** `warp.sh` (zsh, Mac/Linux), `warp.ps1` (Windows), `README.md`

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
- `warp` with no args = SSH into default machine (interactive session)
- `warp "command"` = run command on default, print output, return to local shell
- `warp add` = interactive wizard: "Host IP or domain?", "SSH user?", "SSH key path? (optional)", "Set as default? (y/n)"
- If no default set, first machine added becomes default
- If SSH key not specified, use system default (`~/.ssh/id_ed25519` or ssh-agent)
- Support custom port via config
- Colored output: machine name in cyan, connection status, command output

**README scroll format:** What it is, who it is for (anyone with more than one machine), usage examples, setup, pairs with Teleport item guide.

**Standalone:** Works without OpenClaw. Pure SSH wrapper. Anyone with two machines benefits.

---

## STYLE GUIDE FOR ALL SCRIPTS

```powershell
# Banner pattern
function Write-Banner {
    Write-Host ""
    Write-Host "  <Name>" -ForegroundColor <Color>
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
}

# Status line pattern
function Write-Check {
    param([string]$Label, [string]$Status, [string]$Color, [int]$Pad = 40)
    Write-Host ("    " + $Label.PadRight($Pad)) -NoNewline -ForegroundColor White
    Write-Host $Status -ForegroundColor $Color
}

# Config pattern (top of every script)
$config = @{
    telegramBotToken = $env:TELEGRAM_BOT_TOKEN   # optional
    telegramChatId   = $env:TELEGRAM_CHAT_ID     # optional
    # ... tool-specific config
}
```

**Color scheme:**
- Banner title: Cyan (summons), Yellow (weapons), Magenta (spells)
- Pass: Green
- Fail: Red  
- Warning: Yellow
- Info/skip: DarkGray
- Labels: White

**Every script must have:**
1. Synopsis comment block at top
2. `-Help` param that prints usage and exits
3. Config section with sensible defaults
4. Clean exit codes (0 = success, 1 = error/findings)
