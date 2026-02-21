<#
.SYNOPSIS
  Odin - Zantetsuken. System cleanup in one slash.
.USAGE
  .\odin.ps1              Full sweep
  .\odin.ps1 -DryRun      Show what would be cut
  .\odin.ps1 -Chrome       Kill zombie Chrome only
  .\odin.ps1 -Sessions     Clean stale sessions only
  .\odin.ps1 -Logs         Rotate logs only
  .\odin.ps1 -Temp         Clean temp files only
#>

param(
    [switch]$DryRun,
    [switch]$Chrome,
    [switch]$Sessions,
    [switch]$Logs,
    [switch]$Temp,
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Continue"
$totalFreed = 0
$allTargets = -not ($Chrome -or $Sessions -or $Logs -or $Temp)

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

if ($Help) {
    Write-Host ""
    Write-Host "  Odin" -ForegroundColor Red
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\odin.ps1"
    Write-Host "    .\odin.ps1 -DryRun"
    Write-Host "    .\odin.ps1 -Chrome"
    Write-Host "    .\odin.ps1 -Sessions"
    Write-Host "    .\odin.ps1 -Logs"
    Write-Host "    .\odin.ps1 -Temp"
    Write-Host ""
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

function Format-Size($bytes) {
    if ($bytes -ge 1GB) { return "{0:N1} GB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N1} MB" -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return "{0:N1} KB" -f ($bytes / 1KB) }
    return "$bytes bytes"
}

# Get initial disk space
$drive = Get-PSDrive C
$beforeFree = $drive.Free

Write-Host ""
Write-Host "  Zantetsuken." -ForegroundColor Red
Write-Host ""

# --- Chrome Zombies ---
if ($allTargets -or $Chrome) {
    $zombies = Get-Process chrome -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowHandle -eq 0 -and $_.StartTime -lt (Get-Date).AddHours(-2)
    }
    $count = ($zombies | Measure-Object).Count
    if ($count -gt 0) {
        if ($DryRun) {
            Write-Host "  [DRY] Would kill $count Chrome zombies" -ForegroundColor DarkGray
        } else {
            $zombies | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Host "  Chrome zombies:     $count killed" -ForegroundColor Green
        }
    } else {
        Write-Host "  Chrome zombies:     none found" -ForegroundColor DarkGray
    }
}

# --- Stale Sessions ---
if ($allTargets -or $Sessions) {
    $ocPath = "$env:USERPROFILE\.openclaw"
    $sessionFiles = @()
    $sessionSize = 0
    
    # .deleted files
    $deleted = Get-ChildItem "$ocPath\sessions" -Filter "*.deleted" -Recurse -ErrorAction SilentlyContinue
    foreach ($f in $deleted) { $sessionFiles += $f; $sessionSize += $f.Length }
    
    # Stale completions (older than 7 days)
    $staleCompletions = Get-ChildItem "$ocPath\completions" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
    foreach ($f in $staleCompletions) { $sessionFiles += $f; $sessionSize += $f.Length }
    
    $count = $sessionFiles.Count
    if ($count -gt 0) {
        if ($DryRun) {
            Write-Host "  [DRY] Would purge $count session files ($(Format-Size $sessionSize))" -ForegroundColor DarkGray
        } else {
            foreach ($f in $sessionFiles) { Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue }
            $totalFreed += $sessionSize
            Write-Host "  Stale sessions:     $count purged ($(Format-Size $sessionSize))" -ForegroundColor Green
        }
    } else {
        Write-Host "  Stale sessions:     clean" -ForegroundColor DarkGray
    }
}

# --- Log Rotation ---
if ($allTargets -or $Logs) {
    $logDirs = @(
        "$env:USERPROFILE\.openclaw\logs",
        "$env:USERPROFILE\.openclaw\workspace\logs"
    )
    $logsCleaned = 0
    $logsSize = 0
    
    foreach ($dir in $logDirs) {
        if (-not (Test-Path $dir)) { continue }
        $oldLogs = Get-ChildItem $dir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
        foreach ($f in $oldLogs) {
            $logsSize += $f.Length
            $logsCleaned++
            if (-not $DryRun) {
                Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    if ($logsCleaned -gt 0) {
        if ($DryRun) {
            Write-Host "  [DRY] Would clean $logsCleaned log files ($(Format-Size $logsSize))" -ForegroundColor DarkGray
        } else {
            $totalFreed += $logsSize
            Write-Host "  Log rotation:       $logsCleaned files cleaned ($(Format-Size $logsSize))" -ForegroundColor Green
        }
    } else {
        Write-Host "  Log rotation:       nothing old" -ForegroundColor DarkGray
    }
}

# --- Temp Files ---
if ($allTargets -or $Temp) {
    $tempDirs = @(
        "$env:TEMP",
        "$env:USERPROFILE\AppData\Local\Temp"
    )
    $tempCleaned = 0
    $tempSize = 0
    
    foreach ($dir in $tempDirs) {
        if (-not (Test-Path $dir)) { continue }
        $oldTemp = Get-ChildItem $dir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) }
        foreach ($f in $oldTemp) {
            $tempSize += $f.Length
            $tempCleaned++
            if (-not $DryRun) {
                Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    # npm cache
    $npmCache = "$env:APPDATA\npm-cache"
    if (Test-Path $npmCache) {
        $cacheFiles = Get-ChildItem $npmCache -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) }
        foreach ($f in $cacheFiles) {
            $tempSize += $f.Length
            $tempCleaned++
            if (-not $DryRun) {
                Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    if ($tempCleaned -gt 0) {
        if ($DryRun) {
            Write-Host "  [DRY] Would clean $tempCleaned temp files ($(Format-Size $tempSize))" -ForegroundColor DarkGray
        } else {
            $totalFreed += $tempSize
            Write-Host "  Temp cleanup:       $tempCleaned files ($(Format-Size $tempSize))" -ForegroundColor Green
        }
    } else {
        Write-Host "  Temp cleanup:       already clean" -ForegroundColor DarkGray
    }
}

# --- Summary ---
Write-Host ""
$drive = Get-PSDrive C
$afterFree = $drive.Free

if ($DryRun) {
    Write-Host "  Dry run complete. No files were harmed." -ForegroundColor Yellow
} else {
    Write-Host "  Before: $(Format-Size $beforeFree) free" -ForegroundColor DarkGray
    Write-Host "  After:  $(Format-Size $afterFree) free" -ForegroundColor White
    if ($totalFreed -gt 0) {
        Write-Host "  Freed:  $(Format-Size $totalFreed)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "  Clean cut." -ForegroundColor Red
Write-Host ""
if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
