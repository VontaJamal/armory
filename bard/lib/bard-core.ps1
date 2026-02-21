<#
.SYNOPSIS
  Bard core helpers for Armory sound playback and config management.
#>

Set-StrictMode -Version 2.0

function Get-BardHome {
    return (Join-Path $env:USERPROFILE ".armory\bard")
}

function Get-BardConfigPath {
    return (Join-Path (Get-BardHome) "config.json")
}

function Get-BardRepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..\..") -ErrorAction SilentlyContinue).Path
}

function New-BardDefaultConfig {
    param(
        [string]$RepoRoot
    )

    if (-not $RepoRoot) {
        $RepoRoot = Get-BardRepoRoot
    }

    return [ordered]@{
        enabled = $false
        playbackMode = "opt-in"
        volume = 100
        assetRoots = @(
            (Join-Path (Get-BardHome) "assets"),
            (Join-Path $RepoRoot "bard\assets")
        )
        cues = [ordered]@{
            start = "sfx\start.wav"
            success = "sfx\success.wav"
            fail = "sfx\fail.wav"
        }
        themes = [ordered]@{
            default = "themes\default.mp3"
        }
    }
}

function Initialize-BardConfig {
    param(
        [string]$RepoRoot
    )

    $bardHome = Get-BardHome
    if (-not (Test-Path $bardHome)) {
        New-Item -ItemType Directory -Path $bardHome -Force | Out-Null
    }

    $configPath = Get-BardConfigPath
    if (-not (Test-Path $configPath)) {
        $default = New-BardDefaultConfig -RepoRoot $RepoRoot
        $default | ConvertTo-Json -Depth 8 | Set-Content -Path $configPath -Encoding UTF8
    }

    try {
        $content = [System.IO.File]::ReadAllText($configPath)
        $cfg = $content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $cfg = (New-BardDefaultConfig -RepoRoot $RepoRoot) | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    }

    if (-not $cfg.assetRoots -or $cfg.assetRoots.Count -eq 0) {
        $cfg.assetRoots = @(
            (Join-Path (Get-BardHome) "assets"),
            (Join-Path $RepoRoot "bard\assets")
        )
    }

    return $cfg
}

function Save-BardConfig {
    param([object]$Config)
    $path = Get-BardConfigPath
    $Config | ConvertTo-Json -Depth 8 | Set-Content -Path $path -Encoding UTF8
}

function Resolve-BardAsset {
    param(
        [string]$Asset,
        [object]$Config
    )

    if (-not $Asset) { return $null }

    if ([System.IO.Path]::IsPathRooted($Asset)) {
        if (Test-Path $Asset) { return (Resolve-Path $Asset).Path }
        return $null
    }

    foreach ($root in $Config.assetRoots) {
        if (-not $root) { continue }
        $expanded = $root -replace "~", $env:USERPROFILE
        $candidate = Join-Path $expanded $Asset
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

function Get-BardCuePath {
    param(
        [ValidateSet("start","success","fail")][string]$Cue,
        [object]$Config
    )

    $rel = $Config.cues.$Cue
    if (-not $rel) { return $null }
    return Resolve-BardAsset -Asset $rel -Config $Config
}

function Get-BardThemePath {
    param(
        [string]$ThemeName,
        [object]$Config
    )

    if (-not $ThemeName) { $ThemeName = "default" }
    $rel = $Config.themes.$ThemeName
    if (-not $rel) { return $null }
    return Resolve-BardAsset -Asset $rel -Config $Config
}

function Invoke-BardPlayback {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return $false
    }

    $ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()

    try {
        if ($ext -eq ".wav") {
            $player = New-Object System.Media.SoundPlayer
            $player.SoundLocation = $FilePath
            $player.Load()
            $player.PlaySync()
            return $true
        }

        if ($ext -eq ".mp3") {
            $wmp = New-Object -ComObject WMPlayer.OCX
            $wmp.settings.volume = 100
            $wmp.URL = $FilePath
            $wmp.controls.play()
            $maxTicks = 120
            $ticks = 0
            while ($ticks -lt $maxTicks) {
                Start-Sleep -Milliseconds 250
                $state = $wmp.playState
                if ($state -eq 1 -or $state -eq 8 -or $state -eq 10) {
                    break
                }
                $ticks++
            }
            $wmp.controls.stop()
            return $true
        }
    } catch {
        return $false
    }

    return $false
}

function Get-BardAssetInventory {
    param([object]$Config)

    $items = @()
    foreach ($root in $Config.assetRoots) {
        if (-not $root) { continue }
        $expanded = $root -replace "~", $env:USERPROFILE
        if (-not (Test-Path $expanded)) { continue }
        $files = Get-ChildItem -Path $expanded -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Extension -match "^(?i)\.(wav|mp3)$"
        }
        foreach ($f in $files) {
            $items += [PSCustomObject]@{
                Root = $expanded
                File = $f.FullName
                SizeKB = [math]::Round($f.Length / 1KB, 1)
            }
        }
    }

    return $items
}
