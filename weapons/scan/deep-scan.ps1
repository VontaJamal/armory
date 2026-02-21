$ErrorActionPreference = "Continue"
$token = ""$env:GITHUB_TOKEN""

# Get all public repos
$repos = Invoke-RestMethod -Uri "https://api.github.com/users/VontaJamal/repos?per_page=100&type=public" -Headers @{Authorization="token $token"}
Write-Output "=== PUBLIC REPOS ==="
foreach ($r in $repos) { Write-Output "  $($r.name)" }
Write-Output ""

# Check each public repo locally
$publicNames = $repos | ForEach-Object { $_.name }
foreach ($name in $publicNames) {
    $path = "D:\Code Repos\$name"
    if (Test-Path $path) {
        Write-Output "=== SCANNING: $name ==="
        
        # Check for .env files (should never be committed)
        $envFiles = Get-ChildItem $path -Recurse -File -Filter ".env" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|\.venv)[\\/]' }
        foreach ($ef in $envFiles) {
            Write-Output "  DANGER .env FILE: $($ef.FullName)"
        }
        
        # Check .gitignore for .env
        $gi = Join-Path $path ".gitignore"
        if (Test-Path $gi) {
            $hasEnvIgnore = Select-String -Path $gi -Pattern "^\.env$|^\.env\b" -Quiet
            if (-not $hasEnvIgnore) {
                Write-Output "  WARN: .gitignore missing .env entry"
            }
        } else {
            Write-Output "  WARN: no .gitignore"
        }
        
        # Scan for actual secret patterns (values, not variable names)
        $files = Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName -notmatch '[\\/](\.git|node_modules|\.venv|__pycache__|dist)[\\/]' -and
            $_.Extension -match '\.(md|ts|js|json|yml|yaml|sh|ps1|html|css|py|toml|txt|env|cfg|ini)$'
        }
        foreach ($f in $files) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            
            # Telegram bot tokens (digits:alphanumeric)
            if ($content -match '\d{8,12}:[A-Za-z0-9_-]{30,}') {
                Write-Output "  DANGER TELEGRAM TOKEN: $($f.FullName)"
            }
            # API keys that look real (sk_, sk-ant-, gho_, ghp_, AIza)
            if ($content -match '(sk_[a-zA-Z0-9]{20,}|sk-ant-[a-zA-Z0-9]{20,}|gho_[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|AIza[a-zA-Z0-9]{30,})') {
                Write-Output "  DANGER API KEY: $($f.FullName) match=$($Matches[0].Substring(0,15))..."
            }
            # Private keys
            if ($content -match 'PRIVATE KEY') {
                Write-Output "  DANGER PRIVATE KEY: $($f.FullName)"
            }
            # Hardcoded passwords
            if ($content -match '(?i)(password|passwd|pwd)\s*[:=]\s*[''"][^''"]{4,}[''"]') {
                Write-Output "  WARN PASSWORD: $($f.FullName)"
            }
        }
    } else {
        Write-Output "=== SKIP (not cloned): $name ==="
    }
}
Write-Output "`n=== SCAN COMPLETE ==="


