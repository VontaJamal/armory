<#
.SYNOPSIS
  Manage Civilian alias mode for Armory dispatcher commands.
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
    Write-Host "  Civilian Alias Mode" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Toggle plain-language civilian aliases for dispatcher commands."
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\civs.ps1"
    Write-Host "    .\civs.ps1 status"
    Write-Host "    .\civs.ps1 on"
    Write-Host "    .\civs.ps1 off"
    Write-Host ""
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

$currentEnabled = $true
if ($config.PSObject.Properties.Name -contains "civilianAliases") {
    $currentEnabled = [bool]$config.civilianAliases
}

switch ($Mode) {
    "on" {
        $currentEnabled = $true
        $config | Add-Member -NotePropertyName civilianAliases -NotePropertyValue $true -Force
        $config | ConvertTo-Json -Depth 8 | Set-Content -Path $configPath -Encoding UTF8
        Write-Host "  Civilian aliases are now ON." -ForegroundColor Green
    }
    "off" {
        $currentEnabled = $false
        $config | Add-Member -NotePropertyName civilianAliases -NotePropertyValue $false -Force
        $config | ConvertTo-Json -Depth 8 | Set-Content -Path $configPath -Encoding UTF8
        Write-Host "  Civilian aliases are now OFF." -ForegroundColor Yellow
    }
    default {
        # status mode: no file mutation
    }
}

$statusText = if ($currentEnabled) { "ON" } else { "OFF" }
$statusColor = if ($currentEnabled) { "Green" } else { "Yellow" }
$commandWord = if ($config.PSObject.Properties.Name -contains "commandWord") { [string]$config.commandWord } else { "<command-word>" }

Write-Host ""
Write-Host ("  Current status: {0}" -f $statusText) -ForegroundColor $statusColor
Write-Host "  Command examples:" -ForegroundColor Cyan
Write-Host ("    {0} civs status" -f $commandWord) -ForegroundColor White
Write-Host ("    {0} civs on" -f $commandWord) -ForegroundColor White
Write-Host ("    {0} civs off" -f $commandWord) -ForegroundColor White
Write-Host ""

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
