<#
.SYNOPSIS
  Shiva — Diamond Dust. System state snapshot + diff.
.USAGE
  .\shiva.ps1                    Take a snapshot
  .\shiva.ps1 -Name "pre-deploy" Named snapshot
  .\shiva.ps1 -Diff "pre-deploy" Compare snapshot to current state
  .\shiva.ps1 -List              List all snapshots
#>

param(
    [string]$Name,
    [string]$Diff,
    [switch]$List
)

$ErrorActionPreference = "Continue"
$snapshotDir = "$env:USERPROFILE\.armory\snapshots"
if (-not (Test-Path $snapshotDir)) { New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null }

# ===== CONFIGURE THIS =====
$repoSearchPaths = @(
    "D:\Code Repos"
    # Add more paths where your git repos live
)
# ==========================

function Get-Snapshot {
    $snap = @{}
    
    # Services
    $services = @()
    $svcList = sc.exe query state= all 2>$null
    $currentSvc = $null
    foreach ($line in ($svcList -split "`n")) {
        if ($line -match "SERVICE_NAME:\s+(.+)") { $currentSvc = $Matches[1].Trim() }
        if ($line -match "STATE\s+:\s+\d+\s+(\w+)" -and $currentSvc) {
            $services += @{ name = $currentSvc; state = $Matches[1] }
            $currentSvc = $null
        }
    }
    $snap["services"] = $services
    
    # Processes (top 20 by memory)
    $procs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 20 |
        ForEach-Object { @{ name = $_.ProcessName; memMB = [math]::Round($_.WorkingSet64/1MB,1); pid = $_.Id } }
    $snap["processes"] = @($procs)
    
    # Disk
    $disks = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } |
        ForEach-Object { @{ drive = $_.Name; freeGB = [math]::Round($_.Free/1GB,1); totalGB = [math]::Round(($_.Used+$_.Free)/1GB,1); pct = [math]::Round($_.Free/($_.Used+$_.Free)*100,1) } }
    $snap["disk"] = @($disks)
    
    # Ports
    $ports = netstat -an 2>$null | Select-String "LISTENING" | ForEach-Object {
        if ($_ -match ':(\d+)\s+.*LISTENING') { [int]$Matches[1] }
    } | Sort-Object -Unique
    $snap["ports"] = @($ports)
    
    # Git repos
    $repos = @()
    foreach ($searchPath in $repoSearchPaths) {
        if (-not (Test-Path $searchPath)) { continue }
        Get-ChildItem $searchPath -Directory | ForEach-Object {
            $gitDir = Join-Path $_.FullName ".git"
            if (Test-Path $gitDir) {
                Push-Location $_.FullName
                $branch = git rev-parse --abbrev-ref HEAD 2>$null
                $status = git status --porcelain 2>$null
                $dirty = ($status | Measure-Object).Count
                $repos += @{ name = $_.Name; branch = $branch; dirty = $dirty }
                Pop-Location
            }
        }
    }
    $snap["repos"] = @($repos)
    
    # Environment variables (user-level, masked)
    $envVars = @()
    [System.Environment]::GetEnvironmentVariables("User").GetEnumerator() | ForEach-Object {
        $masked = if ($_.Value.Length -gt 8) { $_.Value.Substring(0,4) + "..." + $_.Value.Substring($_.Value.Length-3) } else { "***" }
        $envVars += @{ name = $_.Key; masked = $masked; length = $_.Value.Length }
    }
    $snap["envVars"] = @($envVars)
    
    # Tools
    $tools = @()
    foreach ($cmd in @("node", "python", "python3", "git", "nssm", "7z")) {
        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($found) {
            $ver = & $cmd --version 2>$null | Select-Object -First 1
            $tools += @{ name = $cmd; version = "$ver".Trim() }
        }
    }
    $snap["tools"] = @($tools)
    
    # Uptime
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        $uptime = (Get-Date) - $os.LastBootUpTime
        $snap["uptime"] = "$([math]::Floor($uptime.TotalDays))d $($uptime.Hours)h $($uptime.Minutes)m"
    }
    
    $snap["timestamp"] = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    return $snap
}

# --- LIST ---
if ($List) {
    Write-Host ""
    Write-Host "  Snapshots" -ForegroundColor Cyan
    Write-Host ""
    $files = Get-ChildItem $snapshotDir -Filter "*.json" | Sort-Object LastWriteTime -Descending
    if ($files.Count -eq 0) {
        Write-Host "  (none yet)" -ForegroundColor DarkGray
    } else {
        foreach ($f in $files) {
            $size = "{0:N0} KB" -f ($f.Length / 1KB)
            Write-Host "    $($f.BaseName.PadRight(30)) $size" -ForegroundColor White
        }
    }
    Write-Host ""
    exit 0
}

