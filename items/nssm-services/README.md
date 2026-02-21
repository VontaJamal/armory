# Running Bots as Windows Services with NSSM

NSSM (Non-Sucking Service Manager) lets you run any script or process as a Windows service that auto-starts on boot and restarts on crash.

## Install

```powershell
choco install nssm
```

## Register a Service

```powershell
nssm install MyService "C:\Python311\python.exe" "C:\path\to\your\bot.py"
nssm set MyService AppDirectory "C:\path\to"
nssm set MyService Start SERVICE_AUTO_START
nssm set MyService AppStdout "C:\path\to\logs\stdout.log"
nssm set MyService AppStderr "C:\path\to\logs\stderr.log"
nssm set MyService AppRotateFiles 1
nssm set MyService AppRotateBytes 1048576
```

## Common Commands

```powershell
# Start/stop
nssm start MyService
nssm stop MyService
nssm restart MyService

# Check status
nssm status MyService
# or
sc query MyService

# Edit config
nssm edit MyService

# Remove
nssm remove MyService confirm
```

## Service Won't Start? Check These

### 1. PAUSED state
Sometimes services get stuck in PAUSED instead of RUNNING:
```powershell
nssm stop MyService
nssm start MyService
```

### 2. Wrong working directory
If your script uses relative paths, `AppDirectory` must be set correctly.

### 3. Python not found
Use the full path to `python.exe`, not just `python`. NSSM services don't inherit your PATH.

### 4. Permission issues
Services run as SYSTEM by default. If your script needs user-level access (files, network drives), set the logon account:
```powershell
nssm set MyService ObjectName ".\YourUsername" "YourPassword"
```

### 5. SSH can't control services
Non-elevated SSH sessions can't stop/start services. Fix with:
```powershell
sc sdset MyService "D:(A;;RPWPCR;;;BU)(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)"
```
This grants Built-in Users read/control permissions.

## Health Check Script

```powershell
$services = @("CryptoPipeline", "CryptoAlertForwarder", "TradingDashboard", "OpenClawGateway")

foreach ($svc in $services) {
    $status = (sc.exe query $svc | Select-String "STATE").ToString().Trim()
    if ($status -notmatch "RUNNING") {
        Write-Output "WARNING: $svc is not running - $status"
        # Add your alert logic here (Telegram, email, etc.)
    }
}
```

