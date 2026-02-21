<#
.SYNOPSIS
  Alexander - release preflight gate for Armory.
#>

param(
    [ValidateSet("catalog", "secrets", "remote", "smoke", "fixtures", "chronicle", "release", "remedy")]
    [string[]]$Skip,
    [switch]$Detailed,
    [string]$Output,
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Continue"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$hooks = Join-Path $repoRoot "bard\lib\bard-hooks.ps1"
if (Test-Path $hooks) { . $hooks }

$soundContext = $null
if (Get-Command Initialize-ArmorySound -ErrorAction SilentlyContinue) {
    $soundContext = Initialize-ArmorySound -Sound:$Sound -NoSound:$NoSound -RepoRoot $repoRoot
    Invoke-ArmoryCue -Context $soundContext -Type start
}

function Show-Usage {
    Write-Host ""
    Write-Host "  Alexander" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Read-only release preflight gate for Armory checks."
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\summons\alexander\alexander.ps1"
    Write-Host "    .\summons\alexander\alexander.ps1 -Detailed"
    Write-Host "    .\summons\alexander\alexander.ps1 -Skip fixtures,chronicle"
    Write-Host "    .\summons\alexander\alexander.ps1 -Output \"$env:USERPROFILE\.armory\reports\alexander.txt\""
    Write-Host ""
}

if ($Help) {
    Show-Usage
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

function Expand-ArmoryPath {
    param([string]$PathValue)

    if (-not $PathValue) { return $PathValue }

    $expanded = [Environment]::ExpandEnvironmentVariables($PathValue)
    if ($expanded.StartsWith("~")) {
        $trimmed = $expanded.Substring(1).TrimStart('/', '\\')
        if ($trimmed) {
            return (Join-Path $HOME $trimmed)
        }
        return $HOME
    }

    return $expanded
}

function Invoke-CommandCapture {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    $output = ""
    $exitCode = 1

    Push-Location $WorkingDirectory
    try {
        $output = (& $Executable @Arguments 2>&1 | Out-String).TrimEnd()
        $exitCode = $LASTEXITCODE
    } catch {
        $output = ($_ | Out-String).TrimEnd()
        $exitCode = 1
    }
    finally {
        Pop-Location
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

$pythonRunner = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $pythonRunner) {
    $pythonRunner = Get-Command python -ErrorAction SilentlyContinue
}

$psRunner = Get-Command powershell -ErrorAction SilentlyContinue
if (-not $psRunner) {
    $psRunner = Get-Command pwsh -ErrorAction SilentlyContinue
}

$sevenZipPath = $null
$sevenZipCmd = Get-Command 7z -ErrorAction SilentlyContinue
if (-not $sevenZipCmd) { $sevenZipCmd = Get-Command 7za -ErrorAction SilentlyContinue }
if ($sevenZipCmd) {
    $sevenZipPath = $sevenZipCmd.Source
} else {
    $candidatePaths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )
    $sevenZipPath = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
}

$checks = @(
    [PSCustomObject]@{
        Name = "catalog"
        Description = "Validate shop catalog schema and paths"
        Requires = "python"
        Command = "scripts/validate_shop_catalog.py"
        BuildArgs = { @("scripts/validate_shop_catalog.py") }
    },
    [PSCustomObject]@{
        Name = "secrets"
        Description = "Scan tracked files for secret patterns"
        Requires = "python"
        Command = "scripts/ci/secret_hygiene.py"
        BuildArgs = { @("scripts/ci/secret_hygiene.py") }
    },
    [PSCustomObject]@{
        Name = "remote"
        Description = "Ensure git remotes do not embed credentials"
        Requires = "powershell"
        Command = "scripts/ci/check_remote_url.ps1"
        BuildArgs = { @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $repoRoot "scripts/ci/check_remote_url.ps1")) }
    },
    [PSCustomObject]@{
        Name = "smoke"
        Description = "Run help/usage smoke checks"
        Requires = "powershell"
        Command = "scripts/ci/help-smoke.ps1"
        BuildArgs = { @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $repoRoot "scripts/ci/help-smoke.ps1")) }
    },
    [PSCustomObject]@{
        Name = "fixtures"
        Description = "Run scan/truesight/cure fixture tests"
        Requires = "powershell"
        Command = "scripts/ci/run-fixture-tests.ps1"
        BuildArgs = {
            $invokeArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $repoRoot "scripts/ci/run-fixture-tests.ps1"))
            if ($sevenZipPath) {
                $invokeArgs += @("-SevenZipPath", $sevenZipPath)
            }
            return $invokeArgs
        }
    },
    [PSCustomObject]@{
        Name = "chronicle"
        Description = "Run chronicle fixture tests"
        Requires = "powershell"
        Command = "scripts/ci/run-chronicle-tests.ps1"
        BuildArgs = { @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $repoRoot "scripts/ci/run-chronicle-tests.ps1")) }
    },
    [PSCustomObject]@{
        Name = "release"
        Description = "Validate changelog/release baseline"
        Requires = "python"
        Command = "scripts/release/validate_release.py --mode ci"
        BuildArgs = { @("scripts/release/validate_release.py", "--mode", "ci") }
    },
    [PSCustomObject]@{
        Name = "remedy"
        Description = "Run remedy environment health check"
        Requires = "powershell"
        Command = "items/remedy/remedy.ps1"
        BuildArgs = { @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $repoRoot "items/remedy/remedy.ps1")) }
    }
)

