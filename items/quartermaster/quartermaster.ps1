<#
.SYNOPSIS
  Quartermaster - agent-first Armory scout, plan, equip, and report loop.
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("scout", "plan", "equip", "report")]
    [string]$Action = "scout",
    [string]$Task,
    [int]$Top = 5,
    [string]$RepoPath = (Get-Location).Path,
    [string]$ArmoryRoot,
    [string]$PlanPath,
    [switch]$FromLastPlan,
    [switch]$Approve,
    [ValidateSet("saga", "civ")]
    [string]$Mode,
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$hooks = Join-Path $repoRoot "bard\lib\bard-hooks.ps1"
if (Test-Path $hooks) { . $hooks }

$soundContext = $null
if (Get-Command Initialize-ArmorySound -ErrorAction SilentlyContinue) {
    $soundContext = Initialize-ArmorySound -Sound:$Sound -NoSound:$NoSound -RepoRoot $repoRoot
    Invoke-ArmoryCue -Context $soundContext -Type start
}

function Show-HelpText {
    Write-Host ""
    Write-Host "  Quartermaster" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Agent-first Armory loop: refresh, scout, plan cart, equip, and report."
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\items\quartermaster\quartermaster.ps1 scout -Task \"repo problem\""
    Write-Host "    .\items\quartermaster\quartermaster.ps1 plan -Task \"release checks\" -Top 3"
    Write-Host "    .\items\quartermaster\quartermaster.ps1 equip -FromLastPlan -Approve"
    Write-Host "    .\items\quartermaster\quartermaster.ps1 report -FromLastPlan"
    Write-Host ""
}

function Expand-ArmoryPath {
    param([string]$PathValue)

    if (-not $PathValue) { return $PathValue }

    $expanded = [Environment]::ExpandEnvironmentVariables($PathValue)
    if ($expanded.StartsWith("~")) {
        $trimmed = $expanded.Substring(1).TrimStart('/', '\\')
        if ($trimmed) {
            return (Join-Path (Get-UserHome) $trimmed)
        }
        return (Get-UserHome)
    }

    return $expanded
}

function Get-UserHome {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($HOME) { return $HOME }
    return [Environment]::GetFolderPath("UserProfile")
}

function Get-ArmoryDir {
    return (Join-Path (Get-UserHome) ".armory")
}

function Get-ConfigPath {
    return (Join-Path (Get-ArmoryDir) "config.json")
}

function ConvertTo-Hashtable {
    param([object]$InputObject)

    $map = @{}
    if ($null -eq $InputObject) { return $map }

    foreach ($p in $InputObject.PSObject.Properties) {
        $map[$p.Name] = $p.Value
    }
    return $map
}

function Normalize-Mode {
    param([string]$Raw)

    if (-not $Raw) { return "saga" }
    $value = $Raw.Trim().ToLowerInvariant()
    if ($value -eq "civ") { return "civ" }
    if ($value -in @("saga", "lore", "crystal")) { return "saga" }
    return "saga"
}

