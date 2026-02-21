<#
.SYNOPSIS
  Bard - optional sound layer for Armory tools.
#>

param(
    [Parameter(Position = 0)][string]$Command,
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib\bard-core.ps1")
. (Join-Path $PSScriptRoot "lib\bard-hooks.ps1")

function Show-Help {
    Write-Host ""
    Write-Host "  Bard" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\bard.ps1 list"
    Write-Host "    .\\bard.ps1 test"
    Write-Host "    .\\bard.ps1 play <file>"
    Write-Host "    .\\bard.ps1 enable"
    Write-Host "    .\\bard.ps1 disable"
    Write-Host "    .\\bard.ps1 theme <name> <file>"
    Write-Host "    .\\bard.ps1 config"
    Write-Host ""
}

if ($Help -or -not $Command) {
    Show-Help
    exit 0
}

$config = Initialize-BardConfig

switch ($Command.ToLower()) {
    "help" {
        Show-Help
        exit 0
    }
    "list" {
        Write-Host ""
        Write-Host "  Bard assets" -ForegroundColor Cyan
        Write-Host "  -----------------------------" -ForegroundColor DarkGray
        $items = Get-BardAssetInventory -Config $config
        if ($items.Count -eq 0) {
            Write-Host "    none found" -ForegroundColor Yellow
        } else {
            foreach ($i in $items) {
                Write-Host "    $($i.File) ($($i.SizeKB) KB)" -ForegroundColor White
            }
        }
        Write-Host ""
        exit 0
    }
    "play" {
        if (-not $Arg1) {
            Write-Host "  Missing file argument" -ForegroundColor Red
            exit 1
        }
        $target = Resolve-BardAsset -Asset $Arg1 -Config $config
        if (-not $target) {
            Write-Host "  File not found: $Arg1" -ForegroundColor Red
            exit 1
        }
        $ok = Invoke-BardPlayback -FilePath $target
        if ($ok) {
            Write-Host "  played: $target" -ForegroundColor Green
            exit 0
        }
        Write-Host "  playback failed: $target" -ForegroundColor Red
        exit 1
    }
    "test" {
        $ctx = [PSCustomObject]@{ Enabled = $true; Config = $config }
        Invoke-ArmoryCue -Context $ctx -Type start
        Invoke-ArmoryCue -Context $ctx -Type success
        Invoke-ArmoryCue -Context $ctx -Type fail
        Write-Host "  test cues played" -ForegroundColor Green
        exit 0
    }
    "enable" {
        $config.enabled = $true
        Save-BardConfig -Config $config
        Write-Host "  bard enabled" -ForegroundColor Green
        exit 0
    }
    "disable" {
        $config.enabled = $false
        Save-BardConfig -Config $config
        Write-Host "  bard disabled" -ForegroundColor Yellow
        exit 0
    }
    "theme" {
        if (-not $Arg1 -or -not $Arg2) {
            Write-Host "  Usage: .\\bard.ps1 theme <name> <file>" -ForegroundColor Red
            exit 1
        }
        if (-not $config.themes) {
            $config | Add-Member -NotePropertyName themes -NotePropertyValue ([PSCustomObject]@{})
        }
        $config.themes | Add-Member -NotePropertyName $Arg1 -NotePropertyValue $Arg2 -Force
        Save-BardConfig -Config $config
        Write-Host "  theme set: $Arg1 -> $Arg2" -ForegroundColor Green
        exit 0
    }
    "config" {
        $config | ConvertTo-Json -Depth 8
        exit 0
    }
    default {
        Write-Host "  Unknown command: $Command" -ForegroundColor Red
        Show-Help
        exit 1
    }
}
