<#
.SYNOPSIS
  Fails when git remote URLs contain embedded credentials.
#>

$ErrorActionPreference = "Stop"

$credentialPattern = 'https?://[^/@\s]+:[^@\s]+@[^\s]+'
$violations = @()

$remoteLines = git remote -v 2>$null
if (-not $remoteLines) {
    Write-Host "No git remotes found; skipping credentialed remote check." -ForegroundColor Yellow
    exit 0
}

foreach ($line in $remoteLines) {
    if ($line -match $credentialPattern) {
        $violations += $line.Trim()
    }
}

if ($violations.Count -gt 0) {
    Write-Host "Credentialed git remote URL detected. Remove embedded username/token from remote URLs." -ForegroundColor Red
    foreach ($v in $violations | Sort-Object -Unique) {
        $safe = $v -replace '://([^:@\s]+):[^@\s]+@', '://$1:***@'
        Write-Host "  $safe" -ForegroundColor Yellow
    }
    Write-Host "Example fix: git remote set-url origin https://github.com/<owner>/<repo>.git" -ForegroundColor DarkGray
    exit 1
}

Write-Host "Remote URL credential check passed." -ForegroundColor Green
exit 0
