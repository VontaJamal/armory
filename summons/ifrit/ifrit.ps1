<#
.SYNOPSIS
  Ifrit - create and register a specialist OpenClaw agent.
#>

param(
    [string]$Name,
    [string]$Role,
    [string]$Model = "claude-sonnet-4-20250514",
    [string]$Heartbeat = "55m",
    [string]$ActiveStart = "08:00",
    [string]$ActiveEnd = "23:00",
    [switch]$NoTelegram,
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Stop"
$ocBase = "$env:USERPROFILE\.openclaw"
$configPath = "$ocBase\openclaw.json"

$hookCandidates = @(
    (Join-Path $PSScriptRoot "..\..\bard\lib\bard-hooks.ps1"),
    (Join-Path $PSScriptRoot "..\bard\lib\bard-hooks.ps1")
)
foreach ($h in $hookCandidates) {
    if (Test-Path $h) { . $h; break }
}
$soundContext = $null
if (Get-Command Initialize-ArmorySound -ErrorAction SilentlyContinue) {
    $soundContext = Initialize-ArmorySound -Sound:$Sound -NoSound:$NoSound
    Invoke-ArmoryCue -Context $soundContext -Type start
}

function Show-Help {
    Write-Host ""
    Write-Host "  Ifrit" -ForegroundColor Red
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\\ifrit.ps1 -Name cipher -Role \"Security analyst\""
    Write-Host "    .\\ifrit.ps1 -Name ops -Role \"Platform ops\" -Heartbeat 30m"
    Write-Host ""
}

if ($Help -or -not $Name -or -not $Role) {
    Show-Help
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

if (-not (Test-Path $configPath)) {
    Write-Host "  missing config: $configPath" -ForegroundColor Red
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

$Name = $Name.ToLower()
$workspace = "$ocBase\workspace-$Name"
$agentDir = "$ocBase\agents\$Name\agent"

New-Item -ItemType Directory -Path $workspace -Force | Out-Null
New-Item -ItemType Directory -Path "$workspace\memory" -Force | Out-Null
New-Item -ItemType Directory -Path $agentDir -Force | Out-Null

@"
# SOUL.md - Who You Are

## Name: $($Name.Substring(0,1).ToUpper() + $Name.Substring(1))
## Role: $Role

You are a specialist agent.

## Core Directives
- Execute your domain with precision
- Report results, not problems
- Verify before claiming success
- Keep responses concise
"@ | Set-Content "$workspace\SOUL.md" -Encoding UTF8

@"
# AGENTS.md

## Every Session
1. Read SOUL.md
2. Read memory notes
3. Check pending tasks

## Safety
- Do not exfiltrate data
- Do not run destructive commands without approval
"@ | Set-Content "$workspace\AGENTS.md" -Encoding UTF8

@"
# MEMORY.md

## Created
$(Get-Date -Format "yyyy-MM-dd")

## Role
$Role
"@ | Set-Content "$workspace\MEMORY.md" -Encoding UTF8

@"
# IDENTITY.md
- Name: $($Name.Substring(0,1).ToUpper() + $Name.Substring(1))
- Role: $Role
- Created: $(Get-Date -Format "yyyy-MM-dd")
"@ | Set-Content "$workspace\IDENTITY.md" -Encoding UTF8

"# TOOLS.md`n`nAdd tool-specific notes here.`n" | Set-Content "$workspace\TOOLS.md" -Encoding UTF8

$configText = [System.IO.File]::ReadAllText($configPath)
$config = $configText | ConvertFrom-Json
$existing = $config.agents.list | Where-Object { $_.id -eq $Name }

if (-not $existing) {
    $agentEntry = [PSCustomObject]@{
        id = $Name
        name = $Name.Substring(0,1).ToUpper() + $Name.Substring(1)
        workspace = $workspace
        agentDir = $agentDir
        model = @{ primary = "anthropic/$Model" }
        heartbeat = @{
            every = $Heartbeat
            activeHours = @{ start = $ActiveStart; end = $ActiveEnd; timezone = "America/New_York" }
            model = "anthropic/claude-haiku-4-5-20251001"
        }
        identity = @{ name = $Name.Substring(0,1).ToUpper() + $Name.Substring(1) }
    }
    $config.agents.list += $agentEntry

    if ($config.tools.agentToAgent.allow -notcontains $Name) {
        $config.tools.agentToAgent.allow += $Name
    }

    $config | ConvertTo-Json -Depth 20 | Set-Content $configPath -Encoding UTF8
}

Write-Host ""
Write-Host "  ifrit complete" -ForegroundColor Green
Write-Host "  Agent:     $Name" -ForegroundColor White
Write-Host "  Workspace: $workspace" -ForegroundColor DarkGray
Write-Host "  Session:   agent:${Name}:main" -ForegroundColor DarkGray
Write-Host "  Heartbeat: every $Heartbeat, $ActiveStart-$ActiveEnd" -ForegroundColor DarkGray
Write-Host "  Model:     anthropic/$Model" -ForegroundColor DarkGray
if (-not $NoTelegram) {
    Write-Host "  First message template:" -ForegroundColor Yellow
    Write-Host "    sessions_send(sessionKey=\"agent:${Name}:main\", message=\"You are live. Report status.\")" -ForegroundColor DarkGray
}
Write-Host ""

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
