<#
.SYNOPSIS
  Awakening - first-run setup for Armory command dispatcher.
#>

param(
    [string]$CommandWord,
    [string]$InstallDir = "$env:USERPROFILE\bin",
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Stop"

$hooks = Join-Path $PSScriptRoot "bard\lib\bard-hooks.ps1"
if (Test-Path $hooks) { . $hooks }
$soundContext = $null
if (Get-Command Initialize-ArmorySound -ErrorAction SilentlyContinue) {
    $soundContext = Initialize-ArmorySound -Sound:$Sound -NoSound:$NoSound -RepoRoot $PSScriptRoot
    Invoke-ArmoryCue -Context $soundContext -Type start
}

function Show-Usage {
    Write-Host ""
    Write-Host "  Awakening" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Set a command word for Armory tools."
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\awakening.ps1"
    Write-Host "    .\\awakening.ps1 -CommandWord faye"
    Write-Host "    .\\awakening.ps1 -CommandWord forge -InstallDir C:\\Tools\\bin"
    Write-Host ""
    Write-Host "  Examples for command word: armory, ops, forge, faye, kit"
    Write-Host ""
}

if ($Help) {
    Show-Usage
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if (-not $CommandWord) {
    Show-Usage
    $CommandWord = Read-Host "  Command word"
}

if (-not $CommandWord -or $CommandWord -notmatch "^[a-zA-Z][a-zA-Z0-9-]{1,20}$") {
    Write-Host "  Invalid command word. Use letters, numbers, and dash only." -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$repoRoot = (Resolve-Path $PSScriptRoot).Path
$cmdPath = Join-Path $InstallDir ("{0}.cmd" -f $CommandWord)

$cmdLines = @(
    "@echo off",
    "setlocal",
    "set \"ARMORY_ROOT=$repoRoot\"",
    "set \"ACTION=%~1\"",
    "if \"%ACTION%\"==\"\" goto :help",
    "shift",
    "if /I \"%ACTION%\"==\"help\" goto :help",
    "if /I \"%ACTION%\"==\"list\" goto :list",
    "if /I \"%ACTION%\"==\"shop\" goto :shop",
    "if /I \"%ACTION%\"==\"forge\" goto :forge",
    "if /I \"%ACTION%\"==\"materia-forge\" goto :forge",
    "if /I \"%ACTION%\"==\"rename\" goto :rename",
    "if /I \"%ACTION%\"==\"rename-word\" goto :rename",
    "if /I \"%ACTION%\"==\"reload\" goto :reload",
    "if /I \"%ACTION%\"==\"swap\" goto :swap",
    "if /I \"%ACTION%\"==\"masamune\" goto :swap",
    "if /I \"%ACTION%\"==\"bahamut\" goto :bahamut",
    "if /I \"%ACTION%\"==\"ifrit\" goto :ifrit",
    "if /I \"%ACTION%\"==\"odin\" goto :odin",
    "if /I \"%ACTION%\"==\"ramuh\" goto :ramuh",
    "if /I \"%ACTION%\"==\"shiva\" goto :shiva",
    "if /I \"%ACTION%\"==\"phoenix-down\" goto :phoenixdown",
    "if /I \"%ACTION%\"==\"save-point\" goto :savepoint",
    "if /I \"%ACTION%\"==\"aegis\" goto :aegis",
    "if /I \"%ACTION%\"==\"sentinel\" goto :sentinel",
    "if /I \"%ACTION%\"==\"scan\" goto :scan",
    "if /I \"%ACTION%\"==\"truesight\" goto :truesight",
    "if /I \"%ACTION%\"==\"deep-scan\" goto :deepscan",
    "if /I \"%ACTION%\"==\"libra\" goto :libra",
    "if /I \"%ACTION%\"==\"cure\" goto :cure",
    "if /I \"%ACTION%\"==\"protect\" goto :protect",
    "if /I \"%ACTION%\"==\"regen\" goto :regen",
    "if /I \"%ACTION%\"==\"chronicle\" goto :chronicle",
    "if /I \"%ACTION%\"==\"status\" goto :chronicle",
    "if /I \"%ACTION%\"==\"bard\" goto :bard",
    "if /I \"%ACTION%\"==\"init\" goto :init",
    "if /I \"%ACTION%\"==\"awakening\" goto :init",
    "echo Unknown command: %ACTION%",
    "goto :help",
    ":swap",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\weapons\\masamune\\masamune.ps1\" %*",
    "exit /b %errorlevel%",
    ":list",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\weapons\\masamune\\masamune.ps1\" list",
    "exit /b %errorlevel%",
    ":shop",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\shop\\list-shop.ps1\" %*",
    "exit /b %errorlevel%",
    ":forge",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\materia-forge.ps1\" %*",
    "exit /b %errorlevel%",
    ":rename",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\rename-command-word.ps1\" %*",
    "exit /b %errorlevel%",
    ":reload",
    "powershell -ExecutionPolicy Bypass -Command \"openclaw gateway restart 2>$null; if ($LASTEXITCODE -ne 0) { nssm restart OpenClawGateway 2>$null }\"",
    "exit /b 0",
    ":bahamut",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\summons\\bahamut\\bahamut.ps1\" %*",
    "exit /b %errorlevel%",
    ":ifrit",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\summons\\ifrit\\ifrit.ps1\" %*",
    "exit /b %errorlevel%",
    ":odin",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\summons\\odin\\odin.ps1\" %*",
    "exit /b %errorlevel%",
    ":ramuh",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\summons\\ramuh\\ramuh.ps1\" %*",
    "exit /b %errorlevel%",
    ":shiva",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\summons\\shiva\\shiva.ps1\" %*",
    "exit /b %errorlevel%",
    ":phoenixdown",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\weapons\\phoenix-down\\phoenix-down.ps1\" %*",
    "exit /b %errorlevel%",
    ":savepoint",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\weapons\\phoenix-down\\save-point.ps1\" %*",
    "exit /b %errorlevel%",
    ":aegis",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\weapons\\aegis\\aegis.ps1\" %*",
    "exit /b %errorlevel%",
    ":sentinel",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\weapons\\sentinel\\sentinel.ps1\" %*",
    "exit /b %errorlevel%",
    ":scan",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\weapons\\scan\\scan.ps1\" %*",
    "exit /b %errorlevel%",
    ":truesight",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\weapons\\truesight\\truesight.ps1\" %*",
    "exit /b %errorlevel%",
    ":deepscan",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\weapons\\scan\\deep-scan.ps1\" %*",
    "exit /b %errorlevel%",
    ":libra",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\spells\\libra\\libra.ps1\" %*",
    "exit /b %errorlevel%",
    ":cure",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\spells\\cure\\cure.ps1\" %*",
    "exit /b %errorlevel%",
    ":protect",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\spells\\protect\\protect.ps1\" %*",
    "exit /b %errorlevel%",
    ":regen",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\spells\\regen\\regen.ps1\" %*",
    "exit /b %errorlevel%",
    ":chronicle",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\spells\\chronicle\\chronicle.ps1\" %*",
    "exit /b %errorlevel%",
    ":bard",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\bard\\bard.ps1\" %*",
    "exit /b %errorlevel%",
    ":init",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\awakening.ps1\" %*",
    "exit /b %errorlevel%",
    ":help",
    "echo.",
    "echo   Armory dispatcher",
    "echo.",
    "echo   Commands:",
    "echo     help, list, shop, forge, materia-forge, rename, rename-word, reload, swap, masamune",
    "echo     bahamut, ifrit, odin, ramuh, shiva",
    "echo     phoenix-down, save-point",
    "echo     aegis, sentinel, scan, truesight, deep-scan",
    "echo     libra, cure, protect, regen, chronicle, status",
    "echo     bard, init, awakening",
    "echo.",
    "exit /b 0"
)

Set-Content -Path $cmdPath -Value ($cmdLines -join "`r`n") -Encoding ASCII

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) {
    $userPath = ""
}
if ($userPath -notlike "*${InstallDir}*") {
    if ($userPath.Length -gt 0 -and -not $userPath.EndsWith(";")) {
        $newPath = "$userPath;$InstallDir"
    } else {
        $newPath = "$userPath$InstallDir"
    }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
}

$armoryDir = Join-Path $env:USERPROFILE ".armory"
if (-not (Test-Path $armoryDir)) {
    New-Item -ItemType Directory -Path $armoryDir -Force | Out-Null
}

$configPath = Join-Path $armoryDir "config.json"
$config = [ordered]@{
    commandWord = $CommandWord
    installDir = $InstallDir
    repoRoot = $repoRoot
}
$config | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8

Write-Host ""
Write-Host "  Awakening complete" -ForegroundColor Green
Write-Host "  Command word: $CommandWord" -ForegroundColor White
Write-Host "  Wrapper: $cmdPath" -ForegroundColor DarkGray
Write-Host "  Config:  $configPath" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Try commands:" -ForegroundColor Yellow
Write-Host "    $CommandWord help" -ForegroundColor White
Write-Host "    $CommandWord swap list" -ForegroundColor White
Write-Host "    $CommandWord aegis" -ForegroundColor White
Write-Host ""

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
