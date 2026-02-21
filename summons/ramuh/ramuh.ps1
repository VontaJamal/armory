<#
.SYNOPSIS
  Ramuh — Judgment Bolt. Full system diagnostic.
.USAGE
  .\ramuh.ps1              Full diagnostic
  .\ramuh.ps1 -Network     Network + SSH only
  .\ramuh.ps1 -Services    Services only
  .\ramuh.ps1 -Keys        API key validation only
  .\ramuh.ps1 -Disk        Disk space only
#>

param(
    [switch]$Network,
    [switch]$Services,
    [switch]$Keys,
    [switch]$Disk,
    [switch]$All
)

$ErrorActionPreference = "Continue"
$allChecks = -not ($Network -or $Services -or $Keys -or $Disk)
$issues = @()

# ===== CONFIGURE THIS =====
$config = @{
    machines = @(
        # Add your machines here
        # @{ name = "mac"; host = "192.168.1.165"; sshUser = "vonta"; sshKey = "$env:USERPROFILE\.ssh\id_ed25519" }
    )
    services = @(
        # Add your Windows services here
        # "OpenClawGateway", "CryptoPipeline"
    )
    apiKeys = @{
        # env var name = validation URL (or $null for existence check only)
        "ANTHROPIC_API_KEY" = "https://api.anthropic.com/v1/messages"
        "GITHUB_TOKEN" = "https://api.github.com/user"
        "OPENAI_API_KEY" = "https://api.openai.com/v1/models"
        "GOOGLE_API_KEY" = $null
    }
    diskWarningPercent = 15
    gatewayPort = 18789
    telegramBotToken = $env:TELEGRAM_BOT_TOKEN
}
# ==========================

function Write-Check($label, $status, $detail) {
    $icon = switch ($status) {
        "ok"   { "✓"; $color = "Green" }
        "fail" { "✗"; $color = "Red" }
        "warn" { "!"; $color = "Yellow" }
        "skip" { "-"; $color = "DarkGray" }
    }
    $padded = $label.PadRight(28)
    Write-Host "    $padded" -NoNewline
    Write-Host "$icon  " -ForegroundColor $color -NoNewline
    Write-Host "$detail"
}

Write-Host ""
Write-Host "  Judgment Bolt" -ForegroundColor Cyan
Write-Host ""

