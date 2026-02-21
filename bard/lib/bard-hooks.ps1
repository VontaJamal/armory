<#
.SYNOPSIS
  Shared hook helpers for optional Armory sound cues.
#>

$bardCorePath = Join-Path $PSScriptRoot "bard-core.ps1"
if (Test-Path $bardCorePath) {
    . $bardCorePath
}

function Initialize-ArmorySound {
    param(
        [switch]$Sound,
        [switch]$NoSound,
        [string]$RepoRoot
    )

    $cfg = Initialize-BardConfig -RepoRoot $RepoRoot

    $enabled = $false
    if ($NoSound) {
        $enabled = $false
    } elseif ($Sound) {
        $enabled = $true
    } elseif ($cfg.enabled) {
        $enabled = $true
    }

    return [PSCustomObject]@{
        Enabled = $enabled
        Config = $cfg
    }
}

function Invoke-ArmoryCue {
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [ValidateSet("start","success","fail")][string]$Type
    )

    if (-not $Context -or -not $Context.Enabled) {
        return
    }

    $path = Get-BardCuePath -Cue $Type -Config $Context.Config
    if ($path) {
        [void](Invoke-BardPlayback -FilePath $path)
    }
}

function Invoke-ArmoryTheme {
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [string]$Theme = "default"
    )

    if (-not $Context -or -not $Context.Enabled) {
        return
    }

    $path = Get-BardThemePath -ThemeName $Theme -Config $Context.Config
    if ($path) {
        [void](Invoke-BardPlayback -FilePath $path)
    }
}
