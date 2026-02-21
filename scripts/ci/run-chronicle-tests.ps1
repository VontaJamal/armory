<#
.SYNOPSIS
  Fixture scenarios for Chronicle cross-repo intel.
#>

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runner = Get-Command powershell -ErrorAction SilentlyContinue
if (-not $runner) {
    $runner = Get-Command pwsh -ErrorAction SilentlyContinue
}
if (-not $runner) {
    Write-Host "No PowerShell runner found (expected powershell or pwsh)." -ForegroundColor Red
    exit 1
}

$chronicleScript = Join-Path $repoRoot "spells\chronicle\chronicle.ps1"
if (-not (Test-Path $chronicleScript)) {
    Write-Host "Missing script: $chronicleScript" -ForegroundColor Red
    exit 1
}

function Invoke-Chronicle {
    param([string[]]$ScriptArgs)

    $invokeArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $chronicleScript) + @($ScriptArgs)
    $output = & $runner.Source @invokeArgs 2>&1 | Out-String
    [PSCustomObject]@{
        ExitCode = $LASTEXITCODE
        Output = $output.Trim()
    }
}

function Assert-Exit {
    param(
        [string]$Name,
        [int]$Expected,
        [object]$Result
    )

    if ($Result.ExitCode -ne $Expected) {
        Write-Host "Scenario failed: $Name" -ForegroundColor Red
        Write-Host "  expected: $Expected" -ForegroundColor Yellow
        Write-Host "  actual:   $($Result.ExitCode)" -ForegroundColor Yellow
        if ($Result.Output) {
            Write-Host "  output:" -ForegroundColor DarkGray
            Write-Host $Result.Output -ForegroundColor DarkGray
        }
        exit 1
    }

    Write-Host "PASS $Name (exit $Expected)" -ForegroundColor Green
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("armory-chronicle-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $cleanRepo = Join-Path $tempRoot "clean-repo"
    $dirtyRepo = Join-Path $tempRoot "dirty-repo"
    $nonGit = Join-Path $tempRoot "non-git"
    $missingRepo = Join-Path $tempRoot "missing-repo"

    New-Item -ItemType Directory -Path $cleanRepo, $dirtyRepo, $nonGit -Force | Out-Null

    Copy-Item -Path (Join-Path $repoRoot "tests\fixtures\chronicle\clean-repo\*") -Destination $cleanRepo -Recurse -Force
    Copy-Item -Path (Join-Path $repoRoot "tests\fixtures\chronicle\dirty-repo\*") -Destination $dirtyRepo -Recurse -Force
    Copy-Item -Path (Join-Path $repoRoot "tests\fixtures\chronicle\non-git\*") -Destination $nonGit -Recurse -Force

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Host "git is required for chronicle fixture tests." -ForegroundColor Red
        exit 1
    }

    foreach ($repo in @($cleanRepo, $dirtyRepo)) {
        & $git.Source -C $repo init | Out-Null
        & $git.Source -C $repo config user.email "fixtures@armory.local" | Out-Null
        & $git.Source -C $repo config user.name "Armory Fixtures" | Out-Null
        & $git.Source -C $repo add . | Out-Null
        & $git.Source -C $repo commit -m "fixture: baseline" | Out-Null
    }

    Add-Content -Path (Join-Path $dirtyRepo "dirty.txt") -Value "changed"
    Set-Content -Path (Join-Path $dirtyRepo "new-untracked.txt") -Value "new"

    $reposFile = Join-Path $tempRoot "repos.json"
    $payload = [ordered]@{
        repos = @($cleanRepo, $dirtyRepo, $nonGit, $missingRepo)
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -Path $reposFile -Encoding UTF8

    $helpResult = Invoke-Chronicle -ScriptArgs @("-Help")
    Assert-Exit -Name "chronicle help" -Expected 0 -Result $helpResult

    $tableResult = Invoke-Chronicle -ScriptArgs @("-ReposFile", $reposFile)
    Assert-Exit -Name "chronicle table" -Expected 0 -Result $tableResult
    if ($tableResult.Output -notmatch "clean-repo") {
        Write-Host "Scenario failed: chronicle table output missing clean-repo" -ForegroundColor Red
        exit 1
    }

    $jsonResult = Invoke-Chronicle -ScriptArgs @("-ReposFile", $reposFile, "-Format", "json")
    Assert-Exit -Name "chronicle json" -Expected 0 -Result $jsonResult

    $parsed = $null
    try {
        $parsed = $jsonResult.Output | ConvertFrom-Json
    } catch {
        Write-Host "Scenario failed: chronicle json output invalid" -ForegroundColor Red
        Write-Host $jsonResult.Output -ForegroundColor DarkGray
        exit 1
    }

    if (@($parsed).Count -lt 4) {
        Write-Host "Scenario failed: chronicle json expected at least 4 records" -ForegroundColor Red
        exit 1
    }

    $states = @($parsed | ForEach-Object { $_.State })
    if ($states -notcontains "not-git" -or $states -notcontains "missing") {
        Write-Host "Scenario failed: chronicle states missing not-git or missing" -ForegroundColor Red
        exit 1
    }

    $missingAllowlist = Join-Path $tempRoot "fresh-repos.json"
    $missingResult = Invoke-Chronicle -ScriptArgs @("-ReposFile", $missingAllowlist)
    Assert-Exit -Name "chronicle missing allowlist" -Expected 0 -Result $missingResult
    if (-not (Test-Path $missingAllowlist)) {
        Write-Host "Scenario failed: missing allowlist file was not created" -ForegroundColor Red
        exit 1
    }

    Write-Host "All chronicle fixture scenarios passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
