<#
.SYNOPSIS
  Legacy alias wrapper for remedy.
#>

$target = Join-Path $PSScriptRoot "items\remedy\remedy.ps1"

Write-Host "  doctor.ps1 is deprecated and will be removed after two releases. Use items/remedy/remedy.ps1 (or dispatcher command 'remedy')." -ForegroundColor Yellow
Write-Host "  Remedy now includes an optional Seven Shadow path check (`-Check shadow`)." -ForegroundColor DarkGray
if (-not (Test-Path $target)) {
    Write-Host "  Missing target script: $target" -ForegroundColor Red
    exit 1
}

$runner = Get-Command powershell -ErrorAction SilentlyContinue
if (-not $runner) {
    $runner = Get-Command pwsh -ErrorAction SilentlyContinue
}
if (-not $runner) {
    Write-Host "  Missing PowerShell runtime (expected powershell or pwsh)." -ForegroundColor Red
    exit 1
}

& $runner.Source -ExecutionPolicy Bypass -File $target @args
exit $LASTEXITCODE