# --- NETWORK ---
if ($allChecks -or $Network) {
    Write-Host "  NETWORK" -ForegroundColor White
    
    # Local
    Write-Check "localhost" "ok" "<1ms"
    
    foreach ($m in $config.machines) {
        $ping = ping -n 1 -w 2000 $m.host 2>$null
        if ($ping -match "time[<=](\d+)ms") {
            Write-Check "$($m.name) ($($m.host))" "ok" "$($Matches[1])ms"
        } elseif ($ping -match "time<1ms") {
            Write-Check "$($m.name) ($($m.host))" "ok" "<1ms"
        } else {
            Write-Check "$($m.name) ($($m.host))" "fail" "unreachable"
            $issues += "$($m.name) is unreachable"
        }
    }
    Write-Host ""
    
    # SSH
    if ($config.machines.Count -gt 0) {
        Write-Host "  SSH" -ForegroundColor White
        foreach ($m in $config.machines) {
            if (-not $m.sshUser) { continue }
            $keyArg = if ($m.sshKey) { "-i `"$($m.sshKey)`"" } else { "" }
            $result = ssh -o ConnectTimeout=3 -o BatchMode=yes $keyArg "$($m.sshUser)@$($m.host)" "echo ok" 2>$null
            if ($result -eq "ok") {
                Write-Check "$($m.sshUser)@$($m.host)" "ok" "connected"
            } else {
                Write-Check "$($m.sshUser)@$($m.host)" "fail" "connection failed"
                $issues += "SSH to $($m.name) failed"
            }
        }
        Write-Host ""
    }
}

# --- SERVICES ---
if ($allChecks -or $Services) {
    if ($config.services.Count -gt 0) {
        Write-Host "  SERVICES" -ForegroundColor White
        foreach ($svc in $config.services) {
            $result = sc.exe query $svc 2>&1
            if ($result -match "RUNNING") {
                Write-Check $svc "ok" "RUNNING"
            } elseif ($result -match "STOPPED") {
                Write-Check $svc "fail" "STOPPED"
                $issues += "$svc is STOPPED"
            } elseif ($result -match "PAUSED") {
                Write-Check $svc "warn" "PAUSED"
                $issues += "$svc is PAUSED"
            } else {
                Write-Check $svc "fail" "not found"
                $issues += "$svc not found"
            }
        }
        Write-Host ""
    }
}

# --- API KEYS ---
if ($allChecks -or $Keys) {
    Write-Host "  API KEYS" -ForegroundColor White
    foreach ($entry in $config.apiKeys.GetEnumerator()) {
        $keyName = $entry.Key
        $validateUrl = $entry.Value
        $keyValue = [System.Environment]::GetEnvironmentVariable($keyName, "User")
        if (-not $keyValue) { $keyValue = [System.Environment]::GetEnvironmentVariable($keyName, "Process") }
        
        if (-not $keyValue) {
            Write-Check $keyName "skip" "not set"
            continue
        }
        
        if ($validateUrl) {
            try {
                $headers = @{}
                if ($keyName -eq "GITHUB_TOKEN") {
                    $headers["Authorization"] = "token $keyValue"
                } elseif ($keyName -eq "ANTHROPIC_API_KEY") {
                    $headers["x-api-key"] = $keyValue
                    $headers["anthropic-version"] = "2023-06-01"
                } elseif ($keyName -eq "OPENAI_API_KEY") {
                    $headers["Authorization"] = "Bearer $keyValue"
                }
                
                $response = Invoke-WebRequest -Uri $validateUrl -Headers $headers -Method Head -TimeoutSec 5 -ErrorAction Stop
                Write-Check $keyName "ok" "valid"
            } catch {
                $code = $_.Exception.Response.StatusCode.value__
                if ($code -eq 401 -or $code -eq 403) {
                    Write-Check $keyName "fail" "expired or invalid"
                    $issues += "$keyName is expired or invalid"
                } elseif ($code -eq 400 -or $code -eq 404 -or $code -eq 405) {
                    # Method not allowed or similar = key probably valid, endpoint doesn't accept HEAD
                    Write-Check $keyName "ok" "valid (key accepted)"
                } else {
                    Write-Check $keyName "warn" "could not validate (HTTP $code)"
                }
            }
        } else {
            Write-Check $keyName "ok" "set ($(($keyValue.Substring(0,6)))...)"
        }
    }
    Write-Host ""
}

# --- DISK ---
if ($allChecks -or $Disk) {
    Write-Host "  DISK" -ForegroundColor White
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
        $free = $_.Free
        $total = $_.Used + $_.Free
        $pct = [math]::Round(($free / $total) * 100, 1)
        $freeGB = [math]::Round($free / 1GB, 1)
        
        if ($pct -lt $config.diskWarningPercent) {
            Write-Check "$($_.Name): $($freeGB) GB free ($pct%)" "warn" "low"
            $issues += "$($_.Name): drive is low ($pct% free)"
        } else {
            Write-Check "$($_.Name): $($freeGB) GB free ($pct%)" "ok" "healthy"
        }
    }
    Write-Host ""
}

# --- GATEWAY (optional) ---
if ($allChecks) {
    $port = $config.gatewayPort
    $listener = netstat -an 2>$null | Select-String ":$port\s"
    if ($listener) {
        Write-Host "  GATEWAY" -ForegroundColor White
        Write-Check "Port $port" "ok" "listening"
        Write-Host ""
    }
}

# --- TELEGRAM (optional) ---
if ($allChecks -and $config.telegramBotToken) {
    Write-Host "  TELEGRAM" -ForegroundColor White
    try {
        $r = Invoke-RestMethod -Uri "https://api.telegram.org/bot$($config.telegramBotToken)/getMe" -TimeoutSec 5
        if ($r.ok) {
            Write-Check "Bot @$($r.result.username)" "ok" "responding"
        } else {
            Write-Check "Bot token" "fail" "invalid response"
            $issues += "Telegram bot not responding"
        }
    } catch {
        Write-Check "Bot token" "fail" "could not connect"
        $issues += "Telegram bot check failed"
    }
    Write-Host ""
}

# --- SUMMARY ---
Write-Host "  ─────────────────────────" -ForegroundColor DarkGray
if ($issues.Count -eq 0) {
    Write-Host "  All clear. No issues found." -ForegroundColor Green
} else {
    Write-Host "  $($issues.Count) issue$(if($issues.Count -gt 1){'s'}) found:" -ForegroundColor Yellow
    foreach ($i in $issues) {
        Write-Host "    - $i" -ForegroundColor Red
    }
}
Write-Host ""