function Read-ArmoryConfig {
    $path = Get-ConfigPath
    if (-not (Test-Path $path)) { return $null }

    try {
        return (Get-Content -Path $path -Raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Save-ArmoryConfig {
    param(
        [hashtable]$Config,
        [string]$RepoRoot
    )

    $armoryDir = Get-ArmoryDir
    if (-not (Test-Path $armoryDir)) {
        New-Item -ItemType Directory -Path $armoryDir -Force | Out-Null
    }

    if (-not $Config.ContainsKey("commandWord") -or -not [string]$Config["commandWord"]) {
        $Config["commandWord"] = "armory"
    }
    if (-not $Config.ContainsKey("installDir") -or -not [string]$Config["installDir"]) {
        $Config["installDir"] = Join-Path (Get-UserHome) "bin"
    }

    $modeValue = "saga"
    if ($Config.ContainsKey("mode")) {
        $modeValue = Normalize-Mode -Raw ([string]$Config["mode"])
    } elseif ($Config.ContainsKey("civilianAliases")) {
        if ([bool]$Config["civilianAliases"]) {
            $modeValue = "civ"
        }
    }

    $Config["mode"] = $modeValue
    $Config["civilianAliases"] = ($modeValue -eq "civ")
    $Config["repoRoot"] = $RepoRoot

    $configPath = Get-ConfigPath
    [PSCustomObject]$Config | ConvertTo-Json -Depth 12 | Set-Content -Path $configPath -Encoding UTF8
}

function Resolve-Mode {
    param(
        [hashtable]$Config,
        [string]$TargetRepoPath
    )

    if ($Mode) { return (Normalize-Mode -Raw $Mode) }

    if ($Config.ContainsKey("mode")) {
        return (Normalize-Mode -Raw ([string]$Config["mode"]))
    }

    if ($Config.ContainsKey("civilianAliases")) {
        if ([bool]$Config["civilianAliases"]) { return "civ" }
        return "saga"
    }

    $sovereignPath = Join-Path $TargetRepoPath ".sovereign.json"
    if (Test-Path $sovereignPath) {
        try {
            $obj = Get-Content -Path $sovereignPath -Raw | ConvertFrom-Json
            if ($obj.PSObject.Properties.Name -contains "mode") {
                return (Normalize-Mode -Raw ([string]$obj.mode))
            }
        } catch {
            # ignore parse errors and continue fallback chain
        }
    }

    if ($env:ARMORY_MODE) { return (Normalize-Mode -Raw $env:ARMORY_MODE) }
    if ($env:SOVEREIGN_MODE) { return (Normalize-Mode -Raw $env:SOVEREIGN_MODE) }
    return "saga"
}

function Test-IsArmoryRoot {
    param([string]$PathValue)

    if (-not $PathValue) { return $false }
    if (-not (Test-Path $PathValue)) { return $false }

    $required = @(
        (Join-Path $PathValue "awakening.ps1"),
        (Join-Path $PathValue "shop\catalog.json")
    )

    foreach ($item in $required) {
        if (-not (Test-Path $item)) { return $false }
    }

    return $true
}

function Resolve-ArmoryRoot {
    param([hashtable]$Config)

    $candidates = New-Object System.Collections.Generic.List[string]

    if ($ArmoryRoot) {
        $candidates.Add((Expand-ArmoryPath -PathValue $ArmoryRoot))
    }

    if ($Config.ContainsKey("repoRoot") -and [string]$Config["repoRoot"]) {
        $candidates.Add((Expand-ArmoryPath -PathValue ([string]$Config["repoRoot"])))
    }

    if ($env:ARMORY_REPO_ROOT) {
        $candidates.Add((Expand-ArmoryPath -PathValue $env:ARMORY_REPO_ROOT))
    }

    $cwd = (Get-Location).Path
    $parent = Split-Path $cwd -Parent
    $home = Get-UserHome
    $candidates.Add($cwd)
    $candidates.Add((Join-Path $cwd "armory"))
    if ($parent) {
        $candidates.Add((Join-Path $parent "armory"))
    }
    $candidates.Add((Join-Path $home "armory"))
    $candidates.Add((Join-Path (Join-Path $home "Documents\Code Repos") "armory"))

    $seen = @{}
    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $expanded = Expand-ArmoryPath -PathValue $candidate
        if (-not $expanded) { continue }

        $key = $expanded.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true

        if (Test-IsArmoryRoot -PathValue $expanded) {
            $resolved = (Resolve-Path $expanded).Path
            Save-ArmoryConfig -Config $Config -RepoRoot $resolved
            return $resolved
        }
    }

    Write-Host ""
    Write-Host "Armory path was not auto-discovered." -ForegroundColor Yellow
    Write-Host "Enter the Armory repository path once to persist it for future runs." -ForegroundColor Yellow
    $manual = Read-Host "Armory path"
    if ($manual) {
        $manualExpanded = Expand-ArmoryPath -PathValue $manual
        if (Test-IsArmoryRoot -PathValue $manualExpanded) {
            $resolved = (Resolve-Path $manualExpanded).Path
            Save-ArmoryConfig -Config $Config -RepoRoot $resolved
            return $resolved
        }
    }

    throw "Unable to resolve Armory path. Run setup with: powershell -ExecutionPolicy Bypass -File .\\setup.ps1"
}

function Get-ManifestData {
    param([string]$ArmoryRepoRoot)

    $manifestPath = Join-Path $ArmoryRepoRoot "docs\data\armory-manifest.v1.json"
    if (Test-Path $manifestPath) {
        return (Get-Content -Path $manifestPath -Raw | ConvertFrom-Json)
    }

    $catalogPath = Join-Path $ArmoryRepoRoot "shop\catalog.json"
    if (-not (Test-Path $catalogPath)) {
        throw "Missing catalog at $catalogPath"
    }

    $catalog = Get-Content -Path $catalogPath -Raw | ConvertFrom-Json
    $entries = @()
    foreach ($entry in @($catalog.entries)) {
        $entries += [PSCustomObject]@{
            id = $entry.id
            class = $entry.class
            status = $entry.status
            display = $entry.display
            tags = $entry.tags
            install = $entry.install
            source = [PSCustomObject]@{
                scriptPath = $entry.scriptPath
                readmePath = $entry.readmePath
            }
        }
    }

    return [PSCustomObject]@{
        ref = "local"
        entries = $entries
        agentFlow = [PSCustomObject]@{
            approvalRequired = $true
        }
    }
}

function Get-RepoContext {
    param([string]$TargetRepoPath)

    $resolvedPath = (Resolve-Path $TargetRepoPath).Path
    $repoTerms = New-Object System.Collections.Generic.List[string]

    $summary = New-Object System.Collections.Generic.List[string]
    $summary.Add("Repo path: $resolvedPath") | Out-Null

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $branch = & $git.Source -C $resolvedPath rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $branch) {
            $summary.Add("Git branch: $($branch.Trim())") | Out-Null
        }

        $dirtyLines = @(& $git.Source -C $resolvedPath status --porcelain 2>$null)
        if ($LASTEXITCODE -eq 0) {
            $summary.Add("Dirty files: $($dirtyLines.Count)") | Out-Null
            if ($dirtyLines.Count -gt 0) {
                $repoTerms.Add("stability") | Out-Null
                $repoTerms.Add("diagnostics") | Out-Null
            }
        }
    }

    $extCounts = @{}
    $files = @(Get-ChildItem -Path $resolvedPath -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 400)
    foreach ($file in $files) {
        $ext = [string]$file.Extension
        if (-not $extCounts.ContainsKey($ext)) {
            $extCounts[$ext] = 0
        }
        $extCounts[$ext]++
    }

    foreach ($ext in ($extCounts.Keys | Sort-Object { -1 * $extCounts[$_] } | Select-Object -First 5)) {
        switch ($ext.ToLowerInvariant()) {
            ".ps1" {
                $repoTerms.Add("powershell") | Out-Null
                $repoTerms.Add("automation") | Out-Null
                $repoTerms.Add("windows") | Out-Null
            }
            ".yml" {
                $repoTerms.Add("ci") | Out-Null
                $repoTerms.Add("release") | Out-Null
            }
            ".yaml" {
                $repoTerms.Add("ci") | Out-Null
                $repoTerms.Add("release") | Out-Null
            }
            ".py" {
                $repoTerms.Add("python") | Out-Null
            }
            ".md" {
                $repoTerms.Add("docs") | Out-Null
            }
        }
    }

    if (Test-Path (Join-Path $resolvedPath ".github\workflows")) {
        $repoTerms.Add("release") | Out-Null
        $repoTerms.Add("preflight") | Out-Null
    }

    $uniqueTerms = @($repoTerms | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)

    return [PSCustomObject]@{
        Path = $resolvedPath
        Summary = @($summary)
        Terms = $uniqueTerms
    }
}

