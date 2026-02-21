<#
.SYNOPSIS
  Regen - morning briefing summary.
#>

param(
    [string]$City,
    [switch]$Telegram,
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
    city = "Dallas"
    telegramBotToken = $env:TELEGRAM_BOT_TOKEN
    telegramChatId = $env:TELEGRAM_CHAT_ID
    gitRepoDirs = @("D:\Code Repos")
    optionalCalendarCredsPath = "$env:USERPROFILE\.armory\calendar\credentials.json"
    serviceNames = @("OpenClawGateway", "CryptoPipeline")
}

function Show-Help {
    Write-Host ""
    Write-Host "  Regen" -ForegroundColor Magenta
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\regen.ps1"
    Write-Host "    .\\regen.ps1 -City Austin"
    Write-Host "    .\\regen.ps1 -Telegram"
    Write-Host ""
}

if ($Help) {
    Show-Help
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if (-not $City) { $City = $config.city }

$lines = @()
$lines += "REGEN MORNING BRIEFING"
$lines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += ""

# Weather
$lines += "Weather:"
try {
    $weather = Invoke-RestMethod -Uri ("https://wttr.in/{0}?format=3" -f [uri]::EscapeDataString($City)) -Method Get
    $lines += "  $weather"
} catch {
    $lines += "  unavailable for $City"
}
$lines += ""

# Disk summary
$lines += "Disk summary:"
try {
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($d in $drives) {
        $pct = if ($d.Size -gt 0) { [math]::Round(($d.FreeSpace / $d.Size) * 100, 1) } else { 0 }
        $lines += "  $($d.DeviceID) free: $pct`%"
    }
} catch {
    $lines += "  unavailable"
}
$lines += ""

# Service health
$lines += "Service health:"
foreach ($svc in $config.serviceNames) {
    try {
        $status = (Get-Service -Name $svc -ErrorAction Stop).Status
        $lines += "  $svc - $status"
    } catch {
        $lines += "  $svc - not found"
    }
}
$lines += ""

# Failed cron jobs signal (openclaw logs)
$lines += "Recent cron issues:"
$openclawLogRoot = "$env:USERPROFILE\.openclaw\logs"
if (Test-Path $openclawLogRoot) {
    $recent = Get-ChildItem $openclawLogRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.LastWriteTime -gt (Get-Date).AddHours(-24) -and $_.Name -match "cron|schedule|job"
    }
    $hits = 0
    foreach ($f in $recent) {
        try {
            $txt = [System.IO.File]::ReadAllText($f.FullName)
            if ($txt -match "ERROR|FAIL|EXCEPTION") {
                $lines += "  possible issue in $($f.Name)"
                $hits++
            }
        } catch {}
    }
    if ($hits -eq 0) {
        $lines += "  none detected"
    }
} else {
    $lines += "  openclaw logs not found"
}
$lines += ""

# Git dirty repos
$lines += "Git repos with uncommitted changes:"
$dirtyCount = 0
foreach ($root in $config.gitRepoDirs) {
    if (-not (Test-Path $root)) { continue }
    $repos = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue
    foreach ($r in $repos) {
        if (-not (Test-Path (Join-Path $r.FullName ".git"))) { continue }
        $status = git -C $r.FullName status --porcelain 2>$null
        if ($status) {
            $lines += "  $($r.Name)"
            $dirtyCount++
        }
    }
}
if ($dirtyCount -eq 0) {
    $lines += "  none"
}
$lines += ""

# Optional calendar check
$lines += "Calendar status:"
if (Test-Path $config.optionalCalendarCredsPath) {
    $lines += "  credentials found (integration optional)"
} else {
    $lines += "  not configured"
}
$lines += ""

$report = ($lines -join "`r`n")
Write-Output $report

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
