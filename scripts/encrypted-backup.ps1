# Encrypted workspace backup using 7-Zip
# Schedule this with Task Scheduler for automatic backups
#
# Usage: .\encrypted-backup.ps1
# Requires: 7-Zip installed (choco install 7zip)
#
# Customize these variables for your setup:

$BackupSource = "$env:USERPROFILE\.openclaw"
$BackupDest = "$env:USERPROFILE\.openclaw\backups"
$PasswordFile = "$env:USERPROFILE\.openclaw\secrets\backup-password.txt"
$MaxBackups = 10
$7z = "C:\Program Files\7-Zip\7z.exe"

# Create backup directory if needed
if (-not (Test-Path $BackupDest)) {
    New-Item -ItemType Directory -Path $BackupDest | Out-Null
}

# Generate timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$backupFile = Join-Path $BackupDest "openclaw-backup-$timestamp.7z"

# Read password
if (-not (Test-Path $PasswordFile)) {
    Write-Error "Password file not found at $PasswordFile"
    Write-Output "Create one: Set-Content -Path '$PasswordFile' -Value 'your-strong-password'"
    exit 1
}
$password = (Get-Content $PasswordFile -Raw).Trim()

# Create encrypted backup
& $7z a -t7z -mhe=on "-p$password" $backupFile $BackupSource `
    -xr!"backups" -xr!"node_modules" -xr!".git" -xr!"__pycache__"

if ($LASTEXITCODE -eq 0) {
    Write-Output "Backup created: $backupFile"
    
    # Prune old backups
    $existing = Get-ChildItem $BackupDest -Filter "openclaw-backup-*.7z" | Sort-Object LastWriteTime -Descending
    if ($existing.Count -gt $MaxBackups) {
        $toDelete = $existing | Select-Object -Skip $MaxBackups
        foreach ($old in $toDelete) {
            Remove-Item $old.FullName
            Write-Output "Pruned: $($old.Name)"
        }
    }
} else {
    Write-Error "Backup failed with exit code $LASTEXITCODE"
}
