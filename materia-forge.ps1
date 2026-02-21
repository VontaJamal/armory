<#
.SYNOPSIS
  Materia Forge - scaffold new Armory shop entries and starter tool files.
#>

param(
    [ValidateSet("summon", "weapon", "spell", "item", "audio", "idea")]
    [string]$Category,
    [string]$Name,
    [string]$Id,
    [string]$Description,
    [string]$FlavorLine,
    [ValidateSet("active", "idea", "planned", "deprecated")]
    [string]$Status,
    [string]$Owner = "community",
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function ConvertTo-Slug {
    param([string]$Text)

    if (-not $Text) { return "" }
    $slug = $Text.ToLowerInvariant()
    $slug = [regex]::Replace($slug, "[^a-z0-9]+", "-")
    $slug = [regex]::Replace($slug, "^-+|-+$", "")
    $slug = [regex]::Replace($slug, "-+", "-")
    return $slug
}

function Prompt-ForValue {
    param(
        [string]$Current,
        [string]$Prompt,
        [string]$Default
    )

    if ($Current) { return $Current }
    if ($Default) {
        $inputValue = Read-Host "$Prompt [$Default]"
        if (-not $inputValue) { return $Default }
        return $inputValue
    }
    return (Read-Host $Prompt)
}

function Show-HelpText {
    Write-Host ""
    Write-Host "  Materia Forge" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Scaffolds a new Armory tool (or idea-only shop entry)."
    Write-Host ""
    Write-Host "  Usage examples:"
    Write-Host "    .\\materia-forge.ps1 -Category weapon -Name \"Pulse Shield\" -Description \"Service restart helper\""
    Write-Host "    .\\materia-forge.ps1 -Category idea -Name \"Mognet\" -Description \"Notification relay\" -FlavorLine \"Reliable message network\""
    Write-Host "    .\\materia-forge.ps1 -Category spell -Name \"Chrono Check\" -DryRun"
    Write-Host ""
}

if ($Help) {
    Show-HelpText
    exit 0
}

$categoryMap = @{
    summon = "summons"
    weapon = "weapons"
    spell = "spells"
    item = "items"
    audio = "bard"
    idea = $null
}

$Category = Prompt-ForValue -Current $Category -Prompt "Category (summon|weapon|spell|item|audio|idea)" -Default ""
if (-not $categoryMap.ContainsKey($Category)) {
    Write-Host "Invalid category: $Category" -ForegroundColor Red
    exit 1
}

$Name = Prompt-ForValue -Current $Name -Prompt "Display name" -Default ""
if (-not $Name) {
    Write-Host "Name is required." -ForegroundColor Red
    exit 1
}

if (-not $Id) {
    $Id = ConvertTo-Slug -Text $Name
}
if (-not $Id) {
    $Id = Prompt-ForValue -Current $Id -Prompt "ID (kebab-case)" -Default ""
}
$Id = ConvertTo-Slug -Text $Id
if (-not $Id) {
    Write-Host "ID is required." -ForegroundColor Red
    exit 1
}

$Description = Prompt-ForValue -Current $Description -Prompt "Plain description" -Default "Useful Armory tool"
$FlavorLine = Prompt-ForValue -Current $FlavorLine -Prompt "Flavor line" -Default "A practical tool for your ops kit."

if (-not $Status) {
    if ($Category -eq "idea") {
        $Status = "idea"
    } else {
        $Status = "active"
    }
}

if ($Category -eq "idea" -and $Status -ne "idea") {
    Write-Host "Category 'idea' requires status 'idea'. Using status=idea." -ForegroundColor Yellow
    $Status = "idea"
}

if ($Category -ne "idea" -and $Status -eq "idea") {
    Write-Host "Non-idea categories cannot use status 'idea'. Use active/planned/deprecated." -ForegroundColor Red
    exit 1
}

$addedOn = (Get-Date).ToString("yyyy-MM-dd")
$repoRoot = (Resolve-Path $PSScriptRoot).Path
$catalogPath = Join-Path $repoRoot "shop\catalog.json"
$shopPath = Join-Path $repoRoot "shop\SHOP.md"

$scriptPath = $null
$readmePath = $null
$changedFiles = New-Object System.Collections.Generic.List[string]
$createdFiles = New-Object System.Collections.Generic.List[string]

if ($Category -ne "idea") {
    $baseFolder = $categoryMap[$Category]
    $toolDirRel = "$baseFolder/$Id"
    $toolDir = Join-Path $repoRoot $toolDirRel
    $scriptPath = "$toolDirRel/$Id.ps1"
    $readmePath = "$toolDirRel/README.md"

    if ($DryRun) {
        $createdFiles.Add($toolDirRel) | Out-Null
        $createdFiles.Add($scriptPath) | Out-Null
        $createdFiles.Add($readmePath) | Out-Null
    } else {
        if (-not (Test-Path $toolDir)) {
            New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
            $createdFiles.Add($toolDirRel) | Out-Null
        }

        $scriptFullPath = Join-Path $repoRoot $scriptPath
        if (-not (Test-Path $scriptFullPath)) {
            $scriptContent = @"
<#
.SYNOPSIS
  $Name - $Description
#>

param(
    [switch]`$Help,
    [switch]`$Sound,
    [switch]`$NoSound
)

`$ErrorActionPreference = "Stop"

`$config = @{
    # Add tool-specific defaults here.
}

function Show-HelpText {
    Write-Host ""
    Write-Host "  $Name" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  What this does: $Description"
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\$Id.ps1 -Help"
    Write-Host ""
}

if (`$Help) {
    Show-HelpText
    exit 0
}

Write-Host "Not implemented yet. Update this script with your tool logic." -ForegroundColor Yellow
exit 0
"@
            Set-Content -Path $scriptFullPath -Value $scriptContent -Encoding UTF8
            $createdFiles.Add($scriptPath) | Out-Null
        }

        $readmeFullPath = Join-Path $repoRoot $readmePath
        if (-not (Test-Path $readmeFullPath)) {
            $readmeContent = @"
# $Name

## What This Does

$Description

## Who This Is For

- People who need this workflow in daily operations.
- Contributors who want a practical starter and clear docs.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\\$scriptPath -Help
```

## Common Tasks

```powershell
# Run the tool
powershell -ExecutionPolicy Bypass -File .\\$scriptPath
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-Help` | off | Show usage and exit. |
| `-Sound` | off | Enable optional sound cues. |
| `-NoSound` | off | Disable optional sound cues. |

## Config

Describe config keys in the script-level `\$config` block.

## Output And Exit Codes

- `0`: command completed successfully.
- `1`: command failed validation or runtime checks.

## Troubleshooting

- If command fails, run with `-Help` and verify file paths/config.
- Confirm dependencies are installed before automating this script.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\\$scriptPath
```

## FAQ

**Why is this scaffold minimal?**
It gives you a reliable shell plus docs contract sections to fill in.

## Migration Notes

- New tool scaffolded via `materia-forge.ps1` on $addedOn.
"@
            Set-Content -Path $readmeFullPath -Value $readmeContent -Encoding UTF8
            $createdFiles.Add($readmePath) | Out-Null
        }
    }
}

if (-not (Test-Path $catalogPath)) {
    if ($DryRun) {
        $changedFiles.Add("shop/catalog.json (new)") | Out-Null
    } else {
        @{ version = 1; entries = @() } | ConvertTo-Json -Depth 8 | Set-Content -Path $catalogPath -Encoding UTF8
        $changedFiles.Add("shop/catalog.json") | Out-Null
    }
}

$catalog = if (Test-Path $catalogPath) { Get-Content -Path $catalogPath -Raw | ConvertFrom-Json } else { [PSCustomObject]@{ version = 1; entries = @() } }
$entries = @($catalog.entries)

$newEntry = [ordered]@{
    id = $Id
    class = $Category
    name = $Name
    plainDescription = $Description
    flavorLine = $FlavorLine
    scriptPath = if ($Category -eq "idea") { $null } else { $scriptPath }
    readmePath = if ($Category -eq "idea") { $null } else { $readmePath }
    status = $Status
    owner = $Owner
    addedOn = $addedOn
}

$existingIndex = -1
for ($i = 0; $i -lt $entries.Count; $i++) {
    if ($entries[$i].id -eq $Id) {
        $existingIndex = $i
        break
    }
}

if ($existingIndex -ge 0) {
    $entries[$existingIndex] = [PSCustomObject]$newEntry
} else {
    $entries += [PSCustomObject]$newEntry
}

if ($DryRun) {
    $changedFiles.Add("shop/catalog.json") | Out-Null
} else {
    $catalogOut = [ordered]@{
        version = [int]$catalog.version
        entries = @($entries)
    }
    $catalogOut | ConvertTo-Json -Depth 10 | Set-Content -Path $catalogPath -Encoding UTF8
    $changedFiles.Add("shop/catalog.json") | Out-Null
}

if (-not (Test-Path $shopPath)) {
    if ($DryRun) {
        $changedFiles.Add("shop/SHOP.md (new)") | Out-Null
    } else {
        Set-Content -Path $shopPath -Value "# Armory Shop`r`n" -Encoding UTF8
        $changedFiles.Add("shop/SHOP.md") | Out-Null
    }
}

$shopHeader = "## Catalog Stubs (Auto-Generated)"
$tick = [char]96
$stubLine = "- $tick$Id$tick ($Category/$Status): $Description"

if ($DryRun) {
    $changedFiles.Add("shop/SHOP.md") | Out-Null
} else {
    $shopText = Get-Content -Path $shopPath -Raw
    if ($shopText -notmatch [regex]::Escape($shopHeader)) {
        $shopText = $shopText.TrimEnd() + "`r`n`r`n$shopHeader`r`n"
    }

    $pattern = "(?m)^- " + [regex]::Escape("$tick$Id$tick") + " \([^\)]*\): .*$"
    if ($shopText -match $pattern) {
        $shopText = [regex]::Replace($shopText, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $stubLine })
    } else {
        if (-not $shopText.EndsWith("`n")) {
            $shopText += "`r`n"
        }
        $shopText += "$stubLine`r`n"
    }

    Set-Content -Path $shopPath -Value $shopText -Encoding UTF8
    $changedFiles.Add("shop/SHOP.md") | Out-Null
}

Write-Host ""
Write-Host "Materia Forge Summary" -ForegroundColor Green
Write-Host "---------------------" -ForegroundColor DarkGray
Write-Host "Category:    $Category"
Write-Host "Name:        $Name"
Write-Host "Id:          $Id"
Write-Host "Status:      $Status"
Write-Host "Owner:       $Owner"
Write-Host "DryRun:      $DryRun"
Write-Host ""

if ($createdFiles.Count -gt 0) {
    Write-Host "Created:" -ForegroundColor Cyan
    foreach ($f in $createdFiles) {
        Write-Host "  - $f"
    }
    Write-Host ""
}

if ($changedFiles.Count -gt 0) {
    Write-Host "Updated:" -ForegroundColor Cyan
    foreach ($f in ($changedFiles | Sort-Object -Unique)) {
        Write-Host "  - $f"
    }
    Write-Host ""
}

if ($DryRun) {
    Write-Host "Dry run complete. No files were written." -ForegroundColor Yellow
}

exit 0
