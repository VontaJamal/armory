<#
.SYNOPSIS
  Scan - fast manual security scan for local repositories.
#>

param(
    [string]$RepoPath = "D:\Code Repos",
    [switch]$Verbose,
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

$config = @{
    fileExtensions = '\.(md|ts|js|json|yml|yaml|sh|ps1|html|css|py|toml|txt|env|cfg|ini)$'
    ignorePathPattern = '[\\/](\.git|node_modules|\.venv|dist|__pycache__)[\\/]'
    patterns = @(
        @{ level = "CRITICAL"; name = "Telegram token"; regex = '\d{8,12}:[A-Za-z0-9_-]{30,}' },
        @{ level = "CRITICAL"; name = "Provider API key"; regex = "(sk_[a-zA-Z0-9]{20,}|sk-ant-[a-zA-Z0-9]{20,}|gho_[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|AIza[a-zA-Z0-9]{30,})" },
        @{ level = "CRITICAL"; name = "Private key"; regex = "PRIVATE KEY" },
        @{ level = "WARNING"; name = "Hardcoded password"; regex = '(?i)(password|passwd|pwd)\s*[:=]\s*[''"][^''"]{6,}[''"]' }
    )
}

function Show-Help {
    Write-Host ""
    Write-Host "  Scan" -ForegroundColor Yellow
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\scan.ps1"
    Write-Host "    .\\scan.ps1 -RepoPath \"D:\\Code Repos\""
    Write-Host "    .\\scan.ps1 -Verbose"
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

$repos = @(Get-ChildItem -Path $RepoPath -Directory -ErrorAction SilentlyContinue)
if ($repos.Count -eq 0) {
    $repos = @((Get-Item $RepoPath))
}

$findings = @()

Write-Host ""
Write-Host "  Scan" -ForegroundColor Yellow
Write-Host "  -----------------------------" -ForegroundColor DarkGray
Write-Host "  Root: $RepoPath" -ForegroundColor DarkGray
Write-Host ""

foreach ($repo in $repos) {
    if ($Verbose) {
        Write-Host "  scanning repo: $($repo.FullName)" -ForegroundColor DarkGray
    }

    $files = Get-ChildItem $repo.FullName -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch $config.ignorePathPattern -and $_.Extension -match $config.fileExtensions
    }

    foreach ($f in $files) {
        $content = $null
        try {
            $content = [System.IO.File]::ReadAllText($f.FullName)
        } catch {
            continue
        }

        if (-not $content) { continue }

        foreach ($p in $config.patterns) {
            if ($content -match $p.regex) {
                $findings += Add-Finding -Level $p.level -Repo $repo.Name -File $f.FullName -Message $p.name
            }
        }
    }

    $envFiles = Get-ChildItem $repo.FullName -Recurse -Filter ".env" -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]'
    }

    foreach ($ef in $envFiles) {
        $findings += Add-Finding -Level "WARNING" -Repo $repo.Name -File $ef.FullName -Message ".env file exists"
    }
}

if ($findings.Count -eq 0) {
    Write-Host "  no findings" -ForegroundColor Green
    Write-Host ""
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

foreach ($f in $findings) {
    $color = if ($f.Level -eq "CRITICAL") { "Red" } else { "Yellow" }
    Write-Host ("  [{0}] {1} - {2}" -f $f.Level, $f.File, $f.Message) -ForegroundColor $color
}

Write-Host ""
Write-Host "  findings: $($findings.Count)" -ForegroundColor Red
Write-Host ""

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
exit 1
