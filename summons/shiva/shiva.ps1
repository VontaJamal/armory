param(
    [string]$Name,
    [string]$Diff,
    [switch]$List
)

$ErrorActionPreference = "Continue"
$snapshotDir = Join-Path $env:USERPROFILE ".armory\snapshots"
if (-not (Test-Path $snapshotDir)) { New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null }

$repoSearchPaths = @("D:\Code Repos")

function Get-Snapshot {
    $snap = @{}
    
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
    
    $procs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 20 |
        ForEach-Object { @{ name = $_.ProcessName; memMB = [math]::Round($_.WorkingSet64/1MB,1); pid = $_.Id } }
    $snap["processes"] = @($procs)
    
    $disks = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } |
        ForEach-Object { @{ drive = $_.Name; freeGB = [math]::Round($_.Free/1GB,1); totalGB = [math]::Round(($_.Used+$_.Free)/1GB,1); pct = [math]::Round($_.Free/($_.Used+$_.Free)*100,1) } }
    $snap["disk"] = @($disks)
    
    $ports = @()
    netstat -an 2>$null | Select-String "LISTENING" | ForEach-Object {
        if ($_ -match ':(\d+)\s+.*LISTENING') { $ports += [int]$Matches[1] }
    }
    $snap["ports"] = @($ports | Sort-Object -Unique)
    
    $repos = @()
    foreach ($searchPath in $repoSearchPaths) {
        if (-not (Test-Path $searchPath)) { continue }
        Get-ChildItem $searchPath -Directory | ForEach-Object {
            $gitDir = Join-Path $_.FullName ".git"
            if (Test-Path $gitDir) {
                Push-Location $_.FullName
                $branch = git rev-parse --abbrev-ref HEAD 2>$null
                $status = git status --porcelain 2>$null
                $dirty = @($status).Count
                if (-not $status) { $dirty = 0 }
                $repos += @{ name = $_.Name; branch = $branch; dirty = $dirty }
                Pop-Location
            }
        }
    }
    $snap["repos"] = @($repos)
    
    $envVars = @()
    [System.Environment]::GetEnvironmentVariables("User").GetEnumerator() | ForEach-Object {
        $val = $_.Value
        if ($val.Length -gt 8) { $masked = $val.Substring(0,4) + "****" } else { $masked = "****" }
        $envVars += @{ name = $_.Key; masked = $masked; length = $val.Length }
    }
    $snap["envVars"] = @($envVars)
    
    $tools = @()
    foreach ($cmd in @("node", "python", "git", "nssm")) {
        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($found) {
            $ver = ""
            try { $ver = (& $cmd --version 2>$null | Select-Object -First 1).Trim() } catch {}
            $tools += @{ name = $cmd; version = $ver }
        }
    }
    $snap["tools"] = @($tools)
    
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        $uptime = (Get-Date) - $os.LastBootUpTime
        $snap["uptime"] = [string]([math]::Floor($uptime.TotalDays)) + "d " + $uptime.Hours + "h"
    }
    
    $snap["timestamp"] = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    return $snap
}

if ($List) {
    Write-Host ""
    Write-Host "  Snapshots" -ForegroundColor Cyan
    Write-Host ""
    $files = Get-ChildItem $snapshotDir -Filter "*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if (-not $files -or $files.Count -eq 0) {
        Write-Host "  (none yet)" -ForegroundColor DarkGray
    } else {
        foreach ($f in $files) {
            $size = [math]::Round($f.Length / 1KB, 0)
            Write-Host ("    " + $f.BaseName.PadRight(30) + " " + $size + " KB") -ForegroundColor White
        }
    }
    Write-Host ""
    exit 0
}

