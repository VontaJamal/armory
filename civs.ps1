<#
.SYNOPSIS
  Manage Armory mode (`saga` or `civ`) for aliases and reporting tone.
#>

param(
    [Parameter(Position=0)]
    [ValidateSet("on", "off", "status")]
    [string]$Mode = "status",
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
    Write-Host "  Armory Mode" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Toggle between Crystal Saga Mode and Civilian Mode."
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\civs.ps1"
    Write-Host "    .\civs.ps1 status"
    Write-Host "    .\civs.ps1 on   # Civilian Mode"
    Write-Host "    .\civs.ps1 off  # Crystal Saga Mode"
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
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

$userHome = if ($env:USERPROFILE) {
    $env:USERPROFILE
} elseif ($HOME) {
    $HOME
} else {
    [Environment]::GetFolderPath("UserProfile")
}
$configDir = Join-Path $userHome ".armory"
$configPath = Join-Path $configDir "config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "  Missing Armory config: $configPath" -ForegroundColor Red
    Write-Host "  Run awakening.ps1 first to initialize your command word." -ForegroundColor Yellow
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

try {
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "  Failed to parse Armory config: $configPath" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

$currentMode = Resolve-CanonicalMode -Config $config

switch ($Mode) {
    "on" {
        $currentMode = "civ"
        Write-Host "  Civilian Mode is now ON." -ForegroundColor Green
    }
    "off" {
        $currentMode = "saga"
        Write-Host "  Crystal Saga Mode is now ON." -ForegroundColor Yellow
    }
    default {
        # status mode: no file mutation beyond normalization
    }
}

# Persist canonical mode and legacy alias boolean for compatibility.
$config | Add-Member -NotePropertyName mode -NotePropertyValue $currentMode -Force
$config | Add-Member -NotePropertyName civilianAliases -NotePropertyValue ($currentMode -eq "civ") -Force
$config | ConvertTo-Json -Depth 8 | Set-Content -Path $configPath -Encoding UTF8

$modeLabel = if ($currentMode -eq "civ") { "Civilian Mode" } else { "Crystal Saga Mode" }
$statusColor = if ($currentMode -eq "civ") { "Green" } else { "Yellow" }
$commandWord = if ($config.PSObject.Properties.Name -contains "commandWord") { [string]$config.commandWord } else { "<command-word>" }

Write-Host ""
Write-Host ("  Current mode: {0} ({1})" -f $modeLabel, $currentMode) -ForegroundColor $statusColor
Write-Host "  Command examples:" -ForegroundColor Cyan
Write-Host ("    {0} civs status" -f $commandWord) -ForegroundColor White
Write-Host ("    {0} civs on" -f $commandWord) -ForegroundColor White
Write-Host ("    {0} civs off" -f $commandWord) -ForegroundColor White
Write-Host ""

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
