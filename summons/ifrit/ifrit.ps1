<#
.SYNOPSIS
  Ifrit — Summon a fully configured OpenClaw agent
.USAGE
  .\ifrit.ps1 -Name "cipher" -Role "Crypto intelligence"
  .\ifrit.ps1  (interactive mode)
#>

param(
    [string]$Name,
    [string]$Role,
    [string]$Model = "claude-sonnet-4-20250514",
    [string]$Heartbeat = "55m",
    [string]$ActiveStart = "08:00",
    [string]$ActiveEnd = "23:00",
    [switch]$NoTelegram
)

$ErrorActionPreference = "Stop"
$ocBase = "$env:USERPROFILE\.openclaw"
$configPath = "$ocBase\openclaw.json"

# --- Interactive mode ---
if (-not $Name) {
    Write-Host ""
    Write-Host "  Summoning Ifrit..." -ForegroundColor Red
    Write-Host ""
    $Name = Read-Host "  Agent name"
    $Role = Read-Host "  Role"
    $modelInput = Read-Host "  Model [claude-sonnet-4-20250514]"
    if ($modelInput) { $Model = $modelInput }
    $hbInput = Read-Host "  Heartbeat interval [55m]"
    if ($hbInput) { $Heartbeat = $hbInput }
    $activeInput = Read-Host "  Active hours [08:00-23:00]"
    if ($activeInput -match "(\d{2}:\d{2})-(\d{2}:\d{2})") {
        $ActiveStart = $Matches[1]
        $ActiveEnd = $Matches[2]
    }
}

$Name = $Name.ToLower()
$workspace = "$ocBase\workspace-$Name"
$agentDir = "$ocBase\agents\$Name\agent"

# --- Create workspace ---
Write-Host ""
Write-Host "  Creating workspace..." -ForegroundColor Yellow

New-Item -ItemType Directory -Path $workspace -Force | Out-Null
New-Item -ItemType Directory -Path "$workspace\memory" -Force | Out-Null
New-Item -ItemType Directory -Path $agentDir -Force | Out-Null

# SOUL.md
@"
# SOUL.md - Who You Are

## Name: $($Name.Substring(0,1).ToUpper() + $Name.Substring(1))
## Role: $Role

You are a specialist agent. You own your domain completely.

## Core Directives
- Execute your domain with precision
- Report results, not problems  
- Verify before claiming success
- Be concise — say what matters, skip the filler

## Personality
(Customize this — give yourself a real voice)

## Boundaries
- Stay in your lane — don't overlap with other agents
- Ask the orchestrator if something is outside your domain
- Never modify system configs without approval
"@ | Set-Content "$workspace\SOUL.md" -Encoding UTF8

# AGENTS.md
@"
# AGENTS.md

## Every Session
1. Read SOUL.md — this is who you are
2. Read memory/YYYY-MM-DD.md (today + yesterday) for recent context
3. Check for pending tasks or messages

## Memory
- Daily notes: memory/YYYY-MM-DD.md
- Long-term: MEMORY.md
- Write things down. Mental notes don't survive restarts.

## Safety
- Don't exfiltrate data
- Don't run destructive commands without asking
- When in doubt, ask
"@ | Set-Content "$workspace\AGENTS.md" -Encoding UTF8

# MEMORY.md
@"
# MEMORY.md - Long-Term Memory

## Created
$(Get-Date -Format "yyyy-MM-dd") — Summoned by Ifrit

## Role
$Role

## Key Context
(Fill this in as you learn your domain)
"@ | Set-Content "$workspace\MEMORY.md" -Encoding UTF8

# IDENTITY.md
@"
# Identity
- Name: $($Name.Substring(0,1).ToUpper() + $Name.Substring(1))
- Role: $Role
- Created: $(Get-Date -Format "yyyy-MM-dd")
"@ | Set-Content "$workspace\IDENTITY.md" -Encoding UTF8

# TOOLS.md
"# TOOLS.md - Agent-Specific Notes`n`nAdd your tool configs, SSH hosts, API endpoints, etc.`n" | Set-Content "$workspace\TOOLS.md" -Encoding UTF8

Write-Host "  Workspace created: $workspace" -ForegroundColor Green

# --- Update openclaw.json ---
Write-Host "  Registering agent..." -ForegroundColor Yellow

$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Check if agent already exists
$existing = $config.agents.list | Where-Object { $_.id -eq $Name }
if ($existing) {
    Write-Host "  Agent '$Name' already registered in config — skipping" -ForegroundColor DarkGray
} else {
    $agentEntry = [PSCustomObject]@{
        id = $Name
        name = $Name.Substring(0,1).ToUpper() + $Name.Substring(1)
        workspace = $workspace
        agentDir = $agentDir
        model = @{ primary = "anthropic/$Model" }
        heartbeat = @{
            every = $Heartbeat
            activeHours = @{
                start = $ActiveStart
                end = $ActiveEnd
                timezone = "America/New_York"
            }
            model = "anthropic/claude-haiku-4-5-20251001"
        }
        identity = @{
            name = $Name.Substring(0,1).ToUpper() + $Name.Substring(1)
        }
    }

    $config.agents.list += $agentEntry

    # Add to agentToAgent allow list
    if ($config.tools.agentToAgent.allow -notcontains $Name) {
        $config.tools.agentToAgent.allow += $Name
    }

    $config | ConvertTo-Json -Depth 20 | Set-Content $configPath -Encoding UTF8
    Write-Host "  Registered in openclaw.json" -ForegroundColor Green
}

# --- Done ---
Write-Host ""
Write-Host "  Ifrit has answered." -ForegroundColor Red
Write-Host ""
Write-Host "  Agent:     $Name" -ForegroundColor White
Write-Host "  Workspace: $workspace" -ForegroundColor DarkGray
Write-Host "  Session:   agent:${Name}:main" -ForegroundColor DarkGray
Write-Host "  Heartbeat: every $Heartbeat, $ActiveStart-$ActiveEnd" -ForegroundColor DarkGray
Write-Host "  Model:     anthropic/$Model" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Restart gateway, then send first orders:" -ForegroundColor Yellow
Write-Host "  sessions_send(sessionKey=`"agent:${Name}:main`", message=`"You're live. Report status.`")" -ForegroundColor DarkGray
Write-Host ""
