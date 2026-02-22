<# ============================================================
   221B  --  Sherlock Holmes for your codebase
   ============================================================
   Point it at a project and it deduces what is wrong.
   Part of The Armory (github.com/VontaJamal/armory)
   ============================================================ #>

param(
    [string]$path = ".",
    [string]$service = "",
    [string]$ssh = "",
    [string]$focus = "",
    [string]$report = "",
    [switch]$help,
    [switch]$civ
)

$ErrorActionPreference = "SilentlyContinue"
$deductions = @()

function Add-Deduction($category, $severity, $title, $evidence, $conclusion) {
    $script:deductions += @{
        Category   = $category
        Severity   = $severity
        Title      = $title
        Evidence   = $evidence
        Conclusion = $conclusion
    }
}

if ($help) {
    Write-Host ""
    Write-Host "  221B - Sherlock Holmes for your codebase" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor White
    Write-Host "    221b                        Analyze current directory"
    Write-Host "    221b --path <dir>           Analyze specific project"
    Write-Host "    221b --service <name>       Analyze a Windows service"
    Write-Host "    221b --focus <category>     config|health|deps|git"
    Write-Host "    221b --report <file>        Save deductions to file"
    Write-Host ""
    exit 0
}

$targetPath = Resolve-Path $path -ErrorAction SilentlyContinue
if (-not $targetPath) {
    Write-Host "Path not found: $path" -ForegroundColor Red
    exit 1
}

$projectName = Split-Path $targetPath -Leaf
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

Write-Host ""
Write-Host "  221B - Analyzing: $projectName" -ForegroundColor Cyan
Write-Host "  Path: $targetPath" -ForegroundColor DarkGray
Write-Host "  Time: $timestamp" -ForegroundColor DarkGray
Write-Host ""

# ═══════════════════════════════════════════
# CONFIG DEDUCTIONS
# ═══════════════════════════════════════════
if (-not $focus -or $focus -eq "config") {

    # Check for .env files with potential secrets
    $envFiles = Get-ChildItem $targetPath -Recurse -Filter ".env*" -File | Where-Object { $_.FullName -notmatch 'node_modules|\.git|dist' }
    foreach ($ef in $envFiles) {
        $content = Get-Content $ef.FullName -ErrorAction SilentlyContinue
        foreach ($line in $content) {
            if ($line -match '(?i)(password|secret|token|api_key|apikey)\s*=\s*[^$\{].{8,}' -and $line -notmatch '#') {
                Add-Deduction "Config" "Critical" "Possible plaintext secret" `
                    "$($ef.Name): $($line.Trim().Substring(0, [Math]::Min(60, $line.Trim().Length)))..." `
                    "Secrets should be in a vault or encrypted store, not plaintext .env files"
            }
        }
    }

    # Check for contradicting .env files
    $envVars = @{}
    foreach ($ef in $envFiles) {
        $content = Get-Content $ef.FullName -ErrorAction SilentlyContinue
        foreach ($line in $content) {
            if ($line -match '^([A-Z_]+)\s*=\s*(.+)$') {
                $key = $matches[1]
                $val = $matches[2].Trim()
                if ($envVars.ContainsKey($key) -and $envVars[$key].Value -ne $val) {
                    Add-Deduction "Config" "WorthFixing" "Duplicate env var with different values" `
                        "$key = '$($envVars[$key].Value)' in $($envVars[$key].File) vs '$val' in $($ef.Name)" `
                        "Which value wins depends on load order. Make it explicit."
                }
                $envVars[$key] = @{ Value = $val; File = $ef.Name }
            }
        }
    }

    # Check for config files referencing paths that don't exist
    $configFiles = Get-ChildItem $targetPath -Recurse -Include "*.json","*.yaml","*.yml","*.toml" -File |
        Where-Object { $_.FullName -notmatch 'node_modules|\.git|dist|package-lock' } |
        Select-Object -First 20
    foreach ($cf in $configFiles) {
        $content = Get-Content $cf.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $pathMatches = [regex]::Matches($content, '(?<=["\s:/])([A-Z]:\\[^"*<>|]+|/[a-z][^"*<>|\s]+)')
            foreach ($pm in $pathMatches) {
                $refPath = $pm.Value
                if ($refPath.Length -gt 5 -and $refPath -notmatch 'node_modules|http|\.git' -and -not (Test-Path $refPath)) {
                    Add-Deduction "Config" "WorthFixing" "Config references non-existent path" `
                        "$($cf.Name) references: $refPath" `
                        "File or directory was moved/deleted but config wasn't updated"
                }
            }
        }
    }
}

