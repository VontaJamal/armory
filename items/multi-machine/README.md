# Multi-Machine Gateway Setup

Running OpenClaw across two machines (daily driver + always-on server) is powerful but has real pitfalls. Here's what we learned the hard way.

## The Architecture

```
[Mac/Laptop] â†â”€â”€ Tailscale â”€â”€â†’ [Windows Server]
  (daily driver)                  (always-on)
  Gateway: primary                Gateway: NSSM service
  Telegram: enabled               Telegram: disabled
  Workspace: primary editor       Workspace: sync target
```

## Key Rules

### 1. Only ONE machine owns Telegram
If both gateways have Telegram enabled, you'll get duplicate messages, session conflicts, and weird behavior. Pick one.

### 2. Workspace sync direction matters
Decide which machine is the primary editor and sync ONE direction:
- Mac â†’ Windows: Mac edits, Windows receives
- Windows â†’ Mac: Windows edits, Mac receives

**Never sync both directions.** You will get silent overwrites.

### 3. Kill Syncthing if you're using SCP
Syncthing and SCP sync scripts will fight each other. Pick one. We recommend SCP with a cron/scheduled task â€” it's explicit and predictable.

### 4. Session JSON files cache paths
When you move the gateway between machines, stale session paths in `sessions.json` can cause failures. Clear them after any migration.

### 5. NSSM for Windows services
Install with Chocolatey:
```powershell
choco install nssm
```

Register your gateway:
```powershell
nssm install OpenClawGateway "C:\Program Files\nodejs\node.exe" "C:\Users\YOU\AppData\Roaming\npm\node_modules\openclaw\dist\index.js" "gateway" "start"
nssm set OpenClawGateway AppDirectory "C:\Users\YOU"
nssm set OpenClawGateway Start SERVICE_AUTO_START
```

### 6. SSH service control without elevation
Windows UAC strips admin tokens from non-interactive SSH sessions. Grant service control to your user:
```powershell
sc sdset OpenClawGateway "D:(A;;RPWPCR;;;BU)(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)"
```
Now you can `sc stop/start` from SSH without elevation.

## Sync Script Template

```bash
#!/bin/bash
# Mac â†’ Windows workspace sync (runs every 60s via launchd/cron)
REMOTE="devon@192.168.1.188"
LOCAL="$HOME/.openclaw/workspace/"
REMOTE_PATH="/C/Users/Devon/.openclaw/workspace/"

rsync -avz --delete \
  --exclude '.git' \
  --exclude 'node_modules' \
  -e "ssh -i $HOME/.ssh/id_ed25519" \
  "$LOCAL" "$REMOTE:$REMOTE_PATH"
```

## Debugging Checklist

- [ ] Both machines on same Tailscale network?
- [ ] Only one gateway has Telegram enabled?
- [ ] Sync direction is one-way?
- [ ] No Syncthing running alongside SCP/rsync?
- [ ] NSSM service set to auto-start?
- [ ] `sc sdset` applied for non-elevated service control?
- [ ] Session JSON cleared after migration?

