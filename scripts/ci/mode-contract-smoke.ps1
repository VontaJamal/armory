<#
.SYNOPSIS
  Smoke test the shared mode contract using real Armory scripts.
#>

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$awakening = Join-Path $repoRoot "awakening.ps1"
$civs = Join-Path $repoRoot "civs.ps1"

if (-not (Test-Path $awakening)) { throw "Missing awakening.ps1" }
if (-not (Test-Path $civs)) { throw "Missing civs.ps1" }

$psRunner = Get-Command powershell -ErrorAction SilentlyContinue
if (-not $psRunner) { $psRunner = Get-Command pwsh -ErrorAction SilentlyContinue }
if (-not $psRunner) { throw "Missing PowerShell runtime (powershell or pwsh)." }

$tempHome = Join-Path ([System.IO.Path]::GetTempPath()) ("armory-mode-" + [Guid]::NewGuid().ToString("N"))
$installDir = Join-Path $tempHome "bin"
$originalUserProfile = $env:USERPROFILE
$originalHome = $env:HOME

try {
    New-Item -ItemType Directory -Path $tempHome -Force | Out-Null
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null

    $env:USERPROFILE = $tempHome
    $env:HOME = $tempHome

    & $psRunner.Source -NoProfile -ExecutionPolicy Bypass -File $awakening -CommandWord "armtest" -InstallDir $installDir -NoSound
    if ($LASTEXITCODE -ne 0) { throw "awakening.ps1 failed" }

    $configPath = Join-Path $tempHome ".armory\config.json"
    if (-not (Test-Path $configPath)) { throw "config.json not created" }

    $cfg = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    if ([string]$cfg.mode -ne "saga") {
        throw "expected default mode=saga, got: $($cfg.mode)"
    }

    & $psRunner.Source -NoProfile -ExecutionPolicy Bypass -File $civs on -NoSound
    if ($LASTEXITCODE -ne 0) { throw "civs.ps1 on failed" }
    $cfg = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    if ([string]$cfg.mode -ne "civ") { throw "expected mode=civ after civs on" }
    if (-not [bool]$cfg.civilianAliases) { throw "expected civilianAliases=true after civs on" }

    & $psRunner.Source -NoProfile -ExecutionPolicy Bypass -File $civs off -NoSound
    if ($LASTEXITCODE -ne 0) { throw "civs.ps1 off failed" }
    $cfg = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    if ([string]$cfg.mode -ne "saga") { throw "expected mode=saga after civs off" }
    if ([bool]$cfg.civilianAliases) { throw "expected civilianAliases=false after civs off" }

    Write-Host "OK mode contract smoke passed" -ForegroundColor Green
}
finally {
    $env:USERPROFILE = $originalUserProfile
    $env:HOME = $originalHome
    if (Test-Path $tempHome) {
        Remove-Item -Path $tempHome -Recurse -Force -ErrorAction SilentlyContinue
    }
}