if ($Diff) {
    $diffPath = Join-Path $snapshotDir ($Diff + ".json")
    if (-not (Test-Path $diffPath)) {
        Write-Host "  Snapshot not found: $Diff" -ForegroundColor Red
        exit 1
    }
    $old = Get-Content $diffPath -Raw | ConvertFrom-Json
    $now = Get-Snapshot
    $changes = 0
    
    Write-Host ""
    Write-Host "  Diamond Dust - Diff" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($d in $now["disk"]) {
        $oldDisk = $old.disk | Where-Object { $_.drive -eq $d.drive }
        if ($oldDisk -and [math]::Abs($oldDisk.freeGB - $d.freeGB) -gt 0.5) {
            $delta = [math]::Round($d.freeGB - $oldDisk.freeGB, 1)
            Write-Host ("  DISK  " + $d.drive + ": " + $oldDisk.freeGB + " GB -> " + $d.freeGB + " GB (" + $delta + " GB)") -ForegroundColor Yellow
            $changes++
        }
    }
    
    foreach ($r in $now["repos"]) {
        $oldRepo = $old.repos | Where-Object { $_.name -eq $r.name }
        if ($oldRepo -and $oldRepo.dirty -ne $r.dirty) {
            Write-Host ("  REPO  " + $r.name + ": " + $oldRepo.dirty + " dirty -> " + $r.dirty + " dirty") -ForegroundColor Yellow
            $changes++
        }
    }
    
    foreach ($e in $now["envVars"]) {
        $oldEnv = $old.envVars | Where-Object { $_.name -eq $e.name }
        if (-not $oldEnv) {
            Write-Host ("  ENV   + " + $e.name + " (added)") -ForegroundColor Green
            $changes++
        } elseif ($oldEnv.length -ne $e.length) {
            Write-Host ("  ENV   ~ " + $e.name + " (changed)") -ForegroundColor Yellow
            $changes++
        }
    }
    
    Write-Host ""
    Write-Host "  -------------------------" -ForegroundColor DarkGray
    if ($changes -eq 0) {
        Write-Host "  No changes detected." -ForegroundColor Green
    } else {
        Write-Host "  $changes change(s) detected." -ForegroundColor Yellow
    }
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "  Diamond Dust" -ForegroundColor Cyan
Write-Host ""

$snap = Get-Snapshot

$running = @($snap["services"] | Where-Object { $_.state -eq "RUNNING" }).Count
$stopped = @($snap["services"] | Where-Object { $_.state -eq "STOPPED" }).Count
Write-Host "  SERVICES        $running running, $stopped stopped" -ForegroundColor White

$topProc = $snap["processes"] | Select-Object -First 3
$topParts = @()
foreach ($p in $topProc) { $topParts += ($p.name + " " + $p.memMB + "MB") }
Write-Host ("  PROCESSES       " + $snap["processes"].Count + " captured, top: " + ($topParts -join ", ")) -ForegroundColor White

$diskParts = @()
foreach ($d in $snap["disk"]) { $diskParts += ($d.drive + ": " + $d.freeGB + "GB") }
Write-Host ("  DISK            " + ($diskParts -join ", ")) -ForegroundColor White

Write-Host ("  PORTS           " + $snap["ports"].Count + " listening") -ForegroundColor White

$cleanRepos = @($snap["repos"] | Where-Object { $_.dirty -eq 0 }).Count
$dirtyRepos = @($snap["repos"] | Where-Object { $_.dirty -gt 0 }).Count
Write-Host "  GIT REPOS       $cleanRepos clean, $dirtyRepos dirty" -ForegroundColor White

Write-Host ("  ENV VARS        " + $snap["envVars"].Count + " user variables") -ForegroundColor White

$toolParts = @()
foreach ($t in $snap["tools"]) { $toolParts += ($t.name + " " + $t.version) }
Write-Host ("  TOOLS           " + ($toolParts -join ", ")) -ForegroundColor White

if ($snap["uptime"]) { Write-Host ("  UPTIME          " + $snap["uptime"]) -ForegroundColor White }

$snapName = if ($Name) { $Name } else { Get-Date -Format "yyyy-MM-dd_HH-mm-ss" }
$snapPath = Join-Path $snapshotDir ($snapName + ".json")
$snap | ConvertTo-Json -Depth 10 | Set-Content $snapPath -Encoding UTF8

Write-Host ""
Write-Host "  Saved: $snapPath" -ForegroundColor DarkGray
Write-Host ""
