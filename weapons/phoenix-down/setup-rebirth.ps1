# Rebirth System Setup — Encrypted Backup + One-Command Restore
# 
# Sets up automatic encrypted backups of your OpenClaw workspace
# and a custom CLI command to restore from any backup instantly.
#
# Usage: .\setup-rebirth.ps1 -Name "faye" -Command "arise"
#   Then from any terminal: faye arise | faye backup | faye status
#
# Requirements: 7-Zip (choco install 7zip)

param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [Parameter(Mandatory=$false)]
    [string]$Command = "arise",
    
    [Parameter(Mandatory=$false)]
    [int]$IntervalMinutes = 15,
    
    [Parameter(Mandatory=$false)]
    [int]$KeepCount = 10
)

$ErrorActionPreference = "Stop"

Write-Output ""
Write-Output "=== Rebirth System Setup ==="
Write-Output "Name: $Name"
Write-Output "Restore command: $Name $Command"
Write-Output "Backup interval: every $IntervalMinutes minutes"
Write-Output "Backups kept: $KeepCount"
Write-Output ""

# Paths
$openclawDir = "$env:USERPROFILE\.openclaw"
$backupDir = "$env:USERPROFILE\.openclaw\backups"
$secretsDir = "$env:USERPROFILE\.openclaw\secrets"
$scriptsDir = "$env:USERPROFILE\.openclaw\scripts"
$passwordFile = "$secretsDir\backup-password.txt"
$7z = "C:\Program Files\7-Zip\7z.exe"

# Check 7-Zip
if (-not (Test-Path $7z)) {
    Write-Error "7-Zip not found. Install it: choco install 7zip"
    exit 1
}

# Create directories
foreach ($dir in @($backupDir, $secretsDir, $scriptsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Output "Created: $dir"
    }
}

# Generate backup password if not exists
if (-not (Test-Path $passwordFile)) {
    $password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
    Set-Content -Path $passwordFile -Value $password -NoNewline
    Write-Output "Generated backup password at: $passwordFile"
    Write-Output "SAVE THIS PASSWORD SOMEWHERE SAFE. Without it, backups cannot be restored."
} else {
    Write-Output "Backup password already exists at: $passwordFile"
}

# Create backup script
$backupScript = @"
`$ErrorActionPreference = "Continue"
`$7z = "C:\Program Files\7-Zip\7z.exe"
`$source = "$openclawDir"
`$dest = "$backupDir"
`$password = (Get-Content "$passwordFile" -Raw).Trim()
`$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
`$file = Join-Path `$dest "openclaw-backup-`$timestamp.7z"

& `$7z a -t7z -mhe=on "-p`$password" `$file `$source ``
    -xr!"backups" -xr!"node_modules" -xr!".git" -xr!"__pycache__" -xr!"*.7z" | Out-Null

