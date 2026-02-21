<#
.SYNOPSIS
  Civilian-first bootstrap for Armory onboarding.
#>

param(
    [ValidateSet("civ", "saga")]
    [string]$Mode,
    [string]$CommandWord,
    [string]$InstallDir = "$env:USERPROFILE\bin",
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Stop"

function Show-Usage {
    Write-Host ""
    Write-Host "  Armory Setup" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Civilian-first onboarding with optional Crystal Saga handoff."
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\setup.ps1"
    Write-Host "    .\\setup.ps1 -Mode civ"
    Write-Host "    .\\setup.ps1 -Mode saga"
    Write-Host "    .\\setup.ps1 -Mode civ -CommandWord armory"
    Write-Host ""
}

function Resolve-CanonicalMode {
    param([pscustomobject]$Config)

    if ($null -ne $Config -and $Config.PSObject.Properties.Name -contains "mode") {
        $raw = [string]$Config.mode
        if ($raw -eq "civ") { return "civ" }
        if ($raw -in @("saga", "lore", "crystal")) { return "saga" }
    }

    if ($null -ne $Config -and $Config.PSObject.Properties.Name -contains "civilianAliases") {
        if ([bool]$Config.civilianAliases) { return "civ" }
        return "saga"
    }

    return "saga"
}

if ($Help) {
    Show-Usage
    exit 0
}

$repoRoot = (Resolve-Path $PSScriptRoot).Path
$awakening = Join-Path $repoRoot "awakening.ps1"
$civs = Join-Path $repoRoot "civs.ps1"

if (-not (Test-Path $awakening)) { throw "Missing onboarding script: $awakening" }
if (-not (Test-Path $civs)) { throw "Missing mode script: $civs" }

$runner = Get-Command powershell -ErrorAction SilentlyContinue
if (-not $runner) { $runner = Get-Command pwsh -ErrorAction SilentlyContinue }
if (-not $runner) { throw "No PowerShell runner found (expected powershell or pwsh)." }

$userHome = if ($env:USERPROFILE) {
    $env:USERPROFILE
} elseif ($HOME) {
    $HOME
} else {
    [Environment]::GetFolderPath("UserProfile")
}

$configPath = Join-Path (Join-Path $userHome ".armory") "config.json"
$existingConfig = $null
if (Test-Path $configPath) {
    try {
        $existingConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    } catch {
        $existingConfig = $null
    }
}

$selectedMode = $Mode
if (-not $selectedMode) {
    if ($existingConfig) {
        $selectedMode = Resolve-CanonicalMode -Config $existingConfig
    } else {
        Write-Host ""
        Write-Host "  Choose your onboarding path:" -ForegroundColor Cyan
        Write-Host "    1) Civilian Mode (plain language)" -ForegroundColor White
        Write-Host "    2) Crystal Saga Mode (Receive the Crystal)" -ForegroundColor White
        $choice = Read-Host "  Selection [1]"
        if ([string]$choice -eq "2") {
            $selectedMode = "saga"
        } else {
            $selectedMode = "civ"
        }
    }
}

if (-not $CommandWord) {
    if ($selectedMode -eq "civ") {
        $CommandWord = "armory"
    } else {
        $CommandWord = "crystal"
    }
}

$awakeningArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $awakening,
    "-CommandWord", $CommandWord,
    "-InstallDir", $InstallDir
)
if ($Sound) { $awakeningArgs += "-Sound" }
if ($NoSound) { $awakeningArgs += "-NoSound" }

if ($selectedMode -eq "civ") {
    Write-Host ""
    Write-Host "  Civilian onboarding selected." -ForegroundColor Green
    Write-Host "  Initializing with command word '$CommandWord'." -ForegroundColor White

    & $runner.Source @awakeningArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $civArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $civs, "on")
    if ($Sound) { $civArgs += "-Sound" }
    if ($NoSound) { $civArgs += "-NoSound" }
    & $runner.Source @civArgs
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "  Crystal Saga onboarding selected." -ForegroundColor Yellow
Write-Host "  Receiving the Crystal and beginning the journey..." -ForegroundColor White
Write-Host "  Initializing with command word '$CommandWord'." -ForegroundColor White

& $runner.Source @awakeningArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$sagaArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $civs, "off")
if ($Sound) { $sagaArgs += "-Sound" }
if ($NoSound) { $sagaArgs += "-NoSound" }
& $runner.Source @sagaArgs
exit $LASTEXITCODE
