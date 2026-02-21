<#
.SYNOPSIS
  Save Point - setup recurring backup and restore command.
#>

param(
    [string]$Name,
    [string]$Command = "arise",
    [int]$IntervalMinutes = 60,
    [int]$KeepCount = 10,
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Stop"

$hookCandidates = @(
    (Join-Path $PSScriptRoot "..\..\bard\lib\bard-hooks.ps1"),
    (Join-Path $PSScriptRoot "..\bard\lib\bard-hooks.ps1")
)
foreach ($h in $hookCandidates) {
    if (Test-Path $h) { . $h; break }
}
$soundContext = $null
if (Get-Command Initialize-ArmorySound -ErrorAction SilentlyContinue) {
    $soundContext = Initialize-ArmorySound -Sound:$Sound -NoSound:$NoSound
    Invoke-ArmoryCue -Context $soundContext -Type start
}

function Show-Usage {
    Write-Host ""
    Write-Host "  Save Point" -ForegroundColor Yellow
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\save-point.ps1 -Name faye"
    Write-Host "    .\\save-point.ps1 -Name faye -Command arise -IntervalMinutes 60 -KeepCount 10"
    Write-Host ""
}

if ($Help) {
    Show-Usage
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if (-not $Name) {
    Show-Usage
    $Name = Read-Host "  Command word for backup tool"
}

if (-not $Name) {
    Write-Host "  Name is required" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$homeArmory = Join-Path $env:USERPROFILE ".armory"
$toolDir = Join-Path $homeArmory "save-point"
$openclawDir = Join-Path $env:USERPROFILE ".openclaw"
$backupDir = Join-Path $openclawDir "backups"
$passwordFile = Join-Path $openclawDir "secrets\backup-password.txt"
$binDir = Join-Path $env:USERPROFILE "bin"

foreach ($dir in @($homeArmory, $toolDir, $backupDir, (Split-Path $passwordFile -Parent), $binDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

if (-not (Test-Path $passwordFile)) {
    $chars = ((65..90) + (97..122) + (48..57))
    $password = -join ($chars | Get-Random -Count 32 | ForEach-Object { [char]$_ })
    Set-Content -Path $passwordFile -Value $password -Encoding ASCII
    Write-Host "  created password file: $passwordFile" -ForegroundColor Green
} else {
    Write-Host "  password file exists: $passwordFile" -ForegroundColor DarkGray
}

$controllerPath = Join-Path $toolDir ("{0}-save-point.ps1" -f $Name)
$controllerBody = @"
param([Parameter(Position=0)][string]
`$Action)

`$repoRoot = `"$repoRoot`"
`$backupScript = Join-Path `$repoRoot `"weapons\\phoenix-down\\phoenix-down.ps1`"
`$backupDir = `"$backupDir`"
`$passwordFile = `"$passwordFile`"
`$restoreSource = `"$openclawDir`"
`$sevenZip = `"C:\\Program Files\\7-Zip\\7z.exe`"
`$commandWord = `"$Name`"
`$restoreCommand = `"$Command`"

if (-not `$Action) { `$Action = `"help`" }

switch (`$Action.ToLower()) {
    `"$Command`" {
        `$latest = Get-ChildItem `$backupDir -Filter `"*.7z`" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not `$latest) {
            Write-Host `"No backups found in `$backupDir`" -ForegroundColor Red
            exit 1
        }
        if (-not (Test-Path `$sevenZip)) {
            Write-Host `"7-Zip required. Install: choco install 7zip`" -ForegroundColor Red
            exit 1
        }
        if (-not (Test-Path `$passwordFile)) {
            Write-Host `"Password file missing: `$passwordFile`" -ForegroundColor Red
            exit 1
        }
        `$password = [System.IO.File]::ReadAllText(`$passwordFile).Trim()
        `$temp = Join-Path `$env:TEMP (`"save-point-restore-`" + (Get-Date -Format `"yyyyMMddHHmmss`"))
        New-Item -ItemType Directory -Path `$temp -Force | Out-Null
        & `$sevenZip x `$latest.FullName (`"-o`" + `$temp) (`"-p`" + `$password) -y | Out-Null
        if (`$LASTEXITCODE -ne 0) {
            Write-Host `"Restore failed during extraction`" -ForegroundColor Red
            Remove-Item `$temp -Recurse -Force -ErrorAction SilentlyContinue
            exit 1
        }
        Copy-Item (Join-Path `$temp `"*`") `$restoreSource -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item `$temp -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host `"Restored from: `$(`$latest.Name)`" -ForegroundColor Green
        exit 0
    }
    `"backup`" {
        powershell -ExecutionPolicy Bypass -File `$backupScript -BackupSource `$restoreSource -BackupDest `$backupDir -PasswordFile `$passwordFile -MaxBackups $KeepCount
        exit `$LASTEXITCODE
    }
    `"status`" {
        `$backups = Get-ChildItem `$backupDir -Filter `"*.7z`" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        Write-Host `"Backups: `$(`$backups.Count)`" -ForegroundColor White
        if (`$backups.Count -gt 0) {
            `$latest = `$backups[0]
            Write-Host `"Latest: `$(`$latest.Name)`" -ForegroundColor DarkGray
            Write-Host `"Updated: `$(`$latest.LastWriteTime)`" -ForegroundColor DarkGray
        }
        exit 0
    }
    default {
        Write-Host `"Usage:`" -ForegroundColor White
        Write-Host `"  `$commandWord `$restoreCommand`" -ForegroundColor DarkGray
        Write-Host `"  `$commandWord backup`" -ForegroundColor DarkGray
        Write-Host `"  `$commandWord status`" -ForegroundColor DarkGray
        exit 0
    }
}
"@
Set-Content -Path $controllerPath -Value $controllerBody -Encoding UTF8

$cmdPath = Join-Path $binDir ("{0}.cmd" -f $Name)
$cmdBody = "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$controllerPath`" %*"
Set-Content -Path $cmdPath -Value $cmdBody -Encoding ASCII

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) { $userPath = "" }
if ($userPath -notlike "*${binDir}*") {
    $newPath = if ($userPath) { "$userPath;$binDir" } else { $binDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
}

$taskName = "ArmorySavePoint_$Name"
$taskExists = schtasks /query /tn $taskName 2>$null
if (-not $taskExists) {
    $taskRun = "powershell -ExecutionPolicy Bypass -File `"$controllerPath`" backup"
    schtasks /create /tn $taskName /tr $taskRun /sc minute /mo $IntervalMinutes /f | Out-Null
    Write-Host "  scheduled task created: $taskName" -ForegroundColor Green
} else {
    Write-Host "  scheduled task exists: $taskName" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Save Point setup complete" -ForegroundColor Green
Write-Host "  command: $Name $Command" -ForegroundColor White
Write-Host "  backup:  $Name backup" -ForegroundColor White
Write-Host "  status:  $Name status" -ForegroundColor White
Write-Host ""

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