function Get-TaskTerms {
    param(
        [string]$TaskValue,
        [string[]]$RepoTerms
    )

    $source = ""
    if ($TaskValue) {
        $source = $TaskValue
    }
    if ($RepoTerms -and $RepoTerms.Count -gt 0) {
        $source = ($source + " " + ($RepoTerms -join " ")).Trim()
    }

    if (-not $source) { return @() }

    $stopWords = @(
        "this", "that", "with", "from", "have", "need", "repo", "issue",
        "task", "help", "please", "about", "into", "when", "your", "their"
    )

    $tokens = @($source.ToLowerInvariant() -split "[^a-z0-9]+" | Where-Object { $_ -and $_.Length -ge 3 })
    $filtered = @($tokens | Where-Object { $stopWords -notcontains $_ } | Sort-Object -Unique)
    return $filtered
}

function Score-Entry {
    param(
        [object]$Entry,
        [string[]]$Terms
    )

    $score = 0
    $matched = New-Object System.Collections.Generic.List[string]

    $tagText = (@($Entry.tags) -join " ").ToLowerInvariant()
    $idText = ("$($Entry.id) $($Entry.class)").ToLowerInvariant()

    $displaySaga = ""
    $displayCiv = ""
    if ($Entry.display -and $Entry.display.saga) {
        $displaySaga = ("$($Entry.display.saga.name) $($Entry.display.saga.description)").ToLowerInvariant()
    }
    if ($Entry.display -and $Entry.display.civ) {
        $displayCiv = ("$($Entry.display.civ.name) $($Entry.display.civ.description)").ToLowerInvariant()
    }

    foreach ($term in @($Terms)) {
        if (-not $term) { continue }

        if ($idText -like "*$term*" -or $tagText -like "*$term*") {
            $score += 4
            $matched.Add($term) | Out-Null
        }

        if ($displaySaga -like "*$term*" -or $displayCiv -like "*$term*") {
            $score += 2
            $matched.Add($term) | Out-Null
        }
    }

    if ($score -eq 0) {
        if ($Entry.class -in @("item", "spell")) {
            $score = 2
        } else {
            $score = 1
        }
    }

    $matchedUnique = @($matched | Sort-Object -Unique)

    return [PSCustomObject]@{
        score = $score
        matched = $matchedUnique
    }
}

