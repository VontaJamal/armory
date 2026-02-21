<#
.SYNOPSIS
    Ramuh - Judgment Bolt - Full system diagnostic
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

# -- Config -------------------------------------------------------
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

# -- Helpers -------------------------------------------------------
function Write-Section($msg) { Write-Host ("`n  " + $msg) -ForegroundColor Cyan }
function Write-Banner {
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "Judgment Bolt" -ForegroundColor Yellow
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
}

function Write-Check {
    param([string]$Label, [string]$Status, [string]$Color, [int]$Pad = 40)
    Write-Host ("    " + $Label.PadRight($Pad)) -NoNewline -ForegroundColor White
    Write-Host $Status -ForegroundColor $Color
}

if ($Help) {
    Write-Host ""
    Write-Host "  Ramuh -- Judgment Bolt"
    Write-Host "  Full system diagnostic in one command."
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\ramuh.ps1              Run all checks"
    Write-Host "    .\ramuh.ps1 -Network     Network + SSH only"
    Write-Host "    .\ramuh.ps1 -Services    Windows services only"
    Write-Host "    .\ramuh.ps1 -Keys        API key validation only"
    Write-Host "    .\ramuh.ps1 -Disk        Disk space only"
    Write-Host "    .\ramuh.ps1 -Help        This message"
    Write-Host ""
    exit 0
}

$runAll = (-not $Network -and -not $Services -and -not $Keys -and -not $Disk) -or $All
$issues = [System.Collections.ArrayList]::new()

Write-Banner

# -- Network -------------------------------------------------------
if ($runAll -or $Network) {
    Write-Section "NETWORK"
    foreach ($m in $config.machines) {
        try {
            $ping = Test-Connection -ComputerName $m.host -Count 1 -ErrorAction Stop
            $ms = $ping.ResponseTime
            Write-Check "$($m.host) ($($m.name))" "pass ${ms}ms" "Green"
        }
        catch {
            Write-Check "$($m.host) ($($m.name))" "FAIL unreachable" "Red"
            [void]$issues.Add("Cannot reach $($m.name) ($($m.host))")
        }
    }

    # DNS
    Write-Host ""
    try {
        Resolve-DnsName google.com -ErrorAction Stop | Out-Null
        Write-Check "DNS resolution" "pass" "Green"
    }
    catch {
        Write-Check "DNS resolution" "FAIL" "Red"
        [void]$issues.Add("DNS resolution failed")
    }

    # SSH
    Write-Section "SSH"
    foreach ($s in $config.sshHosts) {
        $label = "$($s.user)@$($s.host)"
        try {
            $result = ssh -o ConnectTimeout=5 -o BatchMode=yes $label "echo ok" 2>&1
            if ("$result" -match "ok") {
                Write-Check $label "pass connected" "Green"
            }
            else {
                throw "no response"
            }
        }
        catch {
            Write-Check $label "FAIL" "Red"
            [void]$issues.Add("SSH to $label failed")
        }
    }
}

# -- Services -------------------------------------------------------
if ($runAll -or $Services) {
    Write-Section "SERVICES"
    foreach ($svc in $config.services) {
        $svcObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($svcObj) {
            if ($svcObj.Status -eq 'Running') {
                Write-Check $svc "pass RUNNING" "Green"
            }
            else {
                Write-Check $svc ("FAIL " + $svcObj.Status) "Red"
                [void]$issues.Add("$svc is $($svcObj.Status)")
            }
        }
        else {
            # Try NSSM
            $nssmOut = $null
            try { $nssmOut = & nssm status $svc 2>&1 } catch {}
            if ($nssmOut -match "SERVICE_RUNNING") {
                Write-Check $svc "pass RUNNING (nssm)" "Green"
            }
            elseif ($nssmOut) {
                Write-Check $svc ("FAIL " + ($nssmOut -replace "`n"," ").Trim()) "Red"
                [void]$issues.Add("$svc is not running")
            }
            else {
                Write-Check $svc "-- not found" "DarkGray"
            }
        }
    }
}

# -- API Keys -------------------------------------------------------
if ($runAll -or $Keys) {
    Write-Section "API KEYS"
    foreach ($key in $config.apiKeys) {
        $val = [System.Environment]::GetEnvironmentVariable($key, "User")
        if (-not $val) { $val = [System.Environment]::GetEnvironmentVariable($key, "Process") }
        if ($val) {
            $masked = $val.Substring(0, [Math]::Min(8, $val.Length)) + "..."
            Write-Check $key "pass set ($masked)" "Green"
        }
        else {
            Write-Check $key "-- not set" "Yellow"
        }
    }
}

# -- Disk -------------------------------------------------------
if ($runAll -or $Disk) {
    Write-Section "DISK"
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Where-Object { $_.Size -gt 0 } | ForEach-Object {
        $freeGB = [math]::Round($_.FreeSpace / 1GB, 1)
        $pct = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
        $label = "$($_.DeviceID)  ${freeGB} GB free (${pct}%)"
        if ($pct -lt $config.diskWarningPercent) {
            Write-Check $label "WARNING low" "Yellow"
            [void]$issues.Add("Disk $($_.DeviceID) is at ${pct}% free")
        }
        else {
            Write-Check $label "pass healthy" "Green"
        }
    }
}

# -- Ports -------------------------------------------------------
if ($runAll) {
    Write-Section "PORTS"
    $ports = @(
        @{ port = $config.gatewayPort; name = "Gateway" },
        @{ port = $config.dashboardPort; name = "Dashboard" }
    )
    foreach ($p in $ports) {
        $label = "$($p.name) (:$($p.port))"
        $listening = Get-NetTCPConnection -LocalPort $p.port -ErrorAction SilentlyContinue |
            Where-Object { $_.State -eq "Listen" }
        if ($listening) {
            Write-Check $label "pass listening" "Green"
        }
        else {
            Write-Check $label "FAIL not listening" "Red"
            [void]$issues.Add("$($p.name) port $($p.port) not listening")
        }
    }
}

# -- Summary -------------------------------------------------------
Write-Host ("`n  -----------------------------") -ForegroundColor DarkGray
if ($issues.Count -eq 0) {
    Write-Host "  All clear. No issues found." -ForegroundColor Green
}
else {
    Write-Host "  $($issues.Count) issue(s) found:" -ForegroundColor Yellow
    foreach ($i in $issues) {
        Write-Host "    x $i" -ForegroundColor Red
    }
}
Write-Host ""
