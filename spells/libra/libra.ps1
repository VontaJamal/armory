<#
.SYNOPSIS
  Libra - daily operations intelligence report.
#>

param(
    [switch]$Telegram,
    [string]$Output,
    [switch]$NoRepoSummary,
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Continue"

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

$config = @{
    telegramBotToken = $env:TELEGRAM_BOT_TOKEN
    telegramChatId = $env:TELEGRAM_CHAT_ID
    reposFile = "~/.armory/repos.json"
    apiKeyEnvVars = @("ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GITHUB_TOKEN", "GOOGLE_API_KEY")
    serviceNames = @("OpenClawGateway", "CryptoPipeline", "CryptoAlertForwarder", "TradingDashboard")
}

function Show-Help {
    Write-Host ""
    Write-Host "  Libra" -ForegroundColor Magenta
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\libra.ps1"
    Write-Host "    .\\libra.ps1 -Output C:\\Reports\\libra.txt"
    Write-Host "    .\\libra.ps1 -Telegram"
    Write-Host "    .\\libra.ps1 -NoRepoSummary"
    Write-Host ""
}

function Expand-ArmoryPath {
    param([string]$PathValue)
    if (-not $PathValue) { return $PathValue }

    $expanded = [Environment]::ExpandEnvironmentVariables($PathValue)
    if ($expanded.StartsWith("~")) {
        $trimmed = $expanded.Substring(1).TrimStart('/', '\')
        if ($trimmed) {
            return (Join-Path $HOME $trimmed)
        }
        return $HOME
    }
    return $expanded
}

function Get-RepoPulseRecord {
    param([string]$InputPath)

    $expanded = Expand-ArmoryPath -PathValue $InputPath
    $resolvedPath = $expanded
    if (Test-Path $expanded) {
        $resolvedPath = (Resolve-Path $expanded).Path
    }

    $record = [ordered]@{
        Repo = (Split-Path $resolvedPath -Leaf)
        Path = $resolvedPath
        State = "missing"
        Ahead = 0
        Behind = 0
        Dirty = 0
        Untracked = 0
    }

    if (-not $record.Repo) { $record.Repo = $InputPath }
    if (-not (Test-Path $expanded)) { return [PSCustomObject]$record }
    if (-not (Test-Path (Join-Path $expanded ".git"))) {
        $record.State = "not-git"
        return [PSCustomObject]$record
    }

    $record.State = "ok"

    $statusLines = @(git -C $expanded status --porcelain 2>$null)
    if ($LASTEXITCODE -eq 0) {
        foreach ($line in $statusLines) {
            if (-not $line) { continue }
            if ($line.StartsWith("??")) { $record.Untracked++ } else { $record.Dirty++ }
        }
    }

    $upstream = git -C $expanded rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>$null
    if ($LASTEXITCODE -eq 0 -and $upstream) {
        $aheadBehind = git -C $expanded rev-list --left-right --count "@{upstream}...HEAD" 2>$null
        if ($LASTEXITCODE -eq 0 -and $aheadBehind) {
            $parts = $aheadBehind.Trim() -split "\s+"
            if ($parts.Count -ge 2) {
                $record.Behind = [int]$parts[0]
                $record.Ahead = [int]$parts[1]
            }
        }
    }

    return [PSCustomObject]$record
}

if ($Help) {
    Show-Help
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

$lines = @()
$now = Get-Date
$lines += "LIBRA OPERATIONS REPORT"
$lines += "Generated: $($now.ToString('yyyy-MM-dd HH:mm:ss'))"
$lines += "Host: $env:COMPUTERNAME"
$lines += ""

# Uptime and boot
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    $lines += "Uptime: $([int]$uptime.TotalHours)h $($uptime.Minutes)m"
    $lines += "Last boot: $($os.LastBootUpTime)"
} catch {
    $lines += "Uptime: unavailable"
}
$lines += ""

# Disk summary
$lines += "Disk summary:"
try {
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($d in $drives) {
        $free = [math]::Round($d.FreeSpace / 1GB, 1)
        $total = [math]::Round($d.Size / 1GB, 1)
        $pct = if ($d.Size -gt 0) { [math]::Round(($d.FreeSpace / $d.Size) * 100, 1) } else { 0 }
        $lines += "  $($d.DeviceID) - free $free GB / $total GB ($pct`%)"
    }
} catch {
    $lines += "  disk query failed"
}
$lines += ""

# Services
$lines += "Service status:"
foreach ($svc in $config.serviceNames) {
    try {
        $status = (Get-Service -Name $svc -ErrorAction Stop).Status
        $lines += "  $svc - $status"
    } catch {
        $lines += "  $svc - not found"
    }
}
$lines += ""

# Top memory processes
$lines += "Top 5 processes by memory:"
try {
    $top = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5
    foreach ($p in $top) {
        $mb = [math]::Round($p.WorkingSet64 / 1MB, 1)
        $lines += "  $($p.Name) - $mb MB"
    }
} catch {
    $lines += "  process query failed"
}
$lines += ""

# Pending updates
$lines += "Pending Windows updates:"
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $result = $searcher.Search("IsInstalled=0 and Type='Software'")
    $lines += "  $($result.Updates.Count)"
} catch {
    $lines += "  unavailable"
}
$lines += ""

# API key status
$lines += "API key status:"
foreach ($k in $config.apiKeyEnvVars) {
    $v = [System.Environment]::GetEnvironmentVariable($k, "User")
    if (-not $v) { $v = [System.Environment]::GetEnvironmentVariable($k, "Process") }
    if ($v) {
        $lines += "  $k - set"
    } else {
        $lines += "  $k - not set"
    }
}
$lines += ""

# Repo pulse summary (derived from Chronicle logic)
if ($NoRepoSummary) {
    $lines += "Repo pulse: skipped (--NoRepoSummary)"
    $lines += ""
} else {
    $lines += "Repo pulse:"
    $reposFilePath = Expand-ArmoryPath -PathValue $config.reposFile
    if (-not (Test-Path $reposFilePath)) {
        $lines += "  repos file not found: $reposFilePath"
        $lines += ""
    } else {
        $repoTargets = @()
        try {
            $repoConfig = Get-Content -Path $reposFilePath -Raw | ConvertFrom-Json
            foreach ($entry in @($repoConfig.repos)) {
                if ($entry) { $repoTargets += [string]$entry }
            }
        } catch {
            $lines += "  repos file parse failed"
            $lines += ""
            $repoTargets = @()
        }

        if ($repoTargets.Count -eq 0) {
            $lines += "  no repos configured in allowlist"
            $lines += ""
        } else {
            $pulse = @()
            foreach ($repoTarget in ($repoTargets | Sort-Object -Unique)) {
                $pulse += Get-RepoPulseRecord -InputPath $repoTarget
            }

            $dirtyRepos = @($pulse | Where-Object { $_.State -eq "ok" -and ($_.Dirty -gt 0 -or $_.Untracked -gt 0) }).Count
            $behindRepos = @($pulse | Where-Object { $_.State -eq "ok" -and $_.Behind -gt 0 }).Count
            $missingRepos = @($pulse | Where-Object { $_.State -eq "missing" }).Count
            $notGitRepos = @($pulse | Where-Object { $_.State -eq "not-git" }).Count

            $lines += "  repos: $($pulse.Count) (dirty: $dirtyRepos, behind: $behindRepos, missing: $missingRepos, not-git: $notGitRepos)"
            foreach ($r in ($pulse | Select-Object -First 5)) {
                $lines += "  $($r.Repo) - state=$($r.State), dirty=$($r.Dirty), untracked=$($r.Untracked), ahead=$($r.Ahead), behind=$($r.Behind)"
            }
            if ($pulse.Count -gt 5) {
                $lines += "  ... $($pulse.Count - 5) more repos omitted"
            }
            $lines += ""
        }
    }
}

$report = ($lines -join "`r`n")

if ($Output) {
    $outDir = Split-Path $Output -Parent
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -Path $Output -Value $report -Encoding UTF8
    Write-Host "  report written: $Output" -ForegroundColor Green
} else {
    Write-Output $report
}

if ($Telegram) {
    if ($config.telegramBotToken -and $config.telegramChatId) {
        try {
            $body = @{ chat_id = $config.telegramChatId; text = $report } | ConvertTo-Json
            Invoke-RestMethod -Uri ("https://api.telegram.org/bot{0}/sendMessage" -f $config.telegramBotToken) -Method Post -ContentType "application/json" -Body $body | Out-Null
            Write-Host "  telegram sent" -ForegroundColor Green
        } catch {
            Write-Host "  telegram failed" -ForegroundColor Yellow
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            exit 1
        }
    } else {
        Write-Host "  telegram not configured" -ForegroundColor Yellow
        if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
        exit 1
    }
}

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
