<#
.SYNOPSIS
  Phoenix Down - encrypted backup tool.
#>

param(
    [string]$BackupSource = "$env:USERPROFILE\.openclaw",
    [string]$BackupDest = "$env:USERPROFILE\.openclaw\backups",
    [string]$PasswordFile = "$env:USERPROFILE\.openclaw\secrets\backup-password.txt",
    [int]$MaxBackups = 10,
    [switch]$List,
    [switch]$Verify,
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

$sevenZip = "C:\Program Files\7-Zip\7z.exe"

function Write-Banner {
    Write-Host ""
    Write-Host "  Phoenix Down" -ForegroundColor Yellow
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
}

function Write-Check {
    param([string]$Label, [string]$Status, [string]$Color)
    Write-Host ("    " + $Label.PadRight(40)) -NoNewline -ForegroundColor White
    Write-Host $Status -ForegroundColor $Color
}

function Show-Help {
    Write-Banner
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\phoenix-down.ps1"
    Write-Host "    .\\phoenix-down.ps1 -List"
    Write-Host "    .\\phoenix-down.ps1 -Verify"
    Write-Host "    .\\phoenix-down.ps1 -BackupSource D:\\Work -BackupDest D:\\Backups"
    Write-Host ""
}

function Ensure-SevenZip {
    if (-not (Test-Path $sevenZip)) {
        Write-Host "  7-Zip not found. Install with: choco install 7zip" -ForegroundColor Red
        if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
        exit 1
    }
}

function Get-Backups {
    if (-not (Test-Path $BackupDest)) {
        return @()
    }
    return Get-ChildItem -Path $BackupDest -Filter "*.7z" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
}

function Show-Backups {
    Write-Banner
    $files = Get-Backups
    if ($files.Count -eq 0) {
        Write-Host ""
        Write-Host "  none found" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    Write-Host ""
    foreach ($f in $files) {
        $sizeMB = [math]::Round($f.Length / 1MB, 2)
        Write-Host ("  {0}  ({1} MB)  {2}" -f $f.Name, $sizeMB, $f.LastWriteTime) -ForegroundColor White
    }
    Write-Host ""
}

function Read-Password {
    if (-not (Test-Path $PasswordFile)) {
        Write-Host "  Password file missing: $PasswordFile" -ForegroundColor Red
        Write-Host "  Create it with a strong password text value." -ForegroundColor Yellow
        if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
        exit 1
    }
    return ([System.IO.File]::ReadAllText($PasswordFile)).Trim()
}

function Verify-LatestBackup {
    Ensure-SevenZip
    $files = Get-Backups
    Write-Banner

    if ($files.Count -eq 0) {
        Write-Check -Label "Latest backup" -Status "none found" -Color "Red"
        if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
        exit 1
    }

    $latest = $files[0]
    $ageHours = [math]::Round(((Get-Date) - $latest.LastWriteTime).TotalHours, 1)
    Write-Check -Label "Latest backup" -Status $latest.Name -Color "Green"
    Write-Check -Label "Size" -Status ("{0} MB" -f [math]::Round($latest.Length / 1MB, 2)) -Color "White"
    Write-Check -Label "Age" -Status ("{0}h" -f $ageHours) -Color "White"

    $password = Read-Password
    & $sevenZip t $latest.FullName ("-p" + $password) | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Check -Label "Integrity" -Status "pass" -Color "Green"
        if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
        exit 0
    }

    Write-Check -Label "Integrity" -Status "FAIL" -Color "Red"
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

if ($Help) {
    Show-Help
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if ($List) {
    Show-Backups
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if ($Verify) {
    Verify-LatestBackup
}

Ensure-SevenZip
Write-Banner

if (-not (Test-Path $BackupSource)) {
    Write-Host "  Backup source missing: $BackupSource" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

if (-not (Test-Path $BackupDest)) {
    New-Item -ItemType Directory -Path $BackupDest -Force | Out-Null
}

$password = Read-Password
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$baseName = (Split-Path $BackupSource -Leaf)
if (-not $baseName) { $baseName = "backup" }
$backupFile = Join-Path $BackupDest ("{0}-{1}.7z" -f $baseName, $stamp)

Write-Check -Label "Source" -Status $BackupSource -Color "White"
Write-Check -Label "Destination" -Status $BackupDest -Color "White"
Write-Check -Label "Archive" -Status (Split-Path $backupFile -Leaf) -Color "White"

& $sevenZip a -t7z -mhe=on ("-p" + $password) $backupFile $BackupSource -xr!"node_modules" -xr!".git" -xr!"__pycache__" -xr!"backups" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Check -Label "Backup" -Status "FAIL" -Color "Red"
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

Write-Check -Label "Backup" -Status "pass" -Color "Green"

$existing = Get-Backups
if ($existing.Count -gt $MaxBackups) {
    $toDelete = $existing | Select-Object -Skip $MaxBackups
    foreach ($old in $toDelete) {
        Remove-Item $old.FullName -Force -ErrorAction SilentlyContinue
        Write-Check -Label "Pruned" -Status $old.Name -Color "DarkGray"
    }
}

Write-Host ""
Write-Host "  completed" -ForegroundColor Green
Write-Host ""

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
