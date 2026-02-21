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
    "set \"CIVS_ON=1\"",
    "for /f %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -Command \"`$cfg=Join-Path `$env:USERPROFILE ''.armory\\config.json''; if (Test-Path `$cfg) { try { `$obj=Get-Content -Raw -Path `$cfg | ConvertFrom-Json; if (`$obj.PSObject.Properties.Name -contains ''civilianAliases'') { if ([bool]`$obj.civilianAliases) { ''1'' } else { ''0'' } } else { ''1'' } } catch { ''1'' } } else { ''1'' }\"') do set \"CIVS_ON=%%I\"",
    "if \"%ACTION%\"==\"\" goto :help",
    "shift",
    "if /I \"%ACTION%\"==\"help\" goto :help",
    "if /I \"%ACTION%\"==\"list\" goto :list",
    "if /I \"%ACTION%\"==\"keys-list\" (set \"CIV_TARGET=list\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"shop\" goto :shop",
    "if /I \"%ACTION%\"==\"catalog\" (set \"CIV_TARGET=shop\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"forge\" goto :forge",
    "if /I \"%ACTION%\"==\"materia-forge\" goto :forge",
    "if /I \"%ACTION%\"==\"scaffold\" (set \"CIV_TARGET=forge\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"rename\" goto :rename",
    "if /I \"%ACTION%\"==\"rename-word\" goto :rename",
    "if /I \"%ACTION%\"==\"rename-cmd\" (set \"CIV_TARGET=rename\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"civs\" goto :civs",
    "if /I \"%ACTION%\"==\"remedy\" goto :remedy",
    "if /I \"%ACTION%\"==\"health\" (set \"CIV_TARGET=remedy\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"doctor\" goto :doctor",
    "if /I \"%ACTION%\"==\"esuna\" goto :remedy",
    "if /I \"%ACTION%\"==\"reload\" goto :reload",
    "if /I \"%ACTION%\"==\"restart\" (set \"CIV_TARGET=reload\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"swap\" goto :swap",
    "if /I \"%ACTION%\"==\"masamune\" goto :swap",
    "if /I \"%ACTION%\"==\"keys\" (set \"CIV_TARGET=swap\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"bahamut\" goto :bahamut",
    "if /I \"%ACTION%\"==\"restore\" (set \"CIV_TARGET=bahamut\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"ifrit\" goto :ifrit",
    "if /I \"%ACTION%\"==\"create-agent\" (set \"CIV_TARGET=ifrit\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"odin\" goto :odin",
    "if /I \"%ACTION%\"==\"cleanup\" (set \"CIV_TARGET=odin\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"ramuh\" goto :ramuh",
    "if /I \"%ACTION%\"==\"diagnose\" (set \"CIV_TARGET=ramuh\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"shiva\" goto :shiva",
    "if /I \"%ACTION%\"==\"snapshot\" (set \"CIV_TARGET=shiva\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"phoenix-down\" goto :phoenixdown",
    "if /I \"%ACTION%\"==\"backup\" (set \"CIV_TARGET=phoenixdown\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"save-point\" goto :savepoint",
    "if /I \"%ACTION%\"==\"backup-bootstrap\" (set \"CIV_TARGET=savepoint\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"aegis\" goto :aegis",
    "if /I \"%ACTION%\"==\"services\" (set \"CIV_TARGET=aegis\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"sentinel\" goto :sentinel",
    "if /I \"%ACTION%\"==\"scan\" goto :scan",
    "if /I \"%ACTION%\"==\"secret-scan\" (set \"CIV_TARGET=scan\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"truesight\" goto :truesight",
    "if /I \"%ACTION%\"==\"deep-security-scan\" (set \"CIV_TARGET=truesight\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"deep-scan\" goto :deepscan",
    "if /I \"%ACTION%\"==\"libra\" goto :libra",
    "if /I \"%ACTION%\"==\"ops-report\" (set \"CIV_TARGET=libra\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"cure\" goto :cure",
    "if /I \"%ACTION%\"==\"backup-check\" (set \"CIV_TARGET=cure\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"protect\" goto :protect",
    "if /I \"%ACTION%\"==\"scheduled-scan\" (set \"CIV_TARGET=protect\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"regen\" goto :regen",
    "if /I \"%ACTION%\"==\"morning-report\" (set \"CIV_TARGET=regen\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"chronicle\" goto :chronicle",
    "if /I \"%ACTION%\"==\"status\" (set \"CIV_TARGET=chronicle\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"repo-status\" (set \"CIV_TARGET=chronicle\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"bard\" goto :bard",
    "if /I \"%ACTION%\"==\"audio\" (set \"CIV_TARGET=bard\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"alexander\" goto :alexander",
    "if /I \"%ACTION%\"==\"gate\" (set \"CIV_TARGET=alexander\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"preflight\" (set \"CIV_TARGET=alexander\" & goto :civsRoute)",
    "if /I \"%ACTION%\"==\"init\" goto :init",
    "if /I \"%ACTION%\"==\"awakening\" goto :init",
    "if /I \"%ACTION%\"==\"setup\" (set \"CIV_TARGET=init\" & goto :civsRoute)",
    "echo Unknown command: %ACTION%",
    "goto :help",
    ":civsRoute",
    "if /I \"%CIVS_ON%\"==\"1\" goto :%CIV_TARGET%",
    "goto :civsDisabled",
    ":civsDisabled",
    "echo Civilian aliases are OFF. Run %~n0 civs on to enable them.",
    "exit /b 1",
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
    ":civs",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\civs.ps1\" %*",
    "exit /b %errorlevel%",
    ":remedy",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\items\\remedy\\remedy.ps1\" %*",
    "exit /b %errorlevel%",
    ":doctor",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\doctor.ps1\" %*",
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
    ":alexander",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\summons\\alexander\\alexander.ps1\" %*",
    "exit /b %errorlevel%",
    ":init",
    "powershell -ExecutionPolicy Bypass -File \"%ARMORY_ROOT%\\awakening.ps1\" %*",
    "exit /b %errorlevel%",
    ":help",
    "echo.",
    "echo   Armory dispatcher",
    "echo.",
    "echo   Commands:",
    "echo     help, list, shop, forge, materia-forge, rename, rename-word, civs, remedy, doctor, esuna, reload, swap, masamune",
    "echo     bahamut, ifrit, odin, ramuh, shiva, alexander, gate",
    "echo     phoenix-down, save-point",
    "echo     aegis, sentinel, scan, truesight, deep-scan",
    "echo     libra, cure, protect, regen, chronicle, status",
    "echo     bard, init, awakening",
    "echo     civs on^|off^|status",
    "echo.",
    "echo   Civilian aliases (for the uninitiated):",
    "echo     keys-list, catalog, scaffold, rename-cmd, health, restart, keys",
    "echo     restore, create-agent, cleanup, diagnose, snapshot, preflight",
    "echo     backup, backup-bootstrap, services, secret-scan, deep-security-scan",
    "echo     ops-report, backup-check, scheduled-scan, morning-report, repo-status, audio, setup",
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
$civilianAliases = $true
if (Test-Path $configPath) {
    try {
        $existingConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        if ($existingConfig.PSObject.Properties.Name -contains "civilianAliases") {
            $civilianAliases = [bool]$existingConfig.civilianAliases
        }
    } catch {
        $civilianAliases = $true
    }
}
$config = [ordered]@{
    commandWord = $CommandWord
    installDir = $InstallDir
    repoRoot = $repoRoot
    civilianAliases = $civilianAliases
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
