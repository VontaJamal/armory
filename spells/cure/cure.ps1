<#
.SYNOPSIS
  Cure - verify backup health and restorability.
#>

param(
    [string]$Dir = "$env:USERPROFILE\.openclaw\backups",
    [int]$MaxAgeHours = 24,
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
    telegramBotToken = $env:TELEGRAM_BOT_TOKEN
    telegramChatId = $env:TELEGRAM_CHAT_ID
    sevenZip = "C:\Program Files\7-Zip\7z.exe"
    passwordFile = "$env:USERPROFILE\.openclaw\secrets\backup-password.txt"
}

function Show-Help {
    Write-Host ""
    Write-Host "  Cure" -ForegroundColor Magenta
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\cure.ps1"
    Write-Host "    .\\cure.ps1 -Dir D:\\Backups"
    Write-Host "    .\\cure.ps1 -Telegram"
    Write-Host ""
}

if ($Help) {
    Show-Help
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if (-not (Test-Path $Dir)) {
    Write-Host "  backup directory missing: $Dir" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

$files = Get-ChildItem -Path $Dir -Filter "*.7z" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($files.Count -eq 0) {
    Write-Host "  no backup archives found" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

$latest = $files[0]
$ageHours = [math]::Round(((Get-Date) - $latest.LastWriteTime).TotalHours, 1)
$healthy = $true

Write-Host ""
Write-Host "  Cure" -ForegroundColor Magenta
Write-Host "  -----------------------------" -ForegroundColor DarkGray
Write-Host "  latest: $($latest.Name)" -ForegroundColor White
Write-Host "  size:   $([math]::Round($latest.Length / 1MB, 2)) MB" -ForegroundColor White
Write-Host "  age:    $ageHours hours" -ForegroundColor White

if ($latest.Length -le 0) {
    Write-Host "  status: FAIL (zero-byte archive)" -ForegroundColor Red
    $healthy = $false
}

if ($ageHours -gt $MaxAgeHours) {
    Write-Host "  status: FAIL (stale backup)" -ForegroundColor Red
    $healthy = $false
}

if ($healthy -and (Test-Path $config.sevenZip)) {
    $passwordArgs = @()
    if (Test-Path $config.passwordFile) {
        $password = ([System.IO.File]::ReadAllText($config.passwordFile)).Trim()
        if ($password) {
            $passwordArgs = @(("-p" + $password))
        }
    }

    & $config.sevenZip t $latest.FullName @passwordArgs | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  integrity: pass" -ForegroundColor Green
    } else {
        Write-Host "  integrity: FAIL" -ForegroundColor Red
        $healthy = $false
    }
} elseif ($healthy) {
    Write-Host "  integrity: skipped (7-Zip missing)" -ForegroundColor Yellow
    $healthy = $false
}

if (-not $healthy -and $Telegram -and $config.telegramBotToken -and $config.telegramChatId) {
    $alert = "Cure alert on $env:COMPUTERNAME`nLatest: $($latest.Name)`nAge: $ageHours h`nStatus: FAIL"
    try {
        $body = @{ chat_id = $config.telegramChatId; text = $alert } | ConvertTo-Json
        Invoke-RestMethod -Uri ("https://api.telegram.org/bot{0}/sendMessage" -f $config.telegramBotToken) -Method Post -ContentType "application/json" -Body $body | Out-Null
        Write-Host "  telegram alert sent" -ForegroundColor Yellow
    } catch {
        Write-Host "  telegram alert failed" -ForegroundColor Yellow
    }
}

if ($healthy) {
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
exit 1