# --- DIFF ---
if ($Diff) {
    $diffPath = Join-Path $snapshotDir "$Diff.json"
    if (-not (Test-Path $diffPath)) {
        Write-Host "  Snapshot not found: $Diff" -ForegroundColor Red
        exit 1
    }
    
    $old = Get-Content $diffPath -Raw | ConvertFrom-Json
    $now = Get-Snapshot
    $changes = 0
    
    Write-Host ""
    Write-Host "  Diamond Dust - Diff" -ForegroundColor Cyan
    Write-Host "  Comparing: $Diff -> now" -ForegroundColor DarkGray
    Write-Host ""
    
    # Disk changes
    $diskChanges = $false
    foreach ($d in $now["disk"]) {
        $oldDisk = $old.disk | Where-Object { $_.drive -eq $d.drive }
        if ($oldDisk -and [math]::Abs($oldDisk.freeGB - $d.freeGB) -gt 0.5) {
            if (-not $diskChanges) { Write-Host "  DISK" -ForegroundColor White; $diskChanges = $true }
            $delta = $d.freeGB - $oldDisk.freeGB
            $sign = if ($delta -gt 0) { "+" } else { "" }
            Write-Host "    $($d.drive):  $($oldDisk.freeGB) GB -> $($d.freeGB) GB  ($sign$([math]::Round($delta,1)) GB)" -ForegroundColor $(if ($delta -lt 0) { "Red" } else { "Green" })
            $changes++
        }
    }
    if ($diskChanges) { Write-Host "" }
    
    # Repo changes
    $repoChanges = $false
    foreach ($r in $now["repos"]) {
        $oldRepo = $old.repos | Where-Object { $_.name -eq $r.name }
        if ($oldRepo) {
            if ($oldRepo.dirty -ne $r.dirty) {
                if (-not $repoChanges) { Write-Host "  GIT REPOS" -ForegroundColor White; $repoChanges = $true }
                $oldState = if ($oldRepo.dirty -eq 0) { "clean" } else { "dirty ($($oldRepo.dirty))" }
                $newState = if ($r.dirty -eq 0) { "clean" } else { "dirty ($($r.dirty))" }
                Write-Host "    $($r.name.PadRight(24)) $oldState -> $newState" -ForegroundColor Yellow
                $changes++
            }
        } else {
            if (-not $repoChanges) { Write-Host "  GIT REPOS" -ForegroundColor White; $repoChanges = $true }
            Write-Host "    + $($r.name)  (new)" -ForegroundColor Green
            $changes++
        }
    }
    if ($repoChanges) { Write-Host "" }
    
    # Env var changes
    $envChanges = $false
    foreach ($e in $now["envVars"]) {
        $oldEnv = $old.envVars | Where-Object { $_.name -eq $e.name }
        if (-not $oldEnv) {
            if (-not $envChanges) { Write-Host "  ENV VARS" -ForegroundColor White; $envChanges = $true }
            Write-Host "    + $($e.name)  (added)" -ForegroundColor Green
            $changes++
        } elseif ($oldEnv.length -ne $e.length) {
            if (-not $envChanges) { Write-Host "  ENV VARS" -ForegroundColor White; $envChanges = $true }
            Write-Host "    ~ $($e.name)  (changed)" -ForegroundColor Yellow
            $changes++
        }
    }
    foreach ($e in $old.envVars) {
        $nowEnv = $now["envVars"] | Where-Object { $_.name -eq $e.name }
        if (-not $nowEnv) {
            if (-not $envChanges) { Write-Host "  ENV VARS" -ForegroundColor White; $envChanges = $true }
            Write-Host "    - $($e.name)  (removed)" -ForegroundColor Red
            $changes++
        }
    }
    if ($envChanges) { Write-Host "" }
    
    Write-Host "  ─────────────────────────" -ForegroundColor DarkGray
    if ($changes -eq 0) {
        Write-Host "  No changes detected." -ForegroundColor Green
    } else {
        Write-Host "  $changes change$(if($changes -gt 1){'s'}) detected." -ForegroundColor Yellow
    }
    Write-Host ""
    exit 0
}

# --- SNAPSHOT ---
Write-Host ""
Write-Host "  Diamond Dust" -ForegroundColor Cyan
Write-Host ""

$snap = Get-Snapshot

# Display summary
$running = ($snap["services"] | Where-Object { $_.state -eq "RUNNING" }).Count
$stopped = ($snap["services"] | Where-Object { $_.state -eq "STOPPED" }).Count
Write-Host "  SERVICES        $running running, $stopped stopped" -ForegroundColor White

$totalMem = ($snap["processes"] | Measure-Object -Property memMB -Sum).Sum
$topProc = $snap["processes"] | Select-Object -First 3
$topStr = ($topProc | ForEach-Object { "$($_.name) ($($_.memMB) MB)" }) -join ", "
Write-Host "  PROCESSES       $($snap["processes"].Count) captured, top: $topStr" -ForegroundColor White

$diskStr = ($snap["disk"] | ForEach-Object { "$($_.drive): $($_.freeGB) GB ($($_.pct)%)" }) -join " | "
Write-Host "  DISK            $diskStr" -ForegroundColor White

Write-Host "  PORTS           $($snap["ports"].Count) listening" -ForegroundColor White

$cleanRepos = ($snap["repos"] | Where-Object { $_.dirty -eq 0 }).Count
$dirtyRepos = ($snap["repos"] | Where-Object { $_.dirty -gt 0 }).Count
$dirtyNames = ($snap["repos"] | Where-Object { $_.dirty -gt 0 } | ForEach-Object { "$($_.name) +$($_.dirty)" }) -join ", "
$repoStr = "$cleanRepos clean, $dirtyRepos dirty"
if ($dirtyNames) { $repoStr += " ($dirtyNames)" }
Write-Host "  GIT REPOS       $repoStr" -ForegroundColor White

Write-Host "  ENV VARS        $($snap["envVars"].Count) user variables set" -ForegroundColor White

$toolStr = ($snap["tools"] | ForEach-Object { "$($_.name) $($_.version)" }) -join ", "
Write-Host "  TOOLS           $toolStr" -ForegroundColor White

if ($snap["uptime"]) { Write-Host "  UPTIME          $($snap["uptime"])" -ForegroundColor White }

# Save
$snapName = if ($Name) { $Name } else { Get-Date -Format "yyyy-MM-dd_HH-mm-ss" }
$snapPath = Join-Path $snapshotDir "$snapName.json"
$snap | ConvertTo-Json -Depth 10 | Set-Content $snapPath -Encoding UTF8

Write-Host ""
Write-Host "  Saved to: $snapPath" -ForegroundColor DarkGray
Write-Host ""
