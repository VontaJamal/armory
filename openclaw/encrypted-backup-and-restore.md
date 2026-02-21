# Encrypted Backup and One-Command Restore

Set up automatic encrypted backups of your entire OpenClaw workspace with a custom terminal command to restore instantly.

## What You Get

After setup, you'll have:
- **Encrypted backups** running automatically every 15 minutes (configurable)
- **AES-256 encryption** with header encryption so file names are hidden too
- **Auto-pruning** so old backups don't eat your disk
- **A custom CLI command** like `faye arise` to restore from the latest backup in seconds

## Quick Setup (One Script)

```powershell
# Download and run
.\setup-rebirth.ps1 -Name "faye" -Command "arise"
```

**Parameters:**

| Param | Default | What It Does |
|-------|---------|-------------|
| `-Name` | (required) | Your bot's name. Becomes the CLI command. |
| `-Command` | `arise` | The restore subcommand. |
| `-IntervalMinutes` | `15` | How often backups run. |
| `-KeepCount` | `10` | How many backups to keep before pruning. |

**Examples:**
```powershell
# "sage arise" to restore, backup every 30 min, keep 5
.\setup-rebirth.ps1 -Name "sage" -Command "arise" -IntervalMinutes 30 -KeepCount 5

# "nova restore" with defaults
.\setup-rebirth.ps1 -Name "nova" -Command "restore"

# "jarvis wake" every 10 minutes
.\setup-rebirth.ps1 -Name "jarvis" -Command "wake" -IntervalMinutes 10
```

## What It Creates

```
~\.openclaw\
├── backups\
│   ├── openclaw-backup-2026-02-20_14-30.7z   (encrypted)
│   ├── openclaw-backup-2026-02-20_14-15.7z
│   └── ...
├── secrets\
│   └── backup-password.txt    ← SAVE THIS SOMEWHERE SAFE
└── scripts\
    ├── shadow-court-backup.ps1   (the backup logic)
    ├── yourname.ps1              (the CLI)
    └── yourname.cmd              (CMD wrapper)
```

## Your Commands

```powershell
# Restore from latest backup
yourname arise

# Create a backup right now
yourname backup

# Check backup health
yourname status
```

## Manual Setup (If You Prefer)

### 1. Install 7-Zip
```powershell
choco install 7zip
```

### 2. Create a backup password
```powershell
$password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
Set-Content -Path "$env:USERPROFILE\.openclaw\secrets\backup-password.txt" -Value $password -NoNewline
```

Save this password somewhere safe. Without it, your backups are unrecoverable.

### 3. Create the backup script
```powershell
$7z = "C:\Program Files\7-Zip\7z.exe"
$source = "$env:USERPROFILE\.openclaw"
$dest = "$env:USERPROFILE\.openclaw\backups"
$password = (Get-Content "$env:USERPROFILE\.openclaw\secrets\backup-password.txt" -Raw).Trim()
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$file = Join-Path $dest "openclaw-backup-$timestamp.7z"

& $7z a -t7z -mhe=on "-p$password" $file $source `
    -xr!"backups" -xr!"node_modules" -xr!".git" -xr!"__pycache__"
```

### 4. Schedule it
```powershell
schtasks /create /tn "OpenClawBackup" `
    /tr "powershell -ExecutionPolicy Bypass -File C:\path\to\backup.ps1" `
    /sc minute /mo 15 /f
```

### 5. Restore from backup
```powershell
$latest = Get-ChildItem "$env:USERPROFILE\.openclaw\backups" -Filter "*.7z" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$password = (Get-Content "$env:USERPROFILE\.openclaw\secrets\backup-password.txt" -Raw).Trim()
& "C:\Program Files\7-Zip\7z.exe" x $latest.FullName -o"$env:TEMP\restore" "-p$password" -y
Copy-Item -Path "$env:TEMP\restore\.openclaw\*" -Destination "$env:USERPROFILE\.openclaw" -Recurse -Force
```

## What Gets Backed Up

Everything in `~\.openclaw\` except:
- `backups/` (no backup-ception)
- `node_modules/`
- `.git/` directories
- `__pycache__/`

This includes your workspace, agent workspaces, secrets, configs, memory files, scripts, and cron state.

## What Gets Encrypted

Everything. 7-Zip's `-mhe=on` flag encrypts both file contents AND file names. Without the password, an attacker can't even see what's inside the archive.

## Mac/Linux Version

The same concept works with `gpg` instead of 7-Zip:

```bash
# Backup
tar czf - ~/.openclaw --exclude='backups' --exclude='node_modules' --exclude='.git' \
    | gpg --symmetric --cipher-algo AES256 -o ~/.openclaw/backups/backup-$(date +%Y-%m-%d_%H-%M).tar.gz.gpg

# Restore
gpg -d ~/.openclaw/backups/backup-LATEST.tar.gz.gpg | tar xzf - -C /
```

## Tips

- **Test your restore** before you need it. Run `yourname arise` once after setup to make sure it works.
- **Back up the password** separately. Store it in a password manager, not just on the same machine.
- **Check status weekly.** Run `yourname status` to make sure backups are still running.
- **15 minutes is a good default.** Each backup is small (2-5 MB compressed). 10 backups = 20-50 MB total.