function Build-Shortlist {
    param(
        [object[]]$Entries,
        [string[]]$Terms,
        [int]$TopCount,
        [string]$ActiveMode
    )

    $rows = @()
    foreach ($entry in @($Entries)) {
        $scored = Score-Entry -Entry $entry -Terms $Terms

        $display = $null
        if ($entry.display) {
            if ($ActiveMode -eq "civ" -and $entry.display.civ) { $display = $entry.display.civ }
            if ($ActiveMode -eq "saga" -and $entry.display.saga) { $display = $entry.display.saga }
        }

        $name = if ($display -and $display.name) { [string]$display.name } else { [string]$entry.id }
        $description = if ($display -and $display.description) { [string]$display.description } else { "No description available." }

        $rationale = if (@($scored.matched).Count -gt 0) {
            "Matches task/context terms: $(@($scored.matched) -join ', ')."
        } else {
            "General-purpose active Armory tool for diagnostics/readiness."
        }

        $rows += [PSCustomObject]@{
            id = [string]$entry.id
            class = [string]$entry.class
            score = [int]$scored.score
            name = $name
            description = $description
            rationale = $rationale
            dependencies = @($entry.install.dependencies)
            entrypointPath = [string]$entry.install.entrypointPath
        }
    }

    return @($rows | Sort-Object @{ Expression = "score"; Descending = $true }, @{ Expression = "id"; Descending = $false } | Select-Object -First $TopCount)
}

function Expand-Dependencies {
    param(
        [string[]]$SeedIds,
        [hashtable]$EntryById
    )

    $ordered = New-Object System.Collections.Generic.List[string]
    $missing = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    $queue = New-Object System.Collections.Queue
    foreach ($seed in @($SeedIds)) {
        if ($seed) { $queue.Enqueue($seed) }
    }

    while ($queue.Count -gt 0) {
        $id = [string]$queue.Dequeue()
        if ($seen.ContainsKey($id)) { continue }
        $seen[$id] = $true

        if (-not $EntryById.ContainsKey($id)) {
            $missing.Add($id) | Out-Null
            continue
        }

        $ordered.Add($id) | Out-Null

        $entry = $EntryById[$id]
        foreach ($dep in @($entry.install.dependencies)) {
            if ($dep -and -not $seen.ContainsKey([string]$dep)) {
                $queue.Enqueue([string]$dep)
            }
        }
    }

    return [PSCustomObject]@{
        ids = @($ordered)
        missing = @($missing | Sort-Object -Unique)
    }
}

