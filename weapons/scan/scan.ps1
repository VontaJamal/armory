$ErrorActionPreference = "Continue"
Write-Output "=== SHADOW COURT SECURITY AUDIT ==="
Write-Output "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Output ""

# 1. Secrets scan across all repos
Write-Output "=== 1. SECRETS SCAN ==="
$repos = Get-ChildItem "D:\Code Repos" -Directory
$findings = @()

foreach ($repo in $repos) {
    $files = Get-ChildItem $repo.FullName -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch '[\\/](\.git|node_modules|\.venv|dist|__pycache__)[\\/]' -and
        $_.Extension -match '\.(md|ts|js|json|yml|yaml|sh|ps1|html|css|py|toml|txt|env|cfg|ini)$'
    }
    foreach ($f in $files) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        # Telegram bot tokens
        if ($content -match '\d{8,12}:[A-Za-z0-9_-]{30,}') {
            $findings += "CRITICAL|$($repo.Name)|$($f.Name)|Telegram bot token detected"
        }
        # API keys
        if ($content -match '(sk_[a-zA-Z0-9]{20,}|sk-ant-[a-zA-Z0-9]{20,}|gho_[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|AIza[a-zA-Z0-9]{30,})') {
            $findings += "CRITICAL|$($repo.Name)|$($f.Name)|API key pattern: $($Matches[1].Substring(0,[Math]::Min(15,$Matches[1].Length)))..."
        }
        # Private keys
        if ($content -match 'PRIVATE KEY') {
            $findings += "CRITICAL|$($repo.Name)|$($f.Name)|Private key found"
        }
        # Hardcoded passwords
        if ($content -match '(?i)(password|passwd)\s*[:=]\s*[''"][^''"]{6,}[''"]') {
            $findings += "WARNING|$($repo.Name)|$($f.Name)|Possible hardcoded password"
        }
    }
    
    # Check for .env files
    $envFiles = Get-ChildItem $repo.FullName -Recurse -Filter ".env" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
    foreach ($ef in $envFiles) {
        $findings += "WARNING|$($repo.Name)|$($ef.Name)|.env file exists in repo"
    }
}

if ($findings.Count -eq 0) {
    Write-Output "  ALL REPOS CLEAN - No secrets detected"
} else {
    foreach ($f in $findings) {
        $parts = $f.Split('|')
        $icon = if ($parts[0] -eq "CRITICAL") { "RED" } else { "YEL" }
        Write-Output "  [$icon] $($parts[0]): $($parts[1])/$($parts[2]) - $($parts[3])"
    }
}

# 2. .gitignore audit
Write-Output ""
Write-Output "=== 2. GITIGNORE AUDIT ==="
foreach ($repo in $repos) {
    $gi = Join-Path $repo.FullName ".gitignore"
    if (Test-Path $gi) {
        $content = Get-Content $gi -Raw
        $missing = @()
        if ($content -notmatch '\.env') { $missing += ".env" }
        if ($content -notmatch 'node_modules') { $missing += "node_modules" }
        if ($missing.Count -gt 0) {
            Write-Output "  [YEL] WARNING: $($repo.Name) missing: $($missing -join ', ')"
        }
    } else {
        # Only warn for repos with actual code
        $hasCode = Get-ChildItem $repo.FullName -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '\.(ts|js|py|rs)$' }
        if ($hasCode) {
            Write-Output "  [YEL] WARNING: $($repo.Name) has no .gitignore"
        }
    }
}

# 3. Public repos check
Write-Output ""
Write-Output "=== 3. PUBLIC REPOS ==="
try {
    $token = "$env:GITHUB_TOKEN"
    $publicRepos = Invoke-RestMethod -Uri "https://api.github.com/users/VontaJamal/repos?per_page=100&type=public" -Headers @{Authorization="token $token"}
    Write-Output "  Public repos: $($publicRepos.Count)"
    foreach ($r in $publicRepos) {
        Write-Output "  - $($r.name)"
    }
    
    $allRepos = Invoke-RestMethod -Uri "https://api.github.com/user/repos?per_page=100&type=all" -Headers @{Authorization="token $token"}
    $privateRepos = $allRepos | Where-Object { $_.private -eq $true }
    Write-Output "  Private repos: $($privateRepos.Count)"
    foreach ($r in $privateRepos) {
        Write-Output "  - $($r.name) (PRIVATE)"
    }
} catch {
    Write-Output "  ERROR: Could not fetch repos - $_"
}

# 4. Git config check
Write-Output ""
Write-Output "=== 4. GIT CONFIG ==="
$gitConfig = git config --global --list 2>&1
if ($gitConfig -match 'credential') {
    Write-Output "  [YEL] Credential helper configured: check for plain text storage"
} else {
    Write-Output "  No credential helper - clean"
}
if ($gitConfig -match 'password|token|secret') {
    Write-Output "  [RED] CRITICAL: Possible secrets in git config!"
} else {
    Write-Output "  No secrets in git config - clean"
}

# 5. SSH check
Write-Output ""
Write-Output "=== 5. SSH KEYS ==="
$sshDir = "$env:USERPROFILE\.ssh"
if (Test-Path $sshDir) {
    $keys = Get-ChildItem $sshDir -ErrorAction SilentlyContinue
    foreach ($k in $keys) {
        $perms = (Get-Acl $k.FullName).AccessToString
        Write-Output "  $($k.Name) - exists"
    }
    $authKeys = Join-Path $sshDir "authorized_keys"
    if (Test-Path $authKeys) {
        $count = (Get-Content $authKeys | Where-Object { $_.Trim() -and -not $_.StartsWith('#') }).Count
        Write-Output "  authorized_keys: $count entries"
    }
} else {
    Write-Output "  No .ssh directory"
}

# 6. Windows services check
Write-Output ""
Write-Output "=== 6. WINDOWS SERVICES ==="
$services = @("CryptoPipeline", "CryptoAlertForwarder", "TradingDashboard", "OpenClawGateway")
foreach ($svc in $services) {
    $result = sc.exe query $svc 2>&1
    if ($result -match "RUNNING") {
        Write-Output "  ${svc}: RUNNING"
    } elseif ($result -match "STOPPED") {
        Write-Output "  ${svc}: STOPPED"
    } else {
        Write-Output "  ${svc}: NOT FOUND"
    }
}

Write-Output ""
Write-Output "=== AUDIT COMPLETE ==="

