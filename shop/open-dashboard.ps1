<#
.SYNOPSIS
  Open the Armory dashboard with mode hint from shared config.
#>

param(
    [string]$DashboardUrl = "https://vontajamal.github.io/armory/"
)

$ErrorActionPreference = "Stop"

function Resolve-Mode {
    $cfgPath = Join-Path $env:USERPROFILE ".armory\config.json"
    if (Test-Path $cfgPath) {
        try {
            $cfg = Get-Content -Path $cfgPath -Raw | ConvertFrom-Json
            if ($cfg.PSObject.Properties.Name -contains "mode") {
                $raw = [string]$cfg.mode
                if ($raw -eq "civ") { return "civ" }
                if ($raw -in @("saga", "lore", "crystal")) { return "saga" }
            }
            if ($cfg.PSObject.Properties.Name -contains "civilianAliases") {
                if ([bool]$cfg.civilianAliases) { return "civ" }
                return "saga"
            }
        } catch {
            return "saga"
        }
    }

    return "saga"
}

$mode = Resolve-Mode
$target = "$($DashboardUrl.TrimEnd('/'))/?mode=$mode"
Start-Process $target
Write-Host "Opened Armory dashboard: $target" -ForegroundColor Green