function Invoke-ArmoryRefresh {
    param([string]$ArmoryRepoRoot)

    $git = Get-Command git -ErrorAction SilentlyContinue
    $commandText = "git -C <armoryRepoRoot> pull --ff-only"

    if (-not $git) {
        return [PSCustomObject]@{
            success = $false
            command = $commandText
            output = "git not found on PATH"
        }
    }

    $output = & $git.Source -C $ArmoryRepoRoot pull --ff-only 2>&1 | Out-String
    $ok = ($LASTEXITCODE -eq 0)

    return [PSCustomObject]@{
        success = $ok
        command = $commandText
        output = $output.Trim()
    }
}

function Get-QuartermasterDir {
    return (Join-Path (Get-ArmoryDir) "quartermaster")
}

function Get-LastPlanPath {
    return (Join-Path (Get-QuartermasterDir) "last-plan.json")
}

function Resolve-PlanPath {
    if ($PlanPath) {
        return (Expand-ArmoryPath -PathValue $PlanPath)
    }

    if ($FromLastPlan) {
        return (Get-LastPlanPath)
    }

    return (Get-LastPlanPath)
}

function Write-PlanFile {
    param(
        [object]$Plan,
        [string]$TargetPath
    )

    $resolvedPath = Expand-ArmoryPath -PathValue $TargetPath
    $parent = Split-Path $resolvedPath -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $Plan | ConvertTo-Json -Depth 20 | Set-Content -Path $resolvedPath -Encoding UTF8
}

function Read-PlanFile {
    param([string]$TargetPath)

    $resolvedPath = Expand-ArmoryPath -PathValue $TargetPath
    if (-not (Test-Path $resolvedPath)) {
        throw "Plan file not found: $resolvedPath"
    }

    try {
        return (Get-Content -Path $resolvedPath -Raw | ConvertFrom-Json)
    } catch {
        throw "Plan file parse failed: $resolvedPath"
    }
}

function Ensure-PathContains {
    param([string]$InstallDir)

    $pathUser = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $pathUser) { $pathUser = "" }

    if ($pathUser -notlike "*${InstallDir}*") {
        if ($pathUser.Length -gt 0 -and -not $pathUser.EndsWith(";")) {
            [Environment]::SetEnvironmentVariable("Path", "$pathUser;$InstallDir", "User")
        } else {
            [Environment]::SetEnvironmentVariable("Path", "$pathUser$InstallDir", "User")
        }
    }
}