# ═══════════════════════════════════════════
# GIT DEDUCTIONS
# ═══════════════════════════════════════════
if (-not $focus -or $focus -eq "git") {

    $gitDir = Join-Path $targetPath ".git"
    if (Test-Path $gitDir) {
        Push-Location $targetPath

        # Stale branches
        $branches = git branch --format='%(refname:short)|%(committerdate:unix)' 2>$null
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        foreach ($b in $branches) {
            if ($b -and $b -match '^(.+)\|(\d+)$') {
                $branchName = $matches[1]
                $lastCommit = [long]$matches[2]
                $daysOld = [math]::Round(($now - $lastCommit) / 86400)
                if ($daysOld -gt 30 -and $branchName -ne "main" -and $branchName -ne "master") {
                    Add-Deduction "Git" "WorthFixing" "Stale branch: $branchName" `
                        "Last commit: $daysOld days ago" `
                        "Delete or merge. Stale branches are decision debt."
                }
            }
        }

        # Uncommitted changes
        $status = git status --porcelain 2>$null
        if ($status) {
            $changeCount = ($status | Measure-Object).Count
            Add-Deduction "Git" "Info" "Uncommitted changes" `
                "$changeCount files with uncommitted changes" `
                "Commit or stash. Uncommitted work is invisible work."
        }

        # Check if behind remote
        $behind = git rev-list --count "HEAD..@{upstream}" 2>$null
        if ($behind -and [int]$behind -gt 0) {
            Add-Deduction "Git" "WorthFixing" "Behind remote by $behind commits" `
                "Local branch is $behind commits behind origin" `
                "Pull to stay current. Divergence gets expensive."
        }

        Pop-Location
    }
}

# ═══════════════════════════════════════════
# DEPENDENCY DEDUCTIONS
# ═══════════════════════════════════════════
if (-not $focus -or $focus -eq "deps") {

    # Node.js: package.json vs node_modules freshness
    $pkgJson = Join-Path $targetPath "package.json"
    $nodeModules = Join-Path $targetPath "node_modules"
    if (Test-Path $pkgJson) {
        if (-not (Test-Path $nodeModules)) {
            Add-Deduction "Deps" "WorthFixing" "package.json exists but no node_modules" `
                "package.json found at $pkgJson but node_modules is missing" `
                "Run npm install. Dependencies are declared but not installed."
        } else {
            $pkgTime = (Get-Item $pkgJson).LastWriteTime
            $nmTime = (Get-Item $nodeModules).LastWriteTime
            if ($pkgTime -gt $nmTime) {
                $drift = [math]::Round(($pkgTime - $nmTime).TotalHours, 1)
                Add-Deduction "Deps" "WorthFixing" "node_modules may be stale" `
                    "package.json modified ${drift}h after last node_modules update" `
                    "Run npm install. Declared deps may not match installed."
            }
        }

        # Check for both package-lock.json and yarn.lock
        $hasNpmLock = Test-Path (Join-Path $targetPath "package-lock.json")
        $hasYarnLock = Test-Path (Join-Path $targetPath "yarn.lock")
        if ($hasNpmLock -and $hasYarnLock) {
            Add-Deduction "Deps" "WorthFixing" "Multiple lock files" `
                "Both package-lock.json and yarn.lock exist" `
                "Pick one package manager. Two lock files cause install conflicts."
        }
    }

    # Python: requirements.txt without venv
    $reqTxt = Join-Path $targetPath "requirements.txt"
    if (Test-Path $reqTxt) {
        $hasVenv = (Test-Path (Join-Path $targetPath "venv")) -or (Test-Path (Join-Path $targetPath ".venv"))
        if (-not $hasVenv) {
            Add-Deduction "Deps" "Info" "Python project without virtual environment" `
                "requirements.txt found but no venv/ or .venv/ directory" `
                "Consider using a virtual environment to isolate dependencies."
        }
    }
}

# ═══════════════════════════════════════════
# SERVICE HEALTH DEDUCTIONS
# ═══════════════════════════════════════════
if ($service -or $focus -eq "health") {

    if ($service) {
        $svc = sc.exe query $service 2>$null
        if ($svc -match "RUNNING") {
            # Check how long it's been running via process start time
            $svcPid = sc.exe queryex $service 2>$null | Select-String "PID\s+:\s+(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }
            if ($svcPid -and $svcPid -ne "0") {
                $proc = Get-Process -Id $svcPid -ErrorAction SilentlyContinue
                if ($proc -and $proc.StartTime) {
                    $uptime = (Get-Date) - $proc.StartTime
                    if ($uptime.TotalDays -gt 30) {
                        Add-Deduction "Health" "Info" "Service running $([math]::Round($uptime.TotalDays)) days" `
                            "$service (PID $svcPid) started $($proc.StartTime.ToString('yyyy-MM-dd HH:mm'))" `
                            "Long-running services accumulate memory. Consider periodic restarts."
                    }
                    $memMB = [math]::Round($proc.WorkingSet64 / 1MB)
                    if ($memMB -gt 500) {
                        Add-Deduction "Health" "WorthFixing" "Service using ${memMB}MB memory" `
                            "$service (PID $svcPid) WorkingSet: ${memMB}MB" `
                            "That's substantial. Check for memory leaks or consider a restart."
                    }
                }
            }
        } elseif ($svc -match "STOPPED") {
            Add-Deduction "Health" "Critical" "Service is STOPPED" `
                "$service is not running" `
                "Start it or investigate why it stopped."
        } else {
            Add-Deduction "Health" "Critical" "Service not found" `
                "No service named '$service' exists" `
                "Check the service name. Use sc.exe query to list services."
        }
    }

    # General health: check disk space
    $drive = (Get-Item $targetPath).PSDrive
    if ($drive) {
        $freeGB = [math]::Round($drive.Free / 1GB, 1)
        if ($freeGB -lt 5) {
            $sev = if ($freeGB -lt 1) { "Critical" } else { "WorthFixing" }
            Add-Deduction "Health" $sev "Low disk space: ${freeGB}GB free" `
                "Drive $($drive.Name): has ${freeGB}GB remaining" `
                "Clean up temp files, old builds, or unused dependencies."
        }
    }
}

