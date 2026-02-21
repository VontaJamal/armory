<#
.SYNOPSIS
  Rename the Armory command word to a new value.
#>

param(
    [Parameter(Position=0)]
    [string]$NewCommandWord,
    [string]$OldCommandWord,
    [string]$InstallDir,
    [switch]$KeepOldAlias,
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

function Show-HelpText {
    Write-Host ""
    Write-Host "  Rename Command Word" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\rename-command-word.ps1 newword"
    Write-Host "    .\\rename-command-word.ps1 -NewCommandWord forge -KeepOldAlias"
    Write-Host "    .\\rename-command-word.ps1 -NewCommandWord ops -OldCommandWord armory"
    Write-Host ""
}

if ($Help) {
    Show-HelpText
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if (-not $NewCommandWord) {
    Show-HelpText
    Write-Host "  New command word is required." -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

if ($NewCommandWord -notmatch "^[a-zA-Z][a-zA-Z0-9-]{1,20}$") {
    Write-Host "  Invalid command word. Use letters, numbers, and dash only." -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

$configPath = Join-Path $env:USERPROFILE ".armory\config.json"
$config = $null
if (Test-Path $configPath) {
    try {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    } catch {
        $config = $null
    }
}

if (-not $OldCommandWord -and $config -and $config.commandWord) {
    $OldCommandWord = [string]$config.commandWord
}

$effectiveInstallDir = $InstallDir
if (-not $effectiveInstallDir -and $config -and $config.installDir) {
    $effectiveInstallDir = [string]$config.installDir
}
if (-not $effectiveInstallDir) {
    $effectiveInstallDir = "$env:USERPROFILE\bin"
}

$awakening = Join-Path $PSScriptRoot "awakening.ps1"
if (-not (Test-Path $awakening)) {
    Write-Host "  Missing awakening script: $awakening" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

$awakenArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $awakening,
    "-CommandWord", $NewCommandWord,
    "-InstallDir", $effectiveInstallDir
)
if ($Sound) { $awakenArgs += "-Sound" }
if ($NoSound) { $awakenArgs += "-NoSound" }

powershell @awakenArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Failed to update command word." -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit $LASTEXITCODE
}

if ($OldCommandWord -and ($OldCommandWord -ne $NewCommandWord) -and -not $KeepOldAlias) {
    $oldWrapper = Join-Path $effectiveInstallDir ("{0}.cmd" -f $OldCommandWord)
    if (Test-Path $oldWrapper) {
        Remove-Item -Path $oldWrapper -Force -ErrorAction SilentlyContinue
        Write-Host "  Removed old wrapper: $oldWrapper" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "  Rename complete" -ForegroundColor Green
if ($OldCommandWord) {
    Write-Host "  Old command: $OldCommandWord" -ForegroundColor DarkGray
}
Write-Host "  New command: $NewCommandWord" -ForegroundColor White
Write-Host ""

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
