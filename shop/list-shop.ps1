<#
.SYNOPSIS
  List Armory shop catalog entries with filtering and output formats.
#>

param(
    [ValidateSet("summon", "weapon", "spell", "item", "audio", "idea")]
    [string]$Class,
    [ValidateSet("active", "idea", "planned", "deprecated")]
    [string]$Status,
    [switch]$IdeasOnly,
    [ValidateSet("saga", "civ")]
    [string]$Mode,
    [ValidateSet("table", "json", "markdown")]
    [string]$Format = "table",
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-HelpText {
    Write-Host ""
    Write-Host "  shop/list-shop.ps1" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Browse Armory shop catalog entries."
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\shop\\list-shop.ps1"
    Write-Host "    .\\shop\\list-shop.ps1 -Class weapon -Status active"
    Write-Host "    .\\shop\\list-shop.ps1 -IdeasOnly -Format markdown"
    Write-Host "    .\\shop\\list-shop.ps1 -Mode civ"
    Write-Host "    .\\shop\\list-shop.ps1 -Format json"
    Write-Host ""
}

function Resolve-ModeFromConfig {
    if ($Mode) { return $Mode }

    $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($HOME) { $HOME } else { [Environment]::GetFolderPath("UserProfile") }
    $cfgPath = Join-Path $userHome ".armory\config.json"
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
            # fall through to default
        }
    }

    return "saga"
}

if ($Help) {
    Show-HelpText
    exit 0
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$catalogPath = Join-Path $repoRoot "shop\catalog.json"

if (-not (Test-Path $catalogPath)) {
    Write-Host "Catalog file not found: $catalogPath" -ForegroundColor Red
    exit 1
}

$catalog = Get-Content -Path $catalogPath -Raw | ConvertFrom-Json
$entries = @($catalog.entries)
$resolvedMode = Resolve-ModeFromConfig

if ($IdeasOnly) {
    $entries = @($entries | Where-Object { $_.class -eq "idea" -or $_.status -eq "idea" })
}
if ($Class) {
    $entries = @($entries | Where-Object { $_.class -eq $Class })
}
if ($Status) {
    $entries = @($entries | Where-Object { $_.status -eq $Status })
}

$entries = @($entries | Sort-Object class, name)

$display = @(
    $entries | ForEach-Object {
        [PSCustomObject]@{
            Class = $_.class
            Name = $_.name
            Status = $_.status
            Id = $_.id
            Description = if ($_.display -and $_.display.$resolvedMode -and $_.display.$resolvedMode.description) { $_.display.$resolvedMode.description } else { $_.plainDescription }
            Script = if ($_.scriptPath) { $_.scriptPath } else { "-" }
        }
    }
)

switch ($Format) {
    "json" {
        $entries | ConvertTo-Json -Depth 10
        exit 0
    }
    "markdown" {
        Write-Output "| Class | Name | Status | ID | Description |"
        Write-Output "|---|---|---|---|---|"
        foreach ($row in $display) {
            $safeDescription = ($row.Description -replace "\|", "/")
            Write-Output ("| {0} | {1} | {2} | {3} | {4} |" -f $row.Class, $row.Name, $row.Status, $row.Id, $safeDescription)
        }
        exit 0
    }
    default {
        Write-Host ""
        Write-Host "Armory Shop Catalog" -ForegroundColor Cyan
        Write-Host "-------------------" -ForegroundColor DarkGray
        if ($display.Count -eq 0) {
            Write-Host "No entries matched your filters." -ForegroundColor Yellow
            Write-Host ""
            exit 0
        }
        $display | Format-Table Class, Name, Status, Id, Script -AutoSize
        Write-Host ""
        exit 0
    }
}
