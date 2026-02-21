<#
.SYNOPSIS
  CI smoke test: run help/usage entrypoints across public scripts.
#>

$ErrorActionPreference = "Continue"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runner = Get-Command powershell -ErrorAction SilentlyContinue
if (-not $runner) {
    $runner = Get-Command pwsh -ErrorAction SilentlyContinue
}

if (-not $runner) {
    Write-Host "No PowerShell runner found (expected powershell or pwsh)." -ForegroundColor Red
    exit 1
}

$targets = @(
    @{ Name = "awakening help"; Path = "awakening.ps1"; Args = @("-Help") },
    @{ Name = "civs help"; Path = "civs.ps1"; Args = @("-Help") },
    @{ Name = "remedy help"; Path = "items/remedy/remedy.ps1"; Args = @("-Help") },
    @{ Name = "doctor help"; Path = "doctor.ps1"; Args = @("-Help") },
    @{ Name = "init alias help"; Path = "init.ps1"; Args = @("-Help") },
    @{ Name = "rename command help"; Path = "rename-command-word.ps1"; Args = @("-Help") },
    @{ Name = "materia-forge help"; Path = "materia-forge.ps1"; Args = @("-Help") },
    @{ Name = "shop list help"; Path = "shop/list-shop.ps1"; Args = @("-Help") },
    @{ Name = "bard help"; Path = "bard/bard.ps1"; Args = @("-Help") },

    @{ Name = "bahamut help"; Path = "summons/bahamut/bahamut.ps1"; Args = @("-Help") },
    @{ Name = "ifrit help"; Path = "summons/ifrit/ifrit.ps1"; Args = @("-Help") },
    @{ Name = "odin help"; Path = "summons/odin/odin.ps1"; Args = @("-Help") },
    @{ Name = "ramuh help"; Path = "summons/ramuh/ramuh.ps1"; Args = @("-Help") },
    @{ Name = "shiva help"; Path = "summons/shiva/shiva.ps1"; Args = @("-Help") },
    @{ Name = "alexander help"; Path = "summons/alexander/alexander.ps1"; Args = @("-Help") },

    @{ Name = "masamune usage (no arg)"; Path = "weapons/masamune/masamune.ps1"; Args = @() },
    @{ Name = "phoenix-down help"; Path = "weapons/phoenix-down/phoenix-down.ps1"; Args = @("-Help") },
    @{ Name = "save-point help"; Path = "weapons/phoenix-down/save-point.ps1"; Args = @("-Help") },
    @{ Name = "setup-rebirth alias help"; Path = "weapons/phoenix-down/setup-rebirth.ps1"; Args = @("-Help") },
    @{ Name = "aegis help"; Path = "weapons/aegis/aegis.ps1"; Args = @("-Help") },
    @{ Name = "sentinel alias help"; Path = "weapons/sentinel/sentinel.ps1"; Args = @("-Help") },
    @{ Name = "scan help"; Path = "weapons/scan/scan.ps1"; Args = @("-Help") },
    @{ Name = "truesight help"; Path = "weapons/truesight/truesight.ps1"; Args = @("-Help") },
    @{ Name = "deep-scan alias help"; Path = "weapons/scan/deep-scan.ps1"; Args = @("-Help") },

    @{ Name = "libra help"; Path = "spells/libra/libra.ps1"; Args = @("-Help") },
    @{ Name = "chronicle help"; Path = "spells/chronicle/chronicle.ps1"; Args = @("-Help") },
    @{ Name = "cure help"; Path = "spells/cure/cure.ps1"; Args = @("-Help") },
    @{ Name = "protect help"; Path = "spells/protect/protect.ps1"; Args = @("-Help") },
    @{ Name = "regen help"; Path = "spells/regen/regen.ps1"; Args = @("-Help") }
)

$results = New-Object System.Collections.Generic.List[object]
$failedOutput = New-Object System.Collections.Generic.List[object]

foreach ($target in $targets) {
    $scriptPath = Join-Path $repoRoot $target.Path
    if (-not (Test-Path $scriptPath)) {
        $results.Add([PSCustomObject]@{
            Target = $target.Name
            Script = $target.Path
            ExitCode = -1
            Result = "FAIL"
            Detail = "Missing script"
        })
        continue
    }

    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath) + @($target.Args)
    $output = & $runner.Source @args 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $passed = ($exitCode -eq 0)

    $results.Add([PSCustomObject]@{
        Target = $target.Name
        Script = $target.Path
        ExitCode = $exitCode
        Result = if ($passed) { "PASS" } else { "FAIL" }
        Detail = if ($passed) { "ok" } else { "non-zero exit" }
    })

    if (-not $passed) {
        $failedOutput.Add([PSCustomObject]@{
            Target = $target.Name
            Script = $target.Path
            Output = $output.Trim()
        })
    }
}

Write-Host ""
Write-Host "Armory help smoke results" -ForegroundColor Cyan
Write-Host "-------------------------" -ForegroundColor DarkGray
$results | Format-Table Target, Script, ExitCode, Result, Detail -AutoSize
Write-Host ""

$failCount = ($results | Where-Object { $_.Result -eq "FAIL" }).Count
if ($failCount -gt 0) {
    Write-Host "$failCount smoke check(s) failed." -ForegroundColor Red
    foreach ($f in $failedOutput) {
        Write-Host ""
        Write-Host "[$($f.Target)] $($f.Script)" -ForegroundColor Yellow
        if ($f.Output) {
            $preview = ($f.Output -split "`r?`n" | Select-Object -First 12) -join "`n"
            Write-Host $preview -ForegroundColor DarkGray
        }
    }
    exit 1
}

Write-Host "All smoke checks passed." -ForegroundColor Green
exit 0