if (`$LASTEXITCODE -eq 0) {
    Write-Output "Backup: `$file"
    `$old = Get-ChildItem `$dest -Filter "openclaw-backup-*.7z" | Sort-Object LastWriteTime -Descending | Select-Object -Skip $KeepCount
    foreach (`$f in `$old) { Remove-Item `$f.FullName; Write-Output "Pruned: `$(`$f.Name)" }
} else {
    Write-Error "Backup failed"
}
"@

$backupScriptPath = "$scriptsDir\shadow-court-backup.ps1"
Set-Content -Path $backupScriptPath -Value $backupScript
Write-Output "Created backup script: $backupScriptPath"

# Create the CLI command (.ps1 + .cmd wrapper)
$cliScript = @"
param([Parameter(Position=0)][string]`$Action)

switch (`$Action) {
    "$Command" {
        Write-Output ""
        Write-Output "  Restoring from latest backup..."
        `$latest = Get-ChildItem "$backupDir" -Filter "openclaw-backup-*.7z" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not `$latest) { Write-Error "No backups found in $backupDir"; exit 1 }
        `$password = (Get-Content "$passwordFile" -Raw).Trim()
        `$temp = "`$env:TEMP\openclaw-restore-`$(Get-Date -Format 'HHmmss')"
        & "C:\Program Files\7-Zip\7z.exe" x `$latest.FullName -o`$temp "-p`$password" -y | Out-Null
        if (`$LASTEXITCODE -ne 0) { Write-Error "Decryption failed"; exit 1 }
        Copy-Item -Path "`$temp\.openclaw\*" -Destination "$openclawDir" -Recurse -Force
        Remove-Item `$temp -Recurse -Force
        Write-Output "  Restored from: `$(`$latest.Name)"
        Write-Output "  $Name has risen."
        Write-Output ""
    }
    "backup" {
        Write-Output "  Running backup..."
        powershell -ExecutionPolicy Bypass -File "$backupScriptPath"
    }
    "status" {
        Write-Output ""
        Write-Output "  === $Name Status ==="
        `$backups = Get-ChildItem "$backupDir" -Filter "openclaw-backup-*.7z" | Sort-Object LastWriteTime -Descending
        Write-Output "  Backups: `$(`$backups.Count) (keeping $KeepCount)"
        if (`$backups.Count -gt 0) {
            `$latest = `$backups[0]
            `$size = [math]::Round(`$latest.Length / 1MB, 1)
            Write-Output "  Latest: `$(`$latest.Name) (`$(`$size) MB)"
            Write-Output "  Time: `$(`$latest.LastWriteTime.ToString('MMM d, yyyy h:mm tt'))"
        }
        `$task = schtasks /query /tn "ShadowCourtBackup" 2>`$null
        if (`$task) { Write-Output "  Auto-backup: ACTIVE (every $IntervalMinutes min)" }
        else { Write-Output "  Auto-backup: NOT SCHEDULED" }
        Write-Output ""
    }
    default {
        Write-Output ""
        Write-Output "  $Name"
        Write-Output "  Usage:"
        Write-Output "    $Name $Command    Restore from latest backup"
        Write-Output "    $Name backup   Create a backup now"
        Write-Output "    $Name status   Show backup status"
        Write-Output ""
    }
}
"@

$cliPath = "$scriptsDir\$Name.ps1"
Set-Content -Path $cliPath -Value $cliScript
Write-Output "Created CLI script: $cliPath"

# Create .cmd wrapper so it works from cmd.exe too
$cmdWrapper = "@echo off`npowershell -ExecutionPolicy Bypass -File `"$cliPath`" %*"
$cmdPath = "$scriptsDir\$Name.cmd"
Set-Content -Path $cmdPath -Value $cmdWrapper
Write-Output "Created CMD wrapper: $cmdPath"

# Add scripts dir to PATH if not already there
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$scriptsDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$scriptsDir", "User")
    Write-Output "Added $scriptsDir to PATH (restart terminal to use)"
} else {
    Write-Output "Scripts dir already in PATH"
}

# Create scheduled task for auto-backup
$taskExists = schtasks /query /tn "ShadowCourtBackup" 2>$null
if (-not $taskExists) {
    schtasks /create /tn "ShadowCourtBackup" /tr "powershell -ExecutionPolicy Bypass -File `"$backupScriptPath`"" /sc minute /mo $IntervalMinutes /f | Out-Null
    Write-Output "Scheduled task created: every $IntervalMinutes minutes"
} else {
    Write-Output "Scheduled task already exists"
}

Write-Output ""
Write-Output "=== Setup Complete ==="
Write-Output ""
Write-Output "Your commands (restart terminal first):"
Write-Output "  $Name $Command    Restore from latest encrypted backup"
Write-Output "  $Name backup   Create a backup right now"
Write-Output "  $Name status   Check backup health"
Write-Output ""
Write-Output "Backups run automatically every $IntervalMinutes minutes."
Write-Output "Password stored at: $passwordFile"
Write-Output "KEEP THAT PASSWORD SAFE."
Write-Output ""
