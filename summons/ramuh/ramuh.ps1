<#
.SYNOPSIS
    Ramuh - Judgment Bolt - Full system diagnostic
.DESCRIPTION
    Tests network, SSH, services, API keys, disk space, gateway, and ports in one shot.
.EXAMPLE
    .\ramuh.ps1
    .\ramuh.ps1 -Network
    .\ramuh.ps1 -Services
    .\ramuh.ps1 -Keys
    .\ramuh.ps1 -Disk
#>
param(
    [switch]$Network,
    [switch]$Services,
    [switch]$Keys,
    [switch]$Disk,
    [switch]$All,
    [switch]$Help
)

# ── Config ──────────────────────────────────────────────
$config = @{
    machines = @(
        @{ name = "local"; host = "127.0.0.1" },
        @{ name = "mac"; host = "192.168.1.165"; sshUser = "vonta" }
    )
    sshHosts = @(
        @{ name = "mac"; user = "vonta"; host = "192.168.1.165" }
    )
    services = @("OpenClawGateway", "CryptoPipeline", "CryptoAlertForwarder", "TradingDashboard")
    apiKeys = @("ANTHROPIC_API_KEY", "GITHUB_TOKEN", "OPENAI_API_KEY")
    diskWarningPercent = 15
    gatewayPort = 18789
    dashboardPort = 8420
}

# ── Colors ──────────────────────────────────────────────
function Write-Pass($msg) { Write-Host "    $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "    $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }
function Write-Section($msg) { Write-Host "`n  $msg" -ForegroundColor Cyan }
function Write-Banner {
    Write-Host ""
    Write-Host "  ⚡ " -NoNewline -ForegroundColor Yellow
    Write-Host "Judgment Bolt" -ForegroundColor White
    Write-Host "  ─────────────────────────────" -ForegroundColor DarkGray
}

if ($Help) {
    Write-Host @"

  ⚡ Ramuh — Judgment Bolt
  Full system diagnostic in one command.

  Usage:
    .\ramuh.ps1              Run all checks
    .\ramuh.ps1 -Network     Network + SSH only
    .\ramuh.ps1 -Services    Windows services only
    .\ramuh.ps1 -Keys        API key validation only
    .\ramuh.ps1 -Disk        Disk space only
    .\ramuh.ps1 -Help        This message

"@
    exit 0
}

# Default to all if no flags
$runAll = (-not $Network -and -not $Services -and -not $Keys -and -not $Disk) -or $All
$issues = @()

Write-Banner

# ── Network ─────────────────────────────────────────────
if ($runAll -or $Network) {
    Write-Section "NETWORK"
    foreach ($m in $config.machines) {
        try {
            $ping = Test-Connection -ComputerName $m.host -Count 1 -ErrorAction Stop
            $ms = $ping.ResponseTime
            Write-Pass "$($m.host.PadRight(22)) ($($m.name))".PadRight(40) + "✓  ${ms}ms"
            Write-Host "    $($m.host.PadRight(22))" -NoNewline -ForegroundColor White
            Write-Host " ($($m.name))".PadRight(18) -NoNewline -ForegroundColor DarkGray
            Write-Host "✓  ${ms}ms" -ForegroundColor Green
        } catch {
            Write-Host "    $($m.host.PadRight(22))" -NoNewline -ForegroundColor White
            Write-Host " ($($m.name))".PadRight(18) -NoNewline -ForegroundColor DarkGray
            Write-Host "✗  unreachable" -ForegroundColor Red
            $issues += "Cannot reach $($m.name) ($($m.host))"
        }
    }

    # DNS check
    Write-Host ""
    try {
        $dns = Resolve-DnsName google.com -ErrorAction Stop | Select-Object -First 1
        Write-Host "    DNS resolution".PadRight(40) -NoNewline -ForegroundColor White
        Write-Host "✓  working" -ForegroundColor Green
    } catch {
        Write-Host "    DNS resolution".PadRight(40) -NoNewline -ForegroundColor White
        Write-Host "✗  failed" -ForegroundColor Red
        $issues += "DNS resolution failed"
    }

    # SSH
    Write-Section "SSH"
    foreach ($s in $config.sshHosts) {
        try {
            $result = ssh -o ConnectTimeout=5 -o BatchMode=yes "$($s.user)@$($s.host)" "echo ok" 2>&1
            if ($result -match "ok") {
                Write-Host "    $($s.user)@$($s.host)".PadRight(40) -NoNewline -ForegroundColor White
                Write-Host "✓  connected" -ForegroundColor Green
            } else {
                throw "no response"
            }
        } catch {
            Write-Host "    $($s.user)@$($s.host)".PadRight(40) -NoNewline -ForegroundColor White
            Write-Host "✗  failed" -ForegroundColor Red
            $issues += "SSH to $($s.user)@$($s.host) failed"
        }
    }
}

