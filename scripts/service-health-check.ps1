# Service health check with Telegram alerting
# Checks NSSM services and sends alerts when something's down
#
# Usage: .\service-health-check.ps1
# Schedule with Task Scheduler or OpenClaw cron

# Customize these
$services = @("CryptoPipeline", "CryptoAlertForwarder", "TradingDashboard", "OpenClawGateway")
$botToken = $env:TELEGRAM_BOT_TOKEN  # or read from secrets file
$chatId = $env:TELEGRAM_CHAT_ID

$down = @()

foreach ($svc in $services) {
    try {
        $result = sc.exe query $svc 2>&1
        if ($result -match "RUNNING") {
            # All good
        } elseif ($result -match "STOPPED|PAUSED") {
            $down += "$svc is STOPPED/PAUSED"
        } else {
            $down += "$svc status unknown"
        }
    } catch {
        $down += "$svc query failed"
    }
}

if ($down.Count -gt 0) {
    $message = "Service Alert:`n" + ($down -join "`n")
    Write-Output $message
    
    if ($botToken -and $chatId) {
        $body = @{
            chat_id = $chatId
            text = $message
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" `
            -Method Post -ContentType "application/json" -Body $body | Out-Null
        Write-Output "Alert sent to Telegram"
    }
} else {
    Write-Output "All services healthy"
}
