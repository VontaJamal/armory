<#
.SYNOPSIS
    Shiva - Diamond Dust - System state snapshot & diff
.EXAMPLE
    .\shiva.ps1              Take a snapshot
    .\shiva.ps1 --diff       Compare last two snapshots
    .\shiva.ps1 --list       List all snapshots
#>
param(
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$snapshotDir = Join-Path $env:USERPROFILE ".shiva\snapshots"
$isDiff = $args -contains "--diff"
$isList = $args -contains "--list"

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

function Write-Banner {
    Write-Host ""
    Write-Host "  * " -NoNewline -ForegroundColor Cyan
    Write-Host "Diamond Dust" -ForegroundColor White
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
}

if ($Help) {
    Write-Host @"

  * Shiva - Diamond Dust
  Freeze your system state. Compare snapshots to find what changed.

  Usage:
    .\shiva.ps1              Take a snapshot
    .\shiva.ps1 --diff       Compare last two snapshots
    .\shiva.ps1 --diff a b   Compare two specific files
    .\shiva.ps1 --list       List all snapshots
    .\shiva.ps1 -Help        This message

"@
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

# Ensure snapshot dir exists
if (-not (Test-Path $snapshotDir)) { New-Item -Path $snapshotDir -ItemType Directory -Force | Out-Null }

Write-Banner

# -- List ------------------------------------------------
if ($isList) {
    $files = Get-ChildItem $snapshotDir -Filter "*.json" | Sort-Object Name -Descending
    if ($files.Count -eq 0) {
        Write-Host "`n  No snapshots yet. Run .\shiva.ps1 to create one." -ForegroundColor Yellow
    } else {
        Write-Host ""
        foreach ($f in $files) {
            $size = [math]::Round($f.Length / 1KB, 1)
            Write-Host "    $($f.BaseName)" -NoNewline -ForegroundColor White
            Write-Host "  (${size} KB)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

# -- Diff ------------------------------------------------
if ($isDiff) {
    $diffIdx = [Array]::IndexOf($args, "--diff")
    $diffArgs = @($args | Select-Object -Skip ($diffIdx + 1) | Where-Object { $_ -notmatch "^--" })

    if ($diffArgs.Count -ge 2) {
        $file1 = $diffArgs[0]; $file2 = $diffArgs[1]
        if (-not (Test-Path $file1)) { $file1 = Join-Path $snapshotDir $file1 }
        if (-not (Test-Path $file2)) { $file2 = Join-Path $snapshotDir $file2 }
    } else {
        $files = Get-ChildItem $snapshotDir -Filter "*.json" | Sort-Object Name -Descending | Select-Object -First 2
        if ($files.Count -lt 2) {
            Write-Host "`n  Need at least 2 snapshots to diff. Take more snapshots first." -ForegroundColor Yellow
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            Write-Host ""; exit 1
        }
        $file1 = $files[1].FullName; $file2 = $files[0].FullName
    }

    $old = Get-Content $file1 -Raw | ConvertFrom-Json
    $new = Get-Content $file2 -Raw | ConvertFrom-Json

    Write-Host "`n  Comparing:" -ForegroundColor DarkGray
    Write-Host "    $(Split-Path $file1 -Leaf) -> $(Split-Path $file2 -Leaf)" -ForegroundColor White

    # Service diff
    $svcChanges = @()
    $oldSvcs = @{}; $old.services | ForEach-Object { $oldSvcs[$_.name] = $_.status }
    $newSvcs = @{}; $new.services | ForEach-Object { $newSvcs[$_.name] = $_.status }
    foreach ($k in $newSvcs.Keys) {
        if ($oldSvcs.ContainsKey($k) -and $oldSvcs[$k] -ne $newSvcs[$k]) {
            $svcChanges += @{ name = $k; from = $oldSvcs[$k]; to = $newSvcs[$k] }
        }
    }
    if ($svcChanges.Count -gt 0) {
        Write-Host "`n  SERVICES" -ForegroundColor Cyan
        foreach ($c in $svcChanges) {
            $color = if ($c.to -eq "Running") { "Green" } else { "Red" }
            Write-Host "    $($c.name.PadRight(30))" -NoNewline -ForegroundColor White
            Write-Host "$($c.from) -> $($c.to)" -ForegroundColor $color
        }
    }

    # Disk diff
    $diskChanges = @()
    $oldDisks = @{}; $old.disk | ForEach-Object { $oldDisks[$_.drive] = $_.freeGB }
    $newDisks = @{}; $new.disk | ForEach-Object { $newDisks[$_.drive] = $_.freeGB }
    foreach ($k in $newDisks.Keys) {
        if ($oldDisks.ContainsKey($k)) {
            $delta = [math]::Round($newDisks[$k] - $oldDisks[$k], 1)
            if ([math]::Abs($delta) -ge 0.5) {
                $diskChanges += @{ drive = $k; from = $oldDisks[$k]; to = $newDisks[$k]; delta = $delta }
            }
        }
    }
    if ($diskChanges.Count -gt 0) {
        Write-Host "`n  DISK" -ForegroundColor Cyan
        foreach ($c in $diskChanges) {
            $sign = if ($c.delta -gt 0) { "+" } else { "" }
            $color = if ($c.delta -lt 0) { "Yellow" } else { "Green" }
            Write-Host "    $($c.drive)  $($c.from) GB -> $($c.to) GB" -NoNewline -ForegroundColor White
            Write-Host "  (${sign}$($c.delta) GB)" -ForegroundColor $color
        }
    }

    # Port diff
    $oldPorts = @($old.ports | ForEach-Object { $_.port }); $newPorts = @($new.ports | ForEach-Object { $_.port })
    $addedPorts = $newPorts | Where-Object { $_ -notin $oldPorts }
    $removedPorts = $oldPorts | Where-Object { $_ -notin $newPorts }
    if ($addedPorts.Count -gt 0 -or $removedPorts.Count -gt 0) {
        Write-Host "`n  PORTS" -ForegroundColor Cyan
        foreach ($p in $addedPorts) {
            $proc = ($new.ports | Where-Object { $_.port -eq $p }).process
            Write-Host "    + :$p" -NoNewline -ForegroundColor Green
            Write-Host "  now listening ($proc)" -ForegroundColor DarkGray
        }
        foreach ($p in $removedPorts) {
            Write-Host "    - :$p" -NoNewline -ForegroundColor Red
            Write-Host "  no longer listening" -ForegroundColor DarkGray
        }
    }

    # Process diff
    $oldProcs = @($old.processes | ForEach-Object { $_.name }) | Sort-Object -Unique
    $newProcs = @($new.processes | ForEach-Object { $_.name }) | Sort-Object -Unique
    $addedProcs = $newProcs | Where-Object { $_ -notin $oldProcs }
    $removedProcs = $oldProcs | Where-Object { $_ -notin $newProcs }
    if ($addedProcs.Count -gt 0 -or $removedProcs.Count -gt 0) {
        Write-Host "`n  PROCESSES" -ForegroundColor Cyan
        if ($addedProcs.Count -gt 0) {
            Write-Host "    + $($addedProcs.Count) new: $($addedProcs[0..([Math]::Min(4,$addedProcs.Count-1))] -join ', ')" -ForegroundColor Green
        }
        if ($removedProcs.Count -gt 0) {
            Write-Host "    - $($removedProcs.Count) gone: $($removedProcs[0..([Math]::Min(4,$removedProcs.Count-1))] -join ', ')" -ForegroundColor Red
        }
    }

    if ($svcChanges.Count -eq 0 -and $diskChanges.Count -eq 0 -and $addedPorts.Count -eq 0 -and $removedPorts.Count -eq 0 -and $addedProcs.Count -eq 0 -and $removedProcs.Count -eq 0) {
        Write-Host "`n  No significant changes detected." -ForegroundColor Green
    }

    Write-Host ""
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

# -- Snapshot --------------------------------------------
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outFile = Join-Path $snapshotDir "$timestamp.json"

Write-Host "`n  Capturing system state..." -ForegroundColor DarkGray

$snapshot = [ordered]@{
    timestamp = (Get-Date -Format "o")
    hostname  = $env:COMPUTERNAME
    os        = (Get-CimInstance Win32_OperatingSystem).Caption
    uptime    = ((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).ToString("d\.hh\:mm\:ss")
    lastBoot  = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString("o")

    services  = @(Get-Service | Where-Object { $_.StartType -ne 'Disabled' } | ForEach-Object {
        [ordered]@{ name = $_.Name; status = $_.Status.ToString(); startType = $_.StartType.ToString() }
    })

    processes = @(Get-Process | Group-Object Name | ForEach-Object {
        $mem = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum
        [ordered]@{ name = $_.Name; count = $_.Count; memoryMB = [math]::Round($mem / 1MB, 1) }
    } | Sort-Object { $_.memoryMB } -Descending | Select-Object -First 50)

    ports     = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
        $proc = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name
        [ordered]@{ port = $_.LocalPort; address = $_.LocalAddress; process = $proc; pid = $_.OwningProcess }
    } | Sort-Object { $_.port } -Unique)

    disk      = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        [ordered]@{
            drive   = $_.DeviceID
            freeGB  = [math]::Round($_.FreeSpace / 1GB, 1)
            totalGB = [math]::Round($_.Size / 1GB, 1)
            pctFree = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
        }
    })

    envVars   = @([System.Environment]::GetEnvironmentVariables("User").Keys | Sort-Object)

    network   = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -ne "127.0.0.1" } | ForEach-Object {
        [ordered]@{ interface = $_.InterfaceAlias; ip = $_.IPAddress; prefix = $_.PrefixLength }
    })
}

$snapshot | ConvertTo-Json -Depth 5 | Set-Content $outFile -Encoding UTF8

$svcCount = $snapshot.services.Count
$procCount = $snapshot.processes.Count
$portCount = $snapshot.ports.Count
$diskCount = $snapshot.disk.Count

Write-Host ""
Write-Host "  Snapshot saved: " -NoNewline -ForegroundColor Green
Write-Host $outFile -ForegroundColor White
Write-Host "  Captured: $svcCount services, $procCount processes, $portCount ports, $diskCount drives" -ForegroundColor DarkGray
Write-Host ""
if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
