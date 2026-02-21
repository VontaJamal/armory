<#
.SYNOPSIS
  Chronicle - cross-repo git status and timeline intelligence.
#>

param(
    [string]$ReposFile = "~/.armory/repos.json",
    [string[]]$RepoPath,
    [ValidateSet("table", "json", "markdown")]
    [string]$Format = "table",
    [switch]$Detailed,
    [string]$Output,
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Continue"

$hookCandidates = @(
    (Join-Path $PSScriptRoot "..\..\bard\lib\bard-hooks.ps1"),
    (Join-Path $PSScriptRoot "..\bard\lib\bard-hooks.ps1")
)
foreach ($h in $hookCandidates) {
    if (Test-Path $h) { . $h; break }
}

$soundContext = $null
if (Get-Command Initialize-ArmorySound -ErrorAction SilentlyContinue) {
    $soundContext = Initialize-ArmorySound -Sound:$Sound -NoSound:$NoSound
    Invoke-ArmoryCue -Context $soundContext -Type start
}

function Expand-ArmoryPath {
    param([string]$PathValue)

    if (-not $PathValue) { return $PathValue }

    $expanded = [Environment]::ExpandEnvironmentVariables($PathValue)
    if ($expanded.StartsWith("~")) {
        $trimmed = $expanded.Substring(1).TrimStart("/", "\\")
        if ($trimmed) {
            return (Join-Path $HOME $trimmed)
        }
        return $HOME
    }

    return $expanded
}

function Show-HelpText {
    Write-Host ""
    Write-Host "  Chronicle" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\chronicle.ps1"
    Write-Host "    .\\chronicle.ps1 -Format json"
    Write-Host "    .\\chronicle.ps1 -Detailed"
    Write-Host "    .\\chronicle.ps1 -RepoPath \"D:\\Code Repos\\faye\",\"D:\\Code Repos\\shadow-gate\""
    Write-Host "    .\\chronicle.ps1 -ReposFile \"$env:USERPROFILE\\.armory\\repos.json\""
    Write-Host ""
}

function Get-ReposFromAllowlist {
    param([string]$PathValue)

    $filePath = Expand-ArmoryPath -PathValue $PathValue
    if (-not (Test-Path $filePath)) {
        $parent = Split-Path $filePath -Parent
        if ($parent -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        $starter = [ordered]@{
            repos = @()
            note = "Add absolute repo paths to repos[]"
        }
        $starter | ConvertTo-Json -Depth 5 | Set-Content -Path $filePath -Encoding UTF8

        Write-Host "Created starter repos file: $filePath" -ForegroundColor Yellow
        Write-Host "Add repo paths under repos[] and rerun Chronicle." -ForegroundColor Yellow
        return @()
    }

    try {
        $raw = Get-Content -Path $filePath -Raw
        $json = $raw | ConvertFrom-Json
    } catch {
        Write-Host "Failed to parse repos file: $filePath" -ForegroundColor Red
        return $null
    }

    $repos = @()
    if ($json.PSObject.Properties.Name -contains "repos") {
        foreach ($entry in @($json.repos)) {
            if ($entry) {
                $repos += [string]$entry
            }
        }
    }

    return $repos
}

function Get-ChronicleRecord {
    param([string]$InputPath)

    $expanded = Expand-ArmoryPath -PathValue $InputPath
    $resolvedPath = $expanded
    if (Test-Path $expanded) {
        $resolvedPath = (Resolve-Path $expanded).Path
    }

    $repoName = Split-Path $resolvedPath -Leaf
    if (-not $repoName) { $repoName = $InputPath }

    $record = [ordered]@{
        Repo = $repoName
        Path = $resolvedPath
        State = "missing"
        Branch = "-"
        Ahead = 0
        Behind = 0
        Dirty = 0
        Untracked = 0
        LastCommits = @()
    }

    if (-not (Test-Path $expanded)) {
        return [PSCustomObject]$record
    }

    if (-not (Test-Path (Join-Path $expanded ".git"))) {
        $record.State = "not-git"
        return [PSCustomObject]$record
    }

    $record.State = "ok"

    $branch = git -C $expanded rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $branch) {
        $record.Branch = $branch.Trim()
    }

    $statusLines = @(git -C $expanded status --porcelain 2>$null)
    if ($LASTEXITCODE -eq 0) {
        foreach ($line in $statusLines) {
            if (-not $line) { continue }
            if ($line.StartsWith("??")) {
                $record.Untracked++
            } else {
                $record.Dirty++
            }
        }
    }

    $upstream = git -C $expanded rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>$null
    if ($LASTEXITCODE -eq 0 -and $upstream) {
        $aheadBehind = git -C $expanded rev-list --left-right --count "@{upstream}...HEAD" 2>$null
        if ($LASTEXITCODE -eq 0 -and $aheadBehind) {
            $parts = $aheadBehind.Trim() -split "\s+"
            if ($parts.Count -ge 2) {
                $record.Behind = [int]$parts[0]
                $record.Ahead = [int]$parts[1]
            }
        }
    }

    $commitLines = @(git -C $expanded log -n 3 --pretty=format:"%h|%s|%cr" 2>$null)
    if ($LASTEXITCODE -eq 0) {
        $commits = @()
        foreach ($line in $commitLines) {
            if (-not $line) { continue }
            $parts = $line -split "\|", 3
            if ($parts.Count -lt 3) { continue }
            $commits += [PSCustomObject]@{
                Hash = $parts[0]
                Subject = $parts[1]
                RelativeTime = $parts[2]
            }
        }
        $record.LastCommits = $commits
    }

    return [PSCustomObject]$record
}

if ($Help) {
    Show-HelpText
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

$targets = @()
if ($RepoPath -and $RepoPath.Count -gt 0) {
    $targets = @($RepoPath)
} else {
    $loaded = Get-ReposFromAllowlist -PathValue $ReposFile
    if ($null -eq $loaded) {
        if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
        exit 1
    }
    $targets = @($loaded)
}

$targets = @($targets | Where-Object { $_ } | Sort-Object -Unique)
if ($targets.Count -eq 0) {
    Write-Host "No repositories configured. Add entries to repos file or pass -RepoPath." -ForegroundColor Yellow
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

$records = @()
foreach ($path in $targets) {
    $records += Get-ChronicleRecord -InputPath $path
}

$outputText = ""
switch ($Format) {
    "json" {
        $outputText = $records | ConvertTo-Json -Depth 8
    }
    "markdown" {
        $lines = @()
        $lines += "| Repo | Branch | Ahead | Behind | Dirty | Untracked | State |"
        $lines += "|---|---|---:|---:|---:|---:|---|"
        foreach ($r in $records) {
            $lines += "| $($r.Repo) | $($r.Branch) | $($r.Ahead) | $($r.Behind) | $($r.Dirty) | $($r.Untracked) | $($r.State) |"
        }

        if ($Detailed) {
            $lines += ""
            foreach ($r in $records) {
                $lines += "### $($r.Repo)"
                $lines += "- Path: $($r.Path)"
                foreach ($c in @($r.LastCommits)) {
                    $lines += "- $($c.Hash) $($c.Subject) ($($c.RelativeTime))"
                }
                $lines += ""
            }
        }

        $outputText = $lines -join "`r`n"
    }
    default {
        $display = @(
            $records | ForEach-Object {
                [PSCustomObject]@{
                    Repo = $_.Repo
                    Branch = $_.Branch
                    Ahead = $_.Ahead
                    Behind = $_.Behind
                    Dirty = $_.Dirty
                    Untracked = $_.Untracked
                    State = $_.State
                }
            }
        )

        $lines = @()
        $lines += "Chronicle"
        $lines += "---------"
        $lines += (($display | Format-Table Repo, Branch, Ahead, Behind, Dirty, Untracked, State -AutoSize | Out-String).TrimEnd())

        if ($Detailed) {
            $lines += ""
            $lines += "Details"
            $lines += "-------"
            foreach ($r in $records) {
                $lines += "[$($r.Repo)]"
                $lines += "  Path: $($r.Path)"
                foreach ($c in @($r.LastCommits)) {
                    $lines += "  - $($c.Hash) $($c.Subject) ($($c.RelativeTime))"
                }
                if (@($r.LastCommits).Count -eq 0) {
                    $lines += "  - no commit history available"
                }
                $lines += ""
            }
        }

        $outputText = $lines -join "`r`n"
    }
}

if ($Output) {
    $outPath = Expand-ArmoryPath -PathValue $Output
    $parent = Split-Path $outPath -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -Path $outPath -Value $outputText -Encoding UTF8
    Write-Host "Chronicle output written: $outPath" -ForegroundColor Green
} else {
    Write-Output $outputText
}

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