function Write-ScoutReport {
    param(
        [string]$ActiveMode,
        [string]$TaskSummary,
        [object]$RepoContext,
        [object[]]$Shortlist,
        [object]$DependencyResult
    )

    Write-Host ""
    if ($ActiveMode -eq "civ") {
        Write-Host "Quartermaster scout report" -ForegroundColor Cyan
        Write-Host "------------------------" -ForegroundColor DarkGray
    } else {
        Write-Host "Quartermaster scout report" -ForegroundColor Cyan
        Write-Host "------------------------" -ForegroundColor DarkGray
        Write-Host "Crystal resonance confirmed. Scouting report follows." -ForegroundColor Yellow
    }

    Write-Host "Task context: $TaskSummary" -ForegroundColor White
    foreach ($line in @($RepoContext.Summary)) {
        Write-Host "- $line" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "Recommended loadout:" -ForegroundColor Green
    foreach ($item in @($Shortlist)) {
        $deps = if (@($item.dependencies).Count -gt 0) { @($item.dependencies) -join ", " } else { "none" }
        Write-Host ("- {0} ({1})" -f $item.id, $item.class) -ForegroundColor White
        Write-Host ("  Why: {0}" -f $item.rationale) -ForegroundColor DarkGray
        Write-Host ("  Dependencies: {0}" -f $deps) -ForegroundColor DarkGray
    }

    if (@($DependencyResult.missing).Count -gt 0) {
        Write-Host ""
        Write-Host ("Dependency warnings: missing entries [{0}]" -f (@($DependencyResult.missing) -join ", ")) -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Risk/impact: tools are read-only unless you run equip/install actions." -ForegroundColor Yellow
    Write-Host "Full catalog available on request." -ForegroundColor Cyan
    Write-Host ""
}

function Write-EquipReport {
    param(
        [string]$ActiveMode,
        [string[]]$InstalledIds,
        [string[]]$FailedIds,
        [string]$InstallDir
    )

    Write-Host ""
    if ($ActiveMode -eq "civ") {
        Write-Host "Install complete." -ForegroundColor Green
    } else {
        Write-Host "Loadout equipped. The party is battle-ready." -ForegroundColor Green
    }

    Write-Host ("Installed tool IDs: {0}" -f ((@($InstalledIds) | Sort-Object) -join ", ")) -ForegroundColor White
    if (@($FailedIds).Count -gt 0) {
        Write-Host ("Failed tool IDs: {0}" -f ((@($FailedIds) | Sort-Object) -join ", ")) -ForegroundColor Red
    }
    Write-Host ("Install directory: {0}" -f $InstallDir) -ForegroundColor DarkGray
    Write-Host ""
}

function Write-FailureReport {
    param(
        [string]$ActiveMode,
        [string]$Headline,
        [string]$Detail
    )

    Write-Host ""
    if ($ActiveMode -eq "civ") {
        Write-Host $Headline -ForegroundColor Red
    } else {
        Write-Host "Tactical setback: $Headline" -ForegroundColor Red
    }
    if ($Detail) {
        Write-Host $Detail -ForegroundColor DarkGray
    }
    Write-Host ""
}

if ($Help) {
    Show-HelpText
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if (-not (Test-Path $RepoPath)) {
    Write-Host "RepoPath not found: $RepoPath" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

if ($Top -lt 1) { $Top = 1 }

$configObject = Read-ArmoryConfig
$config = ConvertTo-Hashtable -InputObject $configObject
$resolvedRepoPath = (Resolve-Path $RepoPath).Path
$armoryRepoRoot = $null
$activeMode = "saga"

try {
    $armoryRepoRoot = Resolve-ArmoryRoot -Config $config
    $activeMode = Resolve-Mode -Config $config -TargetRepoPath $resolvedRepoPath
} catch {
    Write-FailureReport -ActiveMode "civ" -Headline "Armory root resolution failed" -Detail $_.Exception.Message
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

switch ($Action) {
    "scout" {
        if (-not $Task) {
            Write-Host "Task is required for scout. Example: quartermaster scout -Task \"release readiness\"" -ForegroundColor Red
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            exit 1
        }

        $refresh = Invoke-ArmoryRefresh -ArmoryRepoRoot $armoryRepoRoot
        if (-not $refresh.success) {
            Write-FailureReport -ActiveMode $activeMode -Headline "Armory refresh failed; stopping before scout." -Detail $refresh.output
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            exit 1
        }

        $manifest = Get-ManifestData -ArmoryRepoRoot $armoryRepoRoot
        $entries = @($manifest.entries | Where-Object {
            $_.status -eq "active" -and
            $_.install -and
            $_.install.entrypointPath -and
            $_.class -ne "idea"
        })

        $repoContext = Get-RepoContext -TargetRepoPath $resolvedRepoPath
        $terms = Get-TaskTerms -TaskValue $Task -RepoTerms @($repoContext.Terms)
        $shortlist = Build-Shortlist -Entries $entries -Terms $terms -TopCount $Top -ActiveMode $activeMode

        $entryById = @{}
        foreach ($entry in @($entries)) {
            $entryById[[string]$entry.id] = $entry
        }
        $depResult = Expand-Dependencies -SeedIds @($shortlist | ForEach-Object { $_.id }) -EntryById $entryById

        Write-ScoutReport -ActiveMode $activeMode -TaskSummary $Task -RepoContext $repoContext -Shortlist $shortlist -DependencyResult $depResult
        if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
        exit 0
    }

    "plan" {
        if (-not $Task) {
            Write-Host "Task is required for plan. Example: quartermaster plan -Task \"release readiness\"" -ForegroundColor Red
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            exit 1
        }

        $refresh = Invoke-ArmoryRefresh -ArmoryRepoRoot $armoryRepoRoot
        if (-not $refresh.success) {
            Write-FailureReport -ActiveMode $activeMode -Headline "Armory refresh failed; stopping before cart planning." -Detail $refresh.output
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            exit 1
        }

        $manifest = Get-ManifestData -ArmoryRepoRoot $armoryRepoRoot
        $entries = @($manifest.entries | Where-Object {
            $_.status -eq "active" -and
            $_.install -and
            $_.install.entrypointPath -and
            $_.class -ne "idea"
        })

        $repoContext = Get-RepoContext -TargetRepoPath $resolvedRepoPath
        $terms = Get-TaskTerms -TaskValue $Task -RepoTerms @($repoContext.Terms)
        $shortlist = Build-Shortlist -Entries $entries -Terms $terms -TopCount $Top -ActiveMode $activeMode

        $entryById = @{}
        foreach ($entry in @($entries)) {
            $entryById[[string]$entry.id] = $entry
        }

        $depResult = Expand-Dependencies -SeedIds @($shortlist | ForEach-Object { $_.id }) -EntryById $entryById
        $loadoutEntries = @()
        foreach ($id in @($depResult.ids)) {
            if (-not $entryById.ContainsKey($id)) { continue }
            $entry = $entryById[$id]
            $display = if ($activeMode -eq "civ") { $entry.display.civ } else { $entry.display.saga }
            $loadoutEntries += [PSCustomObject]@{
                id = [string]$entry.id
                class = [string]$entry.class
                name = if ($display -and $display.name) { [string]$display.name } else { [string]$entry.id }
                description = if ($display -and $display.description) { [string]$display.description } else { "No description available." }
                entrypointPath = [string]$entry.install.entrypointPath
                dependencies = @($entry.install.dependencies)
            }
        }

        $planObject = [PSCustomObject]@{
            planVersion = 1
            status = "planned"
            createdAt = (Get-Date).ToString("o")
            mode = $activeMode
            task = $Task
            repoPath = $resolvedRepoPath
            armoryRoot = $armoryRepoRoot
            shortlist = @($shortlist | ForEach-Object { $_.id })
            loadout = @($depResult.ids)
            dependencyMissing = @($depResult.missing)
            loadoutEntries = $loadoutEntries
            refresh = $refresh
            approvalRequired = $true
            approved = $false
            approvedAt = $null
            equip = [PSCustomObject]@{
                installed = @()
                failed = @()
                installDir = ""
                completedAt = $null
            }
        }

        $targetPlanPath = Resolve-PlanPath
        Write-PlanFile -Plan $planObject -TargetPath $targetPlanPath
        Write-PlanFile -Plan $planObject -TargetPath (Get-LastPlanPath)

        Write-ScoutReport -ActiveMode $activeMode -TaskSummary $Task -RepoContext $repoContext -Shortlist $shortlist -DependencyResult $depResult
        Write-Host ("Cart prepared: {0}" -f ((@($depResult.ids) | Sort-Object) -join ", ")) -ForegroundColor Cyan
        Write-Host ("Plan saved: {0}" -f (Resolve-PlanPath)) -ForegroundColor DarkGray
        Write-Host "Approval required before equip. Run: quartermaster equip -FromLastPlan -Approve" -ForegroundColor Yellow

        if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
        exit 0
    }

    "equip" {
        $targetPlanPath = Resolve-PlanPath
        $planObject = $null
        try {
            $planObject = Read-PlanFile -TargetPath $targetPlanPath
        } catch {
            Write-FailureReport -ActiveMode $activeMode -Headline "No plan available for equip." -Detail $_.Exception.Message
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            exit 1
        }

        if (-not $Approve) {
            Write-FailureReport -ActiveMode $activeMode -Headline "Approval gate not satisfied." -Detail "Re-run with -Approve after explicit human approval."
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            exit 1
        }

        $planArmoryRoot = if ($planObject.armoryRoot) { [string]$planObject.armoryRoot } else { $armoryRepoRoot }
        if (-not (Test-IsArmoryRoot -PathValue $planArmoryRoot)) {
            Write-FailureReport -ActiveMode $activeMode -Headline "Plan Armory root is invalid." -Detail $planArmoryRoot
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            exit 1
        }

        if (-not $config.ContainsKey("installDir") -or -not [string]$config["installDir"]) {
            $config["installDir"] = Join-Path (Get-UserHome) "bin"
        }

        $installDir = Expand-ArmoryPath -PathValue ([string]$config["installDir"])
        if (-not (Test-Path $installDir)) {
            New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        }

        $installed = New-Object System.Collections.Generic.List[string]
        $failed = New-Object System.Collections.Generic.List[string]

        foreach ($toolId in @($planObject.loadout)) {
            $entry = @($planObject.loadoutEntries | Where-Object { [string]$_.id -eq [string]$toolId } | Select-Object -First 1)
            if ($entry.Count -eq 0) {
                $failed.Add([string]$toolId) | Out-Null
                continue
            }

            $entrypoint = [string]$entry[0].entrypointPath
            if (-not $entrypoint) {
                $failed.Add([string]$toolId) | Out-Null
                continue
            }

            $scriptPath = Join-Path $planArmoryRoot $entrypoint
            if (-not (Test-Path $scriptPath)) {
                $failed.Add([string]$toolId) | Out-Null
                continue
            }

            $wrapperPath = Join-Path $installDir ("{0}.cmd" -f [string]$toolId)
            $wrapperLines = @(
                "@echo off",
                "setlocal",
                "set `"ARMORY_ROOT=$planArmoryRoot`"",
                "powershell -ExecutionPolicy Bypass -File `"%ARMORY_ROOT%\\$entrypoint`" %*",
                "exit /b %errorlevel%"
            )
            Set-Content -Path $wrapperPath -Value ($wrapperLines -join "`r`n") -Encoding ASCII
            $installed.Add([string]$toolId) | Out-Null
        }

        Ensure-PathContains -InstallDir $installDir

        $planObject.status = if ($failed.Count -gt 0) { "partial" } else { "equipped" }
        $planObject.approved = $true
        $planObject.approvedAt = (Get-Date).ToString("o")
        $planObject.mode = $activeMode
        $planObject.equip = [PSCustomObject]@{
            installed = @($installed)
            failed = @($failed)
            installDir = $installDir
            completedAt = (Get-Date).ToString("o")
        }

        Write-PlanFile -Plan $planObject -TargetPath $targetPlanPath
        Write-PlanFile -Plan $planObject -TargetPath (Get-LastPlanPath)

        Write-EquipReport -ActiveMode $activeMode -InstalledIds @($installed) -FailedIds @($failed) -InstallDir $installDir

        if ($failed.Count -gt 0) {
            Write-Host "Tactical report: partial equip complete, resolve failed IDs before continuing." -ForegroundColor Yellow
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            exit 1
        }

        if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
        exit 0
    }

    "report" {
        $targetPlanPath = Resolve-PlanPath
        $planObject = $null
        try {
            $planObject = Read-PlanFile -TargetPath $targetPlanPath
        } catch {
            Write-FailureReport -ActiveMode $activeMode -Headline "No saved plan/report data." -Detail $_.Exception.Message
            if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
            exit 1
        }

        $reportMode = if ($planObject.mode) { Normalize-Mode -Raw ([string]$planObject.mode) } else { $activeMode }
        $installed = @($planObject.equip.installed)
        $failed = @($planObject.equip.failed)

        Write-Host ""
        if ($reportMode -eq "civ") {
            Write-Host "Quartermaster status report" -ForegroundColor Cyan
            Write-Host "-------------------------" -ForegroundColor DarkGray
            Write-Host ("Status: {0}" -f [string]$planObject.status) -ForegroundColor White
            Write-Host ("Installed tool IDs: {0}" -f (($installed | Sort-Object) -join ", ")) -ForegroundColor White
            if ($failed.Count -gt 0) {
                Write-Host ("Failed tool IDs: {0}" -f (($failed | Sort-Object) -join ", ")) -ForegroundColor Yellow
            }
        } else {
            Write-Host "Quartermaster field report" -ForegroundColor Cyan
            Write-Host "------------------------" -ForegroundColor DarkGray
            Write-Host ("Quest status: {0}" -f [string]$planObject.status) -ForegroundColor White
            Write-Host ("Equipped tool IDs: {0}" -f (($installed | Sort-Object) -join ", ")) -ForegroundColor White
            if ($failed.Count -gt 0) {
                Write-Host ("Unresolved tool IDs: {0}" -f (($failed | Sort-Object) -join ", ")) -ForegroundColor Yellow
            }
        }

        $shadowPath = Join-Path ([string]$planObject.armoryRoot) "governance\seven-shadow-system"
        if (Test-Path $shadowPath) {
            Write-Host "Seven Shadow path detected. Run real shadow checks before final sign-off." -ForegroundColor Yellow
        } else {
            Write-Host "Seven Shadow path not found; reported and continuing with Armory-native checks." -ForegroundColor DarkGray
        }

        Write-Host ""
        if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
        exit 0
    }
}
