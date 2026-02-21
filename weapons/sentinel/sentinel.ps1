<#
.SYNOPSIS
  Legacy alias wrapper for aegis.
#>

Write-Host "  sentinel.ps1 is a compatibility alias. Use aegis.ps1 for new setups." -ForegroundColor Yellow
$target = Join-Path $PSScriptRoot "..\aegis\aegis.ps1"
if (-not (Test-Path $target)) {
    Write-Host "  Missing target script: $target" -ForegroundColor Red
    exit 1
}

powershell -ExecutionPolicy Bypass -File $target @args
exit $LASTEXITCODE