# ── Services ────────────────────────────────────────────
if ($runAll -or $Services) {
    Write-Section "SERVICES"
    foreach ($svc in $config.services) {
        try {
            $status = (Get-Service -Name $svc -ErrorAction Stop).Status
            if ($status -eq 'Running') {
                Write-Host "    $($svc.PadRight(36))" -NoNewline -ForegroundColor White
                Write-Host "✓  RUNNING" -ForegroundColor Green
            } else {
                Write-Host "    $($svc.PadRight(36))" -NoNewline -ForegroundColor White
                Write-Host "✗  $status" -ForegroundColor Red
                $issues += "$svc is $status"
            }
        } catch {
            # Not a Windows service — try NSSM
            try {
                $nssm = & nssm status $svc 2>&1
                if ($nssm -match "SERVICE_RUNNING") {
                    Write-Host "    $($svc.PadRight(36))" -NoNewline -ForegroundColor White
                    Write-Host "✓  RUNNING" -ForegroundColor Green
                } else {
                    Write-Host "    $($svc.PadRight(36))" -NoNewline -ForegroundColor White
                    Write-Host "✗  $nssm" -ForegroundColor Red
                    $issues += "$svc is not running"
                }
            } catch {
                Write-Host "    $($svc.PadRight(36))" -NoNewline -ForegroundColor White
                Write-Host "—  not found" -ForegroundColor DarkGray
            }
        }
    }
}

# ── API Keys ────────────────────────────────────────────
if ($runAll -or $Keys) {
    Write-Section "API KEYS"
    foreach ($key in $config.apiKeys) {
        $val = [System.Environment]::GetEnvironmentVariable($key, "User")
        if (-not $val) { $val = [System.Environment]::GetEnvironmentVariable($key, "Process") }
        
        if ($val) {
            $masked = $val.Substring(0, [Math]::Min(8, $val.Length)) + "..."
            Write-Host "    $($key.PadRight(36))" -NoNewline -ForegroundColor White
            Write-Host "✓  set ($masked)" -ForegroundColor Green
        } else {
            Write-Host "    $($key.PadRight(36))" -NoNewline -ForegroundColor White
            Write-Host "—  not set" -ForegroundColor Yellow
        }
    }
}

# ── Disk ────────────────────────────────────────────────
if ($runAll -or $Disk) {
    Write-Section "DISK"
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $freeGB = [math]::Round($_.FreeSpace / 1GB, 1)
        $totalGB = [math]::Round($_.Size / 1GB, 1)
        $pct = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
        $label = "$($_.DeviceID)  ${freeGB} GB free (${pct}%)"
        
        if ($pct -lt $config.diskWarningPercent) {
            Write-Host "    $($label.PadRight(36))" -NoNewline -ForegroundColor White
            Write-Host "⚠  low" -ForegroundColor Yellow
            $issues += "Disk $($_.DeviceID) is at ${pct}% free"
        } else {
            Write-Host "    $($label.PadRight(36))" -NoNewline -ForegroundColor White
            Write-Host "✓  healthy" -ForegroundColor Green
        }
    }
}

# ── Ports ───────────────────────────────────────────────
if ($runAll) {
    Write-Section "PORTS"
    $ports = @(
        @{ port = $config.gatewayPort; name = "Gateway" },
        @{ port = $config.dashboardPort; name = "Dashboard" }
    )
    foreach ($p in $ports) {
        $listening = Get-NetTCPConnection -LocalPort $p.port -ErrorAction SilentlyContinue | Where-Object State -eq "Listen"
        if ($listening) {
            Write-Host "    $("$($p.name) (:$($p.port))".PadRight(36))" -NoNewline -ForegroundColor White
            Write-Host "✓  listening" -ForegroundColor Green
        } else {
            Write-Host "    $("$($p.name) (:$($p.port))".PadRight(36))" -NoNewline -ForegroundColor White
            Write-Host "✗  not listening" -ForegroundColor Red
            $issues += "$($p.name) port $($p.port) not listening"
        }
    }
}

# ── Summary ─────────────────────────────────────────────
Write-Host "`n  ─────────────────────────────" -ForegroundColor DarkGray
if ($issues.Count -eq 0) {
    Write-Host "  ⚡ All clear. No issues found." -ForegroundColor Green
} else {
    Write-Host "  $($issues.Count) issue(s) found:" -ForegroundColor Yellow
    foreach ($i in $issues) {
        Write-Host "    ✗ $i" -ForegroundColor Red
    }
}
Write-Host ""
