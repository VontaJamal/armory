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

$config = @{
    machines = @(
        # @{ name = "mac"; host = "192.168.1.165"; sshUser = "vonta"; sshKey = "" }
    )
    services = @(
        # "OpenClawGateway", "CryptoPipeline"
    )
    apiKeys = @{
        "ANTHROPIC_API_KEY" = "https://api.anthropic.com/v1/messages"
        "GITHUB_TOKEN" = "https://api.github.com/user"
        "OPENAI_API_KEY" = "https://api.openai.com/v1/models"
    }
    diskWarningPercent = 15
    gatewayPort = 18789
    telegramBotToken = $env:TELEGRAM_BOT_TOKEN
}

function Write-Check {
    param($label, $status, $detail)
    switch ($status) {
        "ok"   { $icon = "[OK]"; $color = "Green" }
        "fail" { $icon = "[X]"; $color = "Red" }
        "warn" { $icon = "[!]"; $color = "Yellow" }
        "skip" { $icon = "[-]"; $color = "DarkGray" }
    }
    $pad = $label.PadRight(28)
    Write-Host -NoNewline "    $pad"
    Write-Host -NoNewline -ForegroundColor $color "$icon "
    Write-Host $detail
}

Write-Host ""
Write-Host "  Judgment Bolt" -ForegroundColor Cyan
Write-Host ""

if ($allChecks -or $Network) {
    Write-Host "  NETWORK" -ForegroundColor White
    Write-Check "localhost" "ok" "<1ms"
    foreach ($m in $config.machines) {
        $r = ping -n 1 -w 2000 $m.host 2>$null
        if ($r -match "time[<=](\d+)ms") {
            Write-Check "$($m.name) ($($m.host))" "ok" "$($Matches[1])ms"
        } else {
            Write-Check "$($m.name) ($($m.host))" "fail" "unreachable"
            $issues += "$($m.name) is unreachable"
        }
    }
    Write-Host ""
    if ($config.machines.Count -gt 0) {
        Write-Host "  SSH" -ForegroundColor White
        foreach ($m in $config.machines) {
            if (-not $m.sshUser) { continue }
            $result = ssh -o ConnectTimeout=3 -o BatchMode=yes "$($m.sshUser)@$($m.host)" "echo ok" 2>$null
            if ($result -eq "ok") {
                Write-Check "$($m.sshUser)@$($m.host)" "ok" "connected"
            } else {
                Write-Check "$($m.sshUser)@$($m.host)" "fail" "failed"
                $issues += "SSH to $($m.name) failed"
            }
        }
        Write-Host ""
    }
}

if ($allChecks -or $Services) {
    if ($config.services.Count -gt 0) {
        Write-Host "  SERVICES" -ForegroundColor White
        foreach ($svc in $config.services) {
            $r = sc.exe query $svc 2>&1
            if ($r -match "RUNNING") {
                Write-Check $svc "ok" "RUNNING"
            } elseif ($r -match "STOPPED") {
                Write-Check $svc "fail" "STOPPED"
                $issues += "$svc is STOPPED"
            } else {
                Write-Check $svc "fail" "not found"
                $issues += "$svc not found"
            }
        }
        Write-Host ""
    }
}

if ($allChecks -or $Keys) {
    Write-Host "  API KEYS" -ForegroundColor White
    foreach ($entry in $config.apiKeys.GetEnumerator()) {
        $keyName = $entry.Key
        $validateUrl = $entry.Value
        $keyValue = [System.Environment]::GetEnvironmentVariable($keyName, "User")
        if (-not $keyValue) { $keyValue = [System.Environment]::GetEnvironmentVariable($keyName) }
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
                Invoke-WebRequest -Uri $validateUrl -Headers $headers -Method Head -TimeoutSec 5 -ErrorAction Stop | Out-Null
                Write-Check $keyName "ok" "valid"
            } catch {
                $code = 0
                if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
                if ($code -eq 401 -or $code -eq 403) {
                    Write-Check $keyName "fail" "expired or invalid"
                    $issues += "$keyName expired or invalid"
                } elseif ($code -ge 400 -and $code -lt 500) {
                    Write-Check $keyName "ok" "key accepted"
                } else {
                    Write-Check $keyName "warn" "could not validate"
                }
            }
        }
    }
    Write-Host ""
}

if ($allChecks -or $Disk) {
    Write-Host "  DISK" -ForegroundColor White
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
        $free = $_.Free
        $total = $_.Used + $_.Free
        $pct = [math]::Round(($free / $total) * 100, 1)
        $freeGB = [math]::Round($free / 1GB, 1)
        $label = "$($_.Name): $freeGB GB free ($pct%)"
        if ($pct -lt $config.diskWarningPercent) {
            Write-Check $label "warn" "low"
            $issues += "$($_.Name): drive low ($pct% free)"
        } else {
            Write-Check $label "ok" "healthy"
        }
    }
    Write-Host ""
}

if ($allChecks) {
    $port = $config.gatewayPort
    $listener = netstat -an 2>$null | Select-String ":$port\s"
    if ($listener) {
        Write-Host "  GATEWAY" -ForegroundColor White
        Write-Check "Port $port" "ok" "listening"
        Write-Host ""
    }
}

if ($allChecks -and $config.telegramBotToken) {
    Write-Host "  TELEGRAM" -ForegroundColor White
    try {
        $r = Invoke-RestMethod -Uri "https://api.telegram.org/bot$($config.telegramBotToken)/getMe" -TimeoutSec 5
        if ($r.ok) {
            Write-Check "Bot @$($r.result.username)" "ok" "responding"
        } else {
            Write-Check "Bot token" "fail" "invalid"
            $issues += "Telegram bot invalid"
        }
    } catch {
        Write-Check "Bot token" "fail" "could not connect"
        $issues += "Telegram bot check failed"
    }
    Write-Host ""
}

Write-Host "  -------------------------" -ForegroundColor DarkGray
if ($issues.Count -eq 0) {
    Write-Host "  All clear. No issues found." -ForegroundColor Green
} else {
    Write-Host "  $($issues.Count) issue(s) found:" -ForegroundColor Yellow
    foreach ($issue in $issues) {
        Write-Host "    - $issue" -ForegroundColor Red
    }
}
Write-Host ""
