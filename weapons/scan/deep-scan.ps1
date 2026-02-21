<#
.SYNOPSIS
  Legacy alias wrapper for truesight.
#>

Write-Host "  deep-scan.ps1 is a compatibility alias. Use truesight.ps1 for new runs." -ForegroundColor Yellow
$target = Join-Path $PSScriptRoot "..\truesight\truesight.ps1"
if (-not (Test-Path $target)) {
    Write-Host "  Missing target script: $target" -ForegroundColor Red
    exit 1
}

powershell -ExecutionPolicy Bypass -File $target @args
exit $LASTEXITCODE
