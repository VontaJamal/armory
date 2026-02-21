<#
.SYNOPSIS
  Bahamut - restore OpenClaw environment from encrypted backup.
#>

param(
    [string]$BackupPath,
    [string]$Password,
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Stop"
$ocBase = "$env:USERPROFILE\.openclaw"
$tempExtract = "$env:TEMP\bahamut-deploy"
$sevenZip = "C:\Program Files\7-Zip\7z.exe"

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

function Show-Help {
    Write-Host ""
    Write-Host "  Bahamut" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\bahamut.ps1 -BackupPath C:\\Backups\\latest.7z"
    Write-Host "    .\\bahamut.ps1 -BackupPath C:\\Backups\\latest.7z -Password your-password"
    Write-Host ""
}

if ($Help -or -not $BackupPath) {
    Show-Help
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if (-not (Test-Path $BackupPath)) {
    Write-Host "  backup not found: $BackupPath" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

if (-not (Test-Path $sevenZip)) {
    Write-Host "  7-Zip required. Install: choco install 7zip" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

if (-not $Password) {
    $securePass = Read-Host "  Encryption password" -AsSecureString
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass))
}

if (Test-Path $tempExtract) {
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null

Write-Host ""
Write-Host "  Bahamut restore" -ForegroundColor Cyan
Write-Host "  -----------------------------" -ForegroundColor DarkGray

Write-Host "  [1/8] Extracting archive..." -NoNewline
& $sevenZip x $BackupPath ("-o" + $tempExtract) ("-p" + $Password) -y | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host " FAIL" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}
Write-Host " pass" -ForegroundColor Green

Write-Host "  [2/8] Restoring openclaw.json..." -NoNewline
$configSource = Get-ChildItem $tempExtract -Recurse -Filter "openclaw.json" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($configSource) {
    if (-not (Test-Path $ocBase)) { New-Item -ItemType Directory -Path $ocBase -Force | Out-Null }
    Copy-Item $configSource.FullName (Join-Path $ocBase "openclaw.json") -Force
    Write-Host " pass" -ForegroundColor Green
} else {
    Write-Host " warn" -ForegroundColor Yellow
}

Write-Host "  [3/8] Restoring secrets..." -NoNewline
$secretsSource = Get-ChildItem $tempExtract -Recurse -Directory -Filter "secrets" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($secretsSource) {
    $targetSecrets = Join-Path $ocBase "secrets"
    if (-not (Test-Path $targetSecrets)) { New-Item -ItemType Directory -Path $targetSecrets -Force | Out-Null }
    Copy-Item (Join-Path $secretsSource.FullName "*") $targetSecrets -Recurse -Force
    Write-Host " pass" -ForegroundColor Green
} else {
    Write-Host " warn" -ForegroundColor Yellow
}

Write-Host "  [4/8] Restoring workspaces..." -NoNewline
$workspaces = Get-ChildItem $tempExtract -Recurse -Directory -Filter "workspace*" -ErrorAction SilentlyContinue
$count = 0
foreach ($ws in $workspaces) {
    $target = Join-Path $ocBase $ws.Name
    if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
    Copy-Item (Join-Path $ws.FullName "*") $target -Recurse -Force -ErrorAction SilentlyContinue
    $count++
}
Write-Host (" pass ({0})" -f $count) -ForegroundColor Green

Write-Host "  [5/8] Checking gateway service..." -NoNewline
$gw = sc.exe query OpenClawGateway 2>&1
if ($gw -match "RUNNING|STOPPED|PAUSED") {
    Write-Host " pass" -ForegroundColor Green
} else {
    Write-Host " warn" -ForegroundColor Yellow
}

Write-Host "  [6/8] Checking Telegram config..." -NoNewline
$configPath = Join-Path $ocBase "openclaw.json"
if (Test-Path $configPath) {
    try {
        $cfgText = [System.IO.File]::ReadAllText($configPath)
        $cfg = $cfgText | ConvertFrom-Json
        if ($cfg.channels.telegram.enabled) {
            Write-Host " pass" -ForegroundColor Green
        } else {
            Write-Host " warn" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " warn" -ForegroundColor Yellow
    }
} else {
    Write-Host " warn" -ForegroundColor Yellow
}

Write-Host "  [7/8] Detecting cron files..." -NoNewline
$cronFiles = Get-ChildItem $tempExtract -Recurse -Filter "cron*.json" -ErrorAction SilentlyContinue
if ($cronFiles) {
    Write-Host (" pass ({0})" -f $cronFiles.Count) -ForegroundColor Green
} else {
    Write-Host " warn" -ForegroundColor Yellow
}

Write-Host "  [8/8] Sync helper check..." -NoNewline
$syncScript = Get-ChildItem $tempExtract -Recurse -Filter "sync-workspace*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($syncScript) {
    Copy-Item $syncScript.FullName $ocBase -Force
    Write-Host " pass" -ForegroundColor Green
} else {
    Write-Host " warn" -ForegroundColor Yellow
}

Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  restore complete" -ForegroundColor Green
Write-Host ""

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
