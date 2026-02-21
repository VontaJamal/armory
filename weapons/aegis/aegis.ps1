<#
.SYNOPSIS
  Aegis - service health check with optional Telegram alerts.
#>

param(
    [string]$Services,
    [switch]$Silent,
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
    services = @("CryptoPipeline", "CryptoAlertForwarder", "TradingDashboard", "OpenClawGateway")
    telegramBotToken = $env:TELEGRAM_BOT_TOKEN
    telegramChatId = $env:TELEGRAM_CHAT_ID
}

function Show-Help {
    Write-Host ""
    Write-Host "  Aegis" -ForegroundColor Yellow
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\aegis.ps1"
    Write-Host "    .\\aegis.ps1 -Services \"OpenClawGateway,CryptoPipeline\""
    Write-Host "    .\\aegis.ps1 -Silent"
    Write-Host ""
}

function Write-Check {
    param([string]$Label, [string]$Status, [string]$Color)
    if ($Silent) { return }
    Write-Host ("    " + $Label.PadRight(38)) -NoNewline -ForegroundColor White
    Write-Host $Status -ForegroundColor $Color
}

if ($Help) {
    Show-Help
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

$serviceList = @()
if ($Services) {
    $serviceList = $Services.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
} else {
    $serviceList = $config.services
}

$down = @()
$checkedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (-not $Silent) {
    Write-Host ""
    Write-Host "  Aegis" -ForegroundColor Yellow
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host "  Last checked: $checkedAt" -ForegroundColor DarkGray
    Write-Host ""
}

foreach ($svc in $serviceList) {
    try {
        $s = Get-Service -Name $svc -ErrorAction Stop
        if ($s.Status -eq "Running") {
            Write-Check -Label $svc -Status "RUNNING" -Color "Green"
        } else {
            Write-Check -Label $svc -Status $s.Status.ToString().ToUpper() -Color "Red"
            $down += "$svc is $($s.Status)"
        }
    } catch {
        $sc = sc.exe query $svc 2>&1
        if ($sc -match "RUNNING") {
            Write-Check -Label $svc -Status "RUNNING" -Color "Green"
        } elseif ($sc -match "STOPPED|PAUSED") {
            Write-Check -Label $svc -Status "STOPPED" -Color "Red"
            $down += "$svc is STOPPED"
        } else {
            Write-Check -Label $svc -Status "NOT FOUND" -Color "Yellow"
            $down += "$svc not found"
        }
    }
}

if ($down.Count -gt 0) {
    $message = "Aegis alert`nHost: $env:COMPUTERNAME`nTime: $checkedAt`n" + ($down -join "`n")
    if (-not $Silent) {
        Write-Host ""
        Write-Host "  unhealthy services detected" -ForegroundColor Red
    }

    if ($config.telegramBotToken -and $config.telegramChatId) {
        try {
            $body = @{ chat_id = $config.telegramChatId; text = $message } | ConvertTo-Json
            Invoke-RestMethod -Uri ("https://api.telegram.org/bot{0}/sendMessage" -f $config.telegramBotToken) -Method Post -ContentType "application/json" -Body $body | Out-Null
            if (-not $Silent) {
                Write-Host "  telegram alert sent" -ForegroundColor Yellow
            }
        } catch {
            if (-not $Silent) {
                Write-Host "  telegram alert failed" -ForegroundColor Yellow
            }
        }
    } elseif (-not $Silent) {
        Write-Host "  telegram not configured" -ForegroundColor DarkGray
    }

    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

if (-not $Silent) {
    Write-Host ""
    Write-Host "  all monitored services are healthy" -ForegroundColor Green
    Write-Host ""
}

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
