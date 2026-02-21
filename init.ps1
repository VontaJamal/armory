<#
.SYNOPSIS
  Legacy alias wrapper for awakening.
#>

$target = Join-Path $PSScriptRoot "awakening.ps1"

Write-Host "  init.ps1 is a compatibility alias. Use awakening.ps1 for new setups." -ForegroundColor Yellow
if (-not (Test-Path $target)) {
    Write-Host "  Missing target script: $target" -ForegroundColor Red
    exit 1
}

powershell -ExecutionPolicy Bypass -File $target @args
exit $LASTEXITCODE