$skipSet = @{}
if ($Skip) {
    foreach ($entry in $Skip) {
        $skipSet[$entry.ToLower()] = $true
    }
}

$results = New-Object System.Collections.Generic.List[object]

foreach ($check in $checks) {
    if ($skipSet.ContainsKey($check.Name)) {
        $results.Add([PSCustomObject]@{
            Check = $check.Name
            Status = "WARN"
            ExitCode = 0
            Message = "Skipped by request"
            Command = $check.Command
            Output = ""
        }) | Out-Null
        continue
    }

    if ($check.Requires -eq "python" -and -not $pythonRunner) {
        $results.Add([PSCustomObject]@{
            Check = $check.Name
            Status = "FAIL"
            ExitCode = 1
            Message = "python runner not found (expected python3 or python)"
            Command = $check.Command
            Output = ""
        }) | Out-Null
        continue
    }

    if ($check.Requires -eq "powershell" -and -not $psRunner) {
        $results.Add([PSCustomObject]@{
            Check = $check.Name
            Status = "FAIL"
            ExitCode = 1
            Message = "powershell runner not found (expected powershell or pwsh)"
            Command = $check.Command
            Output = ""
        }) | Out-Null
        continue
    }

    $args = & $check.BuildArgs
    $exe = if ($check.Requires -eq "python") { $pythonRunner.Source } else { $psRunner.Source }
    $captured = Invoke-CommandCapture -Executable $exe -Arguments $args -WorkingDirectory $repoRoot

    $status = if ($captured.ExitCode -eq 0) { "PASS" } else { "FAIL" }
    $message = if ($captured.ExitCode -eq 0) { "Check passed" } else { "Check failed (exit $($captured.ExitCode))" }

    if ($check.Name -eq "fixtures" -and -not $sevenZipPath) {
        $status = "FAIL"
        $message = "7-Zip not detected; fixture tests require 7z"
        $captured.ExitCode = 1
        if (-not $captured.Output) {
            $captured = [PSCustomObject]@{
                ExitCode = 1
                Output = "7-Zip executable not found. Install 7-Zip or add 7z to PATH."
            }
        }
    }

    $results.Add([PSCustomObject]@{
        Check = $check.Name
        Status = $status
        ExitCode = $captured.ExitCode
        Message = $message
        Command = $check.Command
        Output = $captured.Output
    }) | Out-Null
}

$failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = @($results | Where-Object { $_.Status -eq "WARN" }).Count
$passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count

$lines = @()
$lines += "Alexander Preflight Gate"
$lines += "-----------------------"
$lines += "Timestamp: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$lines += "Repo: $repoRoot"
$lines += ""
$lines += (($results | Select-Object Check, Status, ExitCode, Message | Format-Table -AutoSize | Out-String).TrimEnd())
$lines += ""
$lines += "Summary: PASS=$passCount WARN=$warnCount FAIL=$failCount"

if ($Detailed) {
    $lines += ""
    $lines += "Detailed Output"
    $lines += "--------------"
    foreach ($result in $results) {
        $lines += ""
        $lines += "[$($result.Check)] $($result.Command)"
        if ($result.Output) {
            $lines += $result.Output
        } else {
            $lines += "(no output)"
        }
    }
}

$finalText = $lines -join "`r`n"

if ($Output) {
    $outPath = Expand-ArmoryPath -PathValue $Output
    $outDir = Split-Path $outPath -Parent
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -Path $outPath -Value $finalText -Encoding UTF8
    Write-Host "Alexander report written: $outPath" -ForegroundColor Green
} else {
    Write-Output $finalText
}

if ($failCount -gt 0) {
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
