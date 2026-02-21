<#
.SYNOPSIS
  Fixture-based exit-code checks for scan, truesight, and cure.
#>

param(
    [string]$SevenZipPath
)

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

if (-not $SevenZipPath) {
    $candidates = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )
    $SevenZipPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $SevenZipPath -or -not (Test-Path $SevenZipPath)) {
    Write-Host "7-Zip executable not found. Provide -SevenZipPath." -ForegroundColor Red
    exit 1
}

function Invoke-PsFile {
    param(
        [string]$ScriptPath,
        [string[]]$ScriptArgs
    )

    $invokeArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath) + @($ScriptArgs)
    $output = & $runner.Source @invokeArgs 2>&1 | Out-String
    $exitCode = $LASTEXITCODE

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output = $output.Trim()
    }
}

function Assert-Scenario {
    param(
        [string]$Name,
        [int]$ExpectedExitCode,
        [string]$ScriptPath,
        [string[]]$ScriptArgs
    )

    $result = Invoke-PsFile -ScriptPath $ScriptPath -ScriptArgs $ScriptArgs
    if ($result.ExitCode -ne $ExpectedExitCode) {
        Write-Host "Scenario failed: $Name" -ForegroundColor Red
        Write-Host "  expected exit: $ExpectedExitCode" -ForegroundColor Yellow
        Write-Host "  actual exit:   $($result.ExitCode)" -ForegroundColor Yellow
        if ($result.Output) {
            Write-Host "  output:" -ForegroundColor DarkGray
            Write-Host $result.Output -ForegroundColor DarkGray
        }
        exit 1
    }

    Write-Host "PASS $Name (exit $ExpectedExitCode)" -ForegroundColor Green
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("armory-fixtures-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $scanScript = Join-Path $repoRoot "weapons\scan\scan.ps1"
    $truesightScript = Join-Path $repoRoot "weapons\truesight\truesight.ps1"
    $cureScript = Join-Path $repoRoot "spells\cure\cure.ps1"

    $cleanRepo = Join-Path $tempRoot "clean-repo"
    New-Item -ItemType Directory -Path $cleanRepo -Force | Out-Null
    Copy-Item -Path (Join-Path $repoRoot "tests\fixtures\security\clean-repo\*") -Destination $cleanRepo -Recurse -Force

    $leakRepo = Join-Path $tempRoot "leak-repo"
    New-Item -ItemType Directory -Path $leakRepo -Force | Out-Null
    Copy-Item -Path (Join-Path $repoRoot "tests\fixtures\security\leak-repo\*") -Destination $leakRepo -Recurse -Force

    $trackedEnvRepo = Join-Path $tempRoot "tracked-env-repo"
    New-Item -ItemType Directory -Path $trackedEnvRepo -Force | Out-Null
    Copy-Item -Path (Join-Path $repoRoot "tests\fixtures\security\tracked-env\*") -Destination $trackedEnvRepo -Recurse -Force

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        & $git.Source -C $trackedEnvRepo init | Out-Null
        & $git.Source -C $trackedEnvRepo config user.email "fixtures@armory.local" | Out-Null
        & $git.Source -C $trackedEnvRepo config user.name "Armory Fixtures" | Out-Null
        & $git.Source -C $trackedEnvRepo add .env | Out-Null
        & $git.Source -C $trackedEnvRepo commit -m "fixture: tracked env" | Out-Null
    }

    Assert-Scenario -Name "scan clean" -ExpectedExitCode 0 -ScriptPath $scanScript -ScriptArgs @("-RepoPath", $cleanRepo)
    Assert-Scenario -Name "scan leak" -ExpectedExitCode 1 -ScriptPath $scanScript -ScriptArgs @("-RepoPath", $leakRepo)

    Assert-Scenario -Name "truesight clean" -ExpectedExitCode 0 -ScriptPath $truesightScript -ScriptArgs @("-RepoPath", $cleanRepo, "-Quiet")
    Assert-Scenario -Name "truesight leak" -ExpectedExitCode 1 -ScriptPath $truesightScript -ScriptArgs @("-RepoPath", $leakRepo, "-Quiet")

    if ($git) {
        Assert-Scenario -Name "truesight tracked .env" -ExpectedExitCode 1 -ScriptPath $truesightScript -ScriptArgs @("-RepoPath", $trackedEnvRepo, "-Quiet")
    } else {
        Write-Host "SKIP truesight tracked .env (git not found)" -ForegroundColor Yellow
    }

    $passwordFile = Join-Path $repoRoot "tests\fixtures\cure\shared\password.txt"
    $password = (Get-Content -Path $passwordFile -Raw).Trim()

    $healthyDir = Join-Path $tempRoot "cure-healthy"
    $staleDir = Join-Path $tempRoot "cure-stale"
    $corruptDir = Join-Path $tempRoot "cure-corrupt"
    New-Item -ItemType Directory -Path $healthyDir, $staleDir, $corruptDir -Force | Out-Null

    $healthySource = Join-Path $repoRoot "tests\fixtures\cure\healthy\source"
    $healthyArchive = Join-Path $healthyDir "healthy-backup.7z"
    $healthyFiles = Get-ChildItem -Path $healthySource -File
    $healthyArgs = @("a", "-t7z", $healthyArchive) + @($healthyFiles.FullName) + @("-p$password", "-mhe=on")
    & $SevenZipPath @healthyArgs | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create healthy fixture archive"
    }

    $staleSource = Join-Path $repoRoot "tests\fixtures\cure\stale\source"
    $staleArchive = Join-Path $staleDir "stale-backup.7z"
    $staleFiles = Get-ChildItem -Path $staleSource -File
    $staleArgs = @("a", "-t7z", $staleArchive) + @($staleFiles.FullName) + @("-p$password", "-mhe=on")
    & $SevenZipPath @staleArgs | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create stale fixture archive"
    }
    (Get-Item $staleArchive).LastWriteTime = (Get-Date).AddHours(-72)

    $corruptArchive = Join-Path $corruptDir "corrupt-backup.7z"
    New-Item -ItemType File -Path $corruptArchive -Force | Out-Null

    Assert-Scenario -Name "cure healthy" -ExpectedExitCode 0 -ScriptPath $cureScript -ScriptArgs @(
        "-Dir", $healthyDir,
        "-MaxAgeHours", "24",
        "-SevenZipPath", $SevenZipPath,
        "-PasswordFile", $passwordFile
    )

    Assert-Scenario -Name "cure stale" -ExpectedExitCode 1 -ScriptPath $cureScript -ScriptArgs @(
        "-Dir", $staleDir,
        "-MaxAgeHours", "24",
        "-SevenZipPath", $SevenZipPath,
        "-PasswordFile", $passwordFile
    )

    Assert-Scenario -Name "cure corrupt" -ExpectedExitCode 1 -ScriptPath $cureScript -ScriptArgs @(
        "-Dir", $corruptDir,
        "-MaxAgeHours", "24",
        "-SevenZipPath", $SevenZipPath,
        "-PasswordFile", $passwordFile
    )

    Write-Host "All fixture scenarios passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
