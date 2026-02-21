<#
.SYNOPSIS
  Bahamut — Megaflare. Full empire deployment from backup.
.USAGE
  .\bahamut.ps1 -BackupPath "backup.7z" -Password "secret"
  .\bahamut.ps1  (interactive mode)
#>

param(
    [string]$BackupPath,
    [string]$Password
)

$ErrorActionPreference = "Stop"
$ocBase = "$env:USERPROFILE\.openclaw"
$tempExtract = "$env:TEMP\bahamut-deploy"

# --- Interactive mode ---
if (-not $BackupPath) {
    Write-Host ""
    Write-Host "  Summoning Bahamut..." -ForegroundColor Magenta
    Write-Host ""
    $BackupPath = Read-Host "  Backup archive path"
    $securePass = Read-Host "  Encryption password" -AsSecureString
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass))
}

if (-not (Test-Path $BackupPath)) {
    Write-Host "  Backup not found: $BackupPath" -ForegroundColor Red
    exit 1
}

# Check 7-Zip
$7z = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $7z)) {
    Write-Host "  7-Zip required. Install: choco install 7zip" -ForegroundColor Red
    exit 1
}

Write-Host ""

# --- Step 1: Extract ---
Write-Host "  [1/8] Extracting archive...         " -NoNewline
if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
& $7z x $BackupPath -o"$tempExtract" -p"$Password" -y | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED (wrong password?)" -ForegroundColor Red
    exit 1
}
Write-Host "done" -ForegroundColor Green

# --- Step 2: Restore openclaw.json ---
Write-Host "  [2/8] Restoring openclaw.json...     " -NoNewline
$configSource = Get-ChildItem $tempExtract -Recurse -Filter "openclaw.json" | Select-Object -First 1
if ($configSource) {
    Copy-Item $configSource.FullName "$ocBase\openclaw.json" -Force
    Write-Host "done" -ForegroundColor Green
} else {
    Write-Host "not found in backup" -ForegroundColor Yellow
}

# --- Step 3: Restore secrets ---
Write-Host "  [3/8] Restoring secrets vault...     " -NoNewline
$secretsSource = Get-ChildItem $tempExtract -Recurse -Directory -Filter "secrets" | Select-Object -First 1
if ($secretsSource) {
    if (-not (Test-Path "$ocBase\secrets")) { New-Item -ItemType Directory -Path "$ocBase\secrets" -Force | Out-Null }
    Copy-Item "$($secretsSource.FullName)\*" "$ocBase\secrets\" -Recurse -Force
    Write-Host "done" -ForegroundColor Green
} else {
    Write-Host "not found in backup" -ForegroundColor Yellow
}

# --- Step 4: Deploy agent workspaces ---
Write-Host "  [4/8] Deploying agent workspaces...  " -NoNewline
$workspaces = Get-ChildItem $tempExtract -Recurse -Directory -Filter "workspace-*"
$agentCount = 0
foreach ($ws in $workspaces) {
    $targetPath = "$ocBase\$($ws.Name)"
    if (-not (Test-Path $targetPath)) { New-Item -ItemType Directory -Path $targetPath -Force | Out-Null }
    Copy-Item "$($ws.FullName)\*" "$targetPath\" -Recurse -Force
    $agentCount++
}
# Also restore main workspace
$mainWs = Get-ChildItem $tempExtract -Recurse -Directory -Filter "workspace" | Where-Object { $_.Name -eq "workspace" } | Select-Object -First 1
if ($mainWs) {
    if (-not (Test-Path "$ocBase\workspace")) { New-Item -ItemType Directory -Path "$ocBase\workspace" -Force | Out-Null }
    Copy-Item "$($mainWs.FullName)\*" "$ocBase\workspace\" -Recurse -Force
    $agentCount++
}
Write-Host "$agentCount workspaces restored" -ForegroundColor Green

# --- Step 5: Register gateway service ---
Write-Host "  [5/8] Registering gateway service... " -NoNewline
$nssmPath = Get-Command nssm -ErrorAction SilentlyContinue
if ($nssmPath) {
    $existing = sc.exe query OpenClawGateway 2>&1
    if ($existing -match "RUNNING|STOPPED|PAUSED") {
        Write-Host "already registered" -ForegroundColor DarkGray
    } else {
        $nodePath = (Get-Command node).Source
        $ocPath = "$env:APPDATA\npm\node_modules\openclaw\dist\index.js"
        if (Test-Path $ocPath) {
            nssm install OpenClawGateway $nodePath $ocPath "gateway" "start" | Out-Null
            nssm set OpenClawGateway AppDirectory $env:USERPROFILE | Out-Null
            nssm set OpenClawGateway Start SERVICE_AUTO_START | Out-Null
            Write-Host "done" -ForegroundColor Green
        } else {
            Write-Host "openclaw not found at expected path" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "nssm not installed (choco install nssm)" -ForegroundColor Yellow
}

# --- Step 6: Telegram config ---
Write-Host "  [6/8] Configuring Telegram...        " -NoNewline
$config = Get-Content "$ocBase\openclaw.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
if ($config -and $config.channels.telegram.enabled) {
    Write-Host "configured (from backup)" -ForegroundColor Green
} else {
    Write-Host "check openclaw.json manually" -ForegroundColor Yellow
}

# --- Step 7: Restore cron jobs ---
Write-Host "  [7/8] Restoring cron jobs...         " -NoNewline
$cronSource = Get-ChildItem $tempExtract -Recurse -Filter "cron*.json" -ErrorAction SilentlyContinue
if ($cronSource) {
    Write-Host "$($cronSource.Count) cron files found — import via openclaw cron" -ForegroundColor Green
} else {
    Write-Host "recreate manually (cron jobs don't survive gateway restarts)" -ForegroundColor Yellow
}

# --- Step 8: Sync scripts ---
Write-Host "  [8/8] Setting up sync scripts...     " -NoNewline
$syncScript = Get-ChildItem $tempExtract -Recurse -Filter "sync-workspace*" -ErrorAction SilentlyContinue
if ($syncScript) {
    Copy-Item $syncScript[0].FullName "$ocBase\" -Force
    Write-Host "done" -ForegroundColor Green
} else {
    Write-Host "configure manually for your network" -ForegroundColor Yellow
}

# --- Cleanup temp ---
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

# --- Summary ---
Write-Host ""
Write-Host "  Megaflare." -ForegroundColor Magenta
Write-Host ""

# Read config for summary
$config = Get-Content "$ocBase\openclaw.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
if ($config) {
    $agents = ($config.agents.list | ForEach-Object { $_.name -or $_.id }) -join ", "
    Write-Host "  Agents:    $agents" -ForegroundColor White
}

# Check gateway
$gwStatus = sc.exe query OpenClawGateway 2>&1
if ($gwStatus -match "RUNNING") {
    Write-Host "  Gateway:   RUNNING" -ForegroundColor Green
} elseif ($gwStatus -match "STOPPED") {
    Write-Host "  Gateway:   STOPPED (run: nssm start OpenClawGateway)" -ForegroundColor Yellow
} else {
    Write-Host "  Gateway:   not registered" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Your empire is restored." -ForegroundColor White
Write-Host "  Restart the gateway to go live." -ForegroundColor Yellow
Write-Host ""
