<#
.SYNOPSIS
  Protect - scheduled security scan for cron and task scheduler.
#>

param(
    [string]$Dirs,
    [switch]$Telegram,
    [switch]$Verbose,
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
    dirs = @("D:\Code Repos")
    telegramBotToken = $env:TELEGRAM_BOT_TOKEN
    telegramChatId = $env:TELEGRAM_CHAT_ID
    ignorePattern = '[\\/](\.git|node_modules|\.venv|dist|__pycache__)[\\/]'
}

function Show-Help {
    Write-Host ""
    Write-Host "  Protect" -ForegroundColor Magenta
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\protect.ps1"
    Write-Host "    .\\protect.ps1 -Dirs \"D:\\Code Repos,D:\\Infra\""
    Write-Host "    .\\protect.ps1 -Verbose"
    Write-Host ""
}

if ($Help) {
    Show-Help
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

$targetDirs = @()
if ($Dirs) {
    $targetDirs = $Dirs.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
} else {
    $targetDirs = $config.dirs
}

$findings = @()

foreach ($dir in $targetDirs) {
    if (-not (Test-Path $dir)) { continue }

    $files = Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch $config.ignorePattern -and
        $_.Extension -match '\.(md|ts|js|json|yml|yaml|sh|ps1|html|css|py|toml|txt|env|cfg|ini)$'
    }

    foreach ($f in $files) {
        $content = $null
        try {
            $content = [System.IO.File]::ReadAllText($f.FullName)
        } catch {
            continue
        }

        if (-not $content) { continue }

        if ($content -match '\d{8,12}:[A-Za-z0-9_-]{30,}') {
            $findings += "CRITICAL|$($f.FullName)|Telegram token pattern"
        }
        if ($content -match "(sk_[a-zA-Z0-9]{20,}|sk-ant-[a-zA-Z0-9]{20,}|gho_[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|AIza[a-zA-Z0-9]{30,})") {
            $findings += "CRITICAL|$($f.FullName)|API key pattern"
        }
        if ($content -match "PRIVATE KEY") {
            $findings += "CRITICAL|$($f.FullName)|Private key text"
        }
        if ($content -match '(?i)(password|passwd|pwd)\s*[:=]\s*[''"][^''"]{4,}[''"]') {
            $findings += "WARNING|$($f.FullName)|Hardcoded password pattern"
        }
    }
}

if ($findings.Count -eq 0) {
    if ($Verbose) {
        Write-Host ""
        Write-Host "  Protect clean" -ForegroundColor Green
        Write-Host ""
    }
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

foreach ($line in $findings) {
    $parts = $line.Split("|")
    $color = if ($parts[0] -eq "CRITICAL") { "Red" } else { "Yellow" }
    Write-Host ("  [{0}] {1} - {2}" -f $parts[0], $parts[1], $parts[2]) -ForegroundColor $color
}

if ($Telegram -and $config.telegramBotToken -and $config.telegramChatId) {
    $summary = "Protect findings on $env:COMPUTERNAME`nCount: $($findings.Count)"
    try {
        $body = @{ chat_id = $config.telegramChatId; text = $summary } | ConvertTo-Json
        Invoke-RestMethod -Uri ("https://api.telegram.org/bot{0}/sendMessage" -f $config.telegramBotToken) -Method Post -ContentType "application/json" -Body $body | Out-Null
    } catch {
        if ($Verbose) {
            Write-Host "  telegram alert failed" -ForegroundColor Yellow
        }
    }
}

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
exit 1