# ═══════════════════════════════════════════
# CROSS-REFERENCE DEDUCTIONS
# ═══════════════════════════════════════════
if (-not $focus) {

    # Check for dead symlinks
    $symlinks = Get-ChildItem $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Attributes -match "ReparsePoint" -and $_.FullName -notmatch 'node_modules|\.git' } |
        Select-Object -First 10
    foreach ($sl in $symlinks) {
        $target = $sl.Target
        if ($target -and -not (Test-Path $target)) {
            Add-Deduction "CrossRef" "WorthFixing" "Dead symlink" `
                "$($sl.Name) -> $target (target doesn't exist)" `
                "Remove or repoint the symlink."
        }
    }

    # Check for .gitignore missing common patterns
    $gitignore = Join-Path $targetPath ".gitignore"
    if ((Test-Path $pkgJson) -and (Test-Path $gitignore)) {
        $giContent = Get-Content $gitignore -Raw -ErrorAction SilentlyContinue
        if ($giContent -and $giContent -notmatch 'node_modules') {
            Add-Deduction "CrossRef" "Critical" ".gitignore missing node_modules" `
                ".gitignore exists but doesn't exclude node_modules" `
                "You're about to commit 500MB of dependencies. Add node_modules/ to .gitignore."
        }
        if ($giContent -and $giContent -notmatch '\.env') {
            $hasEnv = Test-Path (Join-Path $targetPath ".env")
            if ($hasEnv) {
                Add-Deduction "CrossRef" "Critical" ".gitignore missing .env" `
                    ".env file exists but .gitignore doesn't exclude it" `
                    "Your secrets may end up on GitHub. Add .env to .gitignore immediately."
                }
        }
    }
}

# ═══════════════════════════════════════════
# OUTPUT
# ═══════════════════════════════════════════

$sevIcon = @{
    Critical   = [char]0x25CF  # red dot
    WorthFixing = [char]0x25CB # hollow dot
    Info        = [char]0x25AA # small square
}
$sevColor = @{
    Critical    = "Red"
    WorthFixing = "Yellow"
    Info        = "DarkGray"
}

if ($deductions.Count -eq 0) {
    Write-Host "  No deductions. Either this project is clean, or I need more data." -ForegroundColor Green
    Write-Host '  "When you have eliminated the impossible..."' -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

$critical = @($deductions | Where-Object { $_.Severity -eq "Critical" }).Count
$worth = @($deductions | Where-Object { $_.Severity -eq "WorthFixing" }).Count
$info = @($deductions | Where-Object { $_.Severity -eq "Info" }).Count

Write-Host "  DEDUCTIONS: $($deductions.Count) found" -ForegroundColor White
Write-Host ""

$i = 1
foreach ($d in $deductions) {
    $color = $sevColor[$d.Severity]
    Write-Host "  $i. [$($d.Category.ToUpper())] $($d.Title)" -ForegroundColor $color
    Write-Host "     Evidence: $($d.Evidence)" -ForegroundColor DarkGray
    Write-Host "     -> $($d.Conclusion)" -ForegroundColor White
    Write-Host ""
    $i++
}

Write-Host "  ---" -ForegroundColor DarkGray
Write-Host "  $critical critical | $worth worth fixing | $info informational" -ForegroundColor White

if ($civ) {
    Write-Host "  Analysis complete." -ForegroundColor DarkGray
} else {
    Write-Host '  "The game is afoot."' -ForegroundColor DarkGray
}
Write-Host ""

# Save report if requested
if ($report) {
    $reportContent = "# 221B Deduction Report`n"
    $reportContent += "Project: $projectName`n"
    $reportContent += "Path: $targetPath`n"
    $reportContent += "Time: $timestamp`n`n"
    foreach ($d in $deductions) {
        $reportContent += "## [$($d.Severity)] $($d.Title)`n"
        $reportContent += "Category: $($d.Category)`n"
        $reportContent += "Evidence: $($d.Evidence)`n"
        $reportContent += "Conclusion: $($d.Conclusion)`n`n"
    }
    $reportContent | Out-File -FilePath $report -Encoding UTF8
    Write-Host "  Report saved: $report" -ForegroundColor Cyan
}
