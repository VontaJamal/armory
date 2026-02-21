<#
.SYNOPSIS
  Libra - daily operations intelligence report.
#>

param(
    [switch]$Telegram,
    [string]$Output,
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
    gitRepoDirs = @("D:\Code Repos")
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
    Write-Host ""
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

# Git status
$lines += "Git working tree status:"
$repoCount = 0
foreach ($root in $config.gitRepoDirs) {
    if (-not (Test-Path $root)) { continue }
    $repos = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue
    foreach ($r in $repos) {
        if (-not (Test-Path (Join-Path $r.FullName ".git"))) { continue }
        $repoCount++
        $dirty = git -C $r.FullName status --porcelain 2>$null
        if ($dirty) {
            $lines += "  $($r.Name) - uncommitted changes"
        }
    }
}
if ($repoCount -eq 0) {
    $lines += "  no git repos found in configured roots"
}
$lines += ""

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
