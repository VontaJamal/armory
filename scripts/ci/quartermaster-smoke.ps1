<#
.SYNOPSIS
  Smoke test for quartermaster scout/plan/equip/report flow.
#>

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$quartermaster = Join-Path $repoRoot "items\quartermaster\quartermaster.ps1"

if (-not (Test-Path $quartermaster)) {
    Write-Host "Missing script: $quartermaster" -ForegroundColor Red
    exit 1
}

$runner = Get-Command powershell -ErrorAction SilentlyContinue
if (-not $runner) {
    $runner = Get-Command pwsh -ErrorAction SilentlyContinue
}
if (-not $runner) {
    Write-Host "No PowerShell runner found (expected powershell or pwsh)." -ForegroundColor Red
    exit 1
}

function Invoke-Quartermaster {
    param([string[]]$ScriptArgs)

    $invokeArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $quartermaster) + @($ScriptArgs)
    $output = & $runner.Source @invokeArgs 2>&1 | Out-String
    return [PSCustomObject]@{
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

$tempHome = Join-Path ([System.IO.Path]::GetTempPath()) ("armory-quartermaster-" + [Guid]::NewGuid().ToString("N"))
$problemRepo = Join-Path (Split-Path $repoRoot -Parent) ("quartermaster-problem-" + [Guid]::NewGuid().ToString("N"))
$originalUserProfile = $env:USERPROFILE
$originalHome = $env:HOME

try {
    New-Item -ItemType Directory -Path $tempHome -Force | Out-Null
    New-Item -ItemType Directory -Path $problemRepo -Force | Out-Null

    Copy-Item -Path (Join-Path $repoRoot "tests\fixtures\quartermaster\problem-repo\*") -Destination $problemRepo -Recurse -Force

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        & $git.Source -C $problemRepo init | Out-Null
        & $git.Source -C $problemRepo config user.email "fixtures@armory.local" | Out-Null
        & $git.Source -C $problemRepo config user.name "Armory Fixtures" | Out-Null
        & $git.Source -C $problemRepo add . | Out-Null
        & $git.Source -C $problemRepo commit -m "fixture: quartermaster baseline" | Out-Null
    }

    $env:USERPROFILE = $tempHome
    $env:HOME = $tempHome

    Push-Location $problemRepo
    try {
        $scout = Invoke-Quartermaster -ScriptArgs @("scout", "-Task", "release diagnostics and repo status", "-RepoPath", $problemRepo, "-Top", "2")
        Assert-Exit -Name "quartermaster discovery scout" -Expected 0 -Result $scout

        $configPath = Join-Path $tempHome ".armory\config.json"
        if (-not (Test-Path $configPath)) {
            Write-Host "Scenario failed: config file not created by discovery" -ForegroundColor Red
            exit 1
        }

        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        if ([string]$config.repoRoot -ne [string]$repoRoot) {
            Write-Host "Scenario failed: resolved repoRoot mismatch" -ForegroundColor Red
            Write-Host "  expected: $repoRoot" -ForegroundColor Yellow
            Write-Host "  actual:   $($config.repoRoot)" -ForegroundColor Yellow
            exit 1
        }

        $fakeArmory = Join-Path $tempHome "fake-armory"
        New-Item -ItemType Directory -Path (Join-Path $fakeArmory "shop") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fakeArmory "docs\data") -Force | Out-Null
        Copy-Item -Path (Join-Path $repoRoot "awakening.ps1") -Destination (Join-Path $fakeArmory "awakening.ps1") -Force
        Copy-Item -Path (Join-Path $repoRoot "shop\catalog.json") -Destination (Join-Path $fakeArmory "shop\catalog.json") -Force
        Copy-Item -Path (Join-Path $repoRoot "docs\data\armory-manifest.v1.json") -Destination (Join-Path $fakeArmory "docs\data\armory-manifest.v1.json") -Force

        $pullFail = Invoke-Quartermaster -ScriptArgs @("scout", "-Task", "release checks", "-RepoPath", $problemRepo, "-ArmoryRoot", $fakeArmory)
        Assert-Exit -Name "quartermaster pull failure" -Expected 1 -Result $pullFail

        $plan = Invoke-Quartermaster -ScriptArgs @("plan", "-Task", "release diagnostics", "-RepoPath", $problemRepo, "-Top", "2")
        Assert-Exit -Name "quartermaster plan" -Expected 0 -Result $plan

        $lastPlanPath = Join-Path $tempHome ".armory\quartermaster\last-plan.json"
        if (-not (Test-Path $lastPlanPath)) {
            Write-Host "Scenario failed: last-plan.json not created" -ForegroundColor Red
            exit 1
        }

        $planObj = Get-Content -Path $lastPlanPath -Raw | ConvertFrom-Json
        if (@($planObj.loadout).Count -lt 1) {
            Write-Host "Scenario failed: plan loadout is empty" -ForegroundColor Red
            exit 1
        }

        $equipBlocked = Invoke-Quartermaster -ScriptArgs @("equip", "-FromLastPlan")
        Assert-Exit -Name "quartermaster equip approval gate" -Expected 1 -Result $equipBlocked

        $equip = Invoke-Quartermaster -ScriptArgs @("equip", "-FromLastPlan", "-Approve")
        Assert-Exit -Name "quartermaster equip approved" -Expected 0 -Result $equip

        $planObj = Get-Content -Path $lastPlanPath -Raw | ConvertFrom-Json
        if (@($planObj.equip.installed).Count -lt 1) {
            Write-Host "Scenario failed: no installed IDs recorded" -ForegroundColor Red
            exit 1
        }

        $installDir = [string]$planObj.equip.installDir
        if (-not (Test-Path $installDir)) {
            Write-Host "Scenario failed: install directory missing after equip" -ForegroundColor Red
            exit 1
        }

        $firstInstalled = [string](@($planObj.equip.installed)[0])
        $wrapperPath = Join-Path $installDir ("{0}.cmd" -f $firstInstalled)
        if (-not (Test-Path $wrapperPath)) {
            Write-Host "Scenario failed: expected wrapper missing: $wrapperPath" -ForegroundColor Red
            exit 1
        }

        $planObj.mode = "civ"
        $planObj | ConvertTo-Json -Depth 20 | Set-Content -Path $lastPlanPath -Encoding UTF8
        $civReport = Invoke-Quartermaster -ScriptArgs @("report", "-FromLastPlan")
        Assert-Exit -Name "quartermaster civ report" -Expected 0 -Result $civReport
        if ($civReport.Output -notmatch "Quartermaster status report") {
            Write-Host "Scenario failed: civ report wording mismatch" -ForegroundColor Red
            exit 1
        }

        $planObj = Get-Content -Path $lastPlanPath -Raw | ConvertFrom-Json
        $planObj.mode = "saga"
        $planObj | ConvertTo-Json -Depth 20 | Set-Content -Path $lastPlanPath -Encoding UTF8
        $sagaReport = Invoke-Quartermaster -ScriptArgs @("report", "-FromLastPlan")
        Assert-Exit -Name "quartermaster saga report" -Expected 0 -Result $sagaReport
        if ($sagaReport.Output -notmatch "Quartermaster field report") {
            Write-Host "Scenario failed: saga report wording mismatch" -ForegroundColor Red
            exit 1
        }

        Remove-Item -Path $lastPlanPath -Force
        $missingPlan = Invoke-Quartermaster -ScriptArgs @("report", "-FromLastPlan")
        Assert-Exit -Name "quartermaster missing plan" -Expected 1 -Result $missingPlan

        Write-Host "All quartermaster smoke scenarios passed." -ForegroundColor Green
        exit 0
    }
    finally {
        Pop-Location
    }
}
finally {
    $env:USERPROFILE = $originalUserProfile
    $env:HOME = $originalHome

    if (Test-Path $tempHome) {
        Remove-Item -Path $tempHome -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $problemRepo) {
        Remove-Item -Path $problemRepo -Recurse -Force -ErrorAction SilentlyContinue
    }
}
