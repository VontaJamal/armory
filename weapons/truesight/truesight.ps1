<#
.SYNOPSIS
  Truesight - deep security scan for repos and git state.
#>

param(
    [string]$RepoPath = "D:\Code Repos",
    [switch]$Quiet,
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Continue"

# Some runners invoke scripts through wrappers that can leave named args in $args.
# Backfill RepoPath from raw args when it was not bound through the param block.
if (-not $PSBoundParameters.ContainsKey("RepoPath") -and $args.Count -gt 0) {
    for ($i = 0; $i -lt $args.Count; $i++) {
        $token = [string]$args[$i]
        if ($token -ieq "-RepoPath" -and ($i + 1) -lt $args.Count) {
            $RepoPath = [string]$args[$i + 1]
            break
        }
        if ($token -like "-RepoPath:*") {
            $RepoPath = $token.Substring(10)
            break
        }
    }
}

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

function Show-Help {
    Write-Host ""
    Write-Host "  Truesight" -ForegroundColor Yellow
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\truesight.ps1"
    Write-Host "    .\\truesight.ps1 -RepoPath \"D:\\Code Repos\""
    Write-Host "    .\\truesight.ps1 -Quiet"
    Write-Host ""
}

function Add-Finding {
    param([string]$Level, [string]$Repo, [string]$File, [string]$Message)
    [PSCustomObject]@{
        Level = $Level
        Repo = $Repo
        File = $File
        Message = $Message
    }
}

if ($Help) {
    Show-Help
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if (-not (Test-Path $RepoPath)) {
    Write-Host "  RepoPath not found: $RepoPath" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

$findings = @()
$repos = @(Get-ChildItem -Path $RepoPath -Directory -ErrorAction SilentlyContinue)
if ($repos.Count -eq 0) {
    $repos = @((Get-Item $RepoPath))
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host "  Truesight" -ForegroundColor Yellow
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host "  Root: $RepoPath" -ForegroundColor DarkGray
    Write-Host ""
}

foreach ($repo in $repos) {
    $files = Get-ChildItem $repo.FullName -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch '[\\/](\.git|node_modules|\.venv|dist|__pycache__)[\\/]' -and
        $_.Extension -match '\.(md|ts|js|json|yml|yaml|sh|ps1|html|css|py|toml|txt|env|cfg|ini)$'
    }

    foreach ($f in $files) {
        $content = $null
        try {
            $content = [System.IO.File]::ReadAllText($f.FullName)
        } catch {
            continue
        }

        if (-not $content) { continue }

        if ($content -match '\d{8,12}:[A-Za-z0-9_-]{30,}') {
            $findings += Add-Finding -Level "CRITICAL" -Repo $repo.Name -File $f.FullName -Message "Telegram token pattern"
        }
        if ($content -match "(sk_[a-zA-Z0-9]{20,}|sk-ant-[a-zA-Z0-9]{20,}|gho_[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|AIza[a-zA-Z0-9]{30,})") {
            $findings += Add-Finding -Level "CRITICAL" -Repo $repo.Name -File $f.FullName -Message "API key pattern"
        }
        if ($content -match "PRIVATE KEY") {
            $findings += Add-Finding -Level "CRITICAL" -Repo $repo.Name -File $f.FullName -Message "Private key text"
        }
        if ($content -match '(?i)(password|passwd|pwd)\s*[:=]\s*[''"][^''"]{4,}[''"]') {
            $findings += Add-Finding -Level "WARNING" -Repo $repo.Name -File $f.FullName -Message "Hardcoded password pattern"
        }
    }

    if (Test-Path (Join-Path $repo.FullName ".git")) {
        $trackedEnv = git -C $repo.FullName ls-files 2>$null | Where-Object { $_ -match '(^|/|\\)\.env($|\.)' }
        foreach ($te in $trackedEnv) {
            $findings += Add-Finding -Level "CRITICAL" -Repo $repo.Name -File $te -Message ".env tracked by git"
        }

        $recentDiff = git -C $repo.FullName log -n 10 --name-only --pretty=format:"" 2>$null
        foreach ($line in $recentDiff) {
            if ($line -and $line -match '(^|/|\\)\.env($|\.)') {
                $findings += Add-Finding -Level "WARNING" -Repo $repo.Name -File $line -Message ".env appeared in recent commit list"
            }
        }
    }
}

if ($findings.Count -eq 0) {
    if (-not $Quiet) {
        Write-Host "  no findings" -ForegroundColor Green
        Write-Host ""
    }
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

foreach ($f in $findings) {
    if ($Quiet) {
        continue
    }
    $color = if ($f.Level -eq "CRITICAL") { "Red" } else { "Yellow" }
    Write-Host ("  [{0}] {1}/{2} - {3}" -f $f.Level, $f.Repo, $f.File, $f.Message) -ForegroundColor $color
}

if ($Quiet) {
    Write-Output "findings=$($findings.Count)"
} else {
    Write-Host ""
    Write-Host "  findings: $($findings.Count)" -ForegroundColor Red
    Write-Host ""
}

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
exit 1
