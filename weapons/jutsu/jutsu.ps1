param(
    [Parameter(Position=0)][string]$Action,
    [Parameter(Position=1)][string]$Arg1,
    [Parameter(Position=2)][string]$Arg2,
    [Parameter(Position=3)][string]$Arg3
)

$ErrorActionPreference = "Stop"
$configPath = "$env:USERPROFILE\.openclaw\openclaw.json"
$vaultPath = "$env:USERPROFILE\.openclaw\secrets\jutsu-vault.json"

$providerDefs = @{
    "anthropic" = @{
        envVar = "ANTHROPIC_API_KEY"; baseUrl = "https://api.anthropic.com"; api = "anthropic-messages"
        models = @(
            @{ id="claude-opus-4-6"; name="Claude Opus 4.6"; reasoning=$true; maxTokens=32000 },
            @{ id="claude-sonnet-4-20250514"; name="Claude Sonnet 4"; reasoning=$true; maxTokens=16000 },
            @{ id="claude-haiku-4-5-20251001"; name="Claude Haiku 4.5"; reasoning=$false; maxTokens=8192 }
        )
        defaultModel = "anthropic/claude-opus-4-6"; profileKey = "anthropic:default"
    }
    "openai" = @{
        envVar = "OPENAI_API_KEY"; baseUrl = "https://api.openai.com/v1"; api = "openai-chat"
        models = @(
            @{ id="gpt-4o"; name="GPT-4o"; reasoning=$false; maxTokens=16384 },
            @{ id="o3-mini"; name="o3-mini"; reasoning=$true; maxTokens=16384 }
        )
        defaultModel = "openai/gpt-4o"; profileKey = "openai:default"
    }
    "google" = @{
        envVar = "GOOGLE_API_KEY"; baseUrl = "https://generativelanguage.googleapis.com/v1beta"; api = "google-gemini"
        models = @(
            @{ id="gemini-2.0-flash"; name="Gemini 2.0 Flash"; reasoning=$false; maxTokens=8192 },
            @{ id="gemini-2.5-pro-preview-06-05"; name="Gemini 2.5 Pro"; reasoning=$true; maxTokens=16384 }
        )
        defaultModel = "google/gemini-2.0-flash"; profileKey = "google:default"
    }
    "k2" = @{
        envVar = "TOGETHER_API_KEY"; baseUrl = "https://api.together.xyz/v1"; api = "openai-chat"
        models = @(
            @{ id="k2-chat"; name="K2 Chat"; reasoning=$false; maxTokens=8192 }
        )
        defaultModel = "k2/k2-chat"; profileKey = "k2:default"
    }
}

function Load-Vault {
    if (Test-Path $vaultPath) { return (Get-Content $vaultPath -Raw | ConvertFrom-Json) }
    return [PSCustomObject]@{}
}

function Save-Vault($vault) {
    $dir = Split-Path $vaultPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $vault | ConvertTo-Json -Depth 10 | Set-Content $vaultPath -Encoding UTF8
}

function Mask-Key($key) {
    if ($key.Length -le 8) { return "***" }
    return $key.Substring(0,6) + "....." + $key.Substring($key.Length - 3)
}

function Apply-Swap($provider, $apiKey) {
    $prov = $providerDefs[$provider]
    [System.Environment]::SetEnvironmentVariable($prov.envVar, $apiKey, "User")
    Set-Item "env:$($prov.envVar)" $apiKey

    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    if (-not $config.auth.profiles.PSObject.Properties[$prov.profileKey]) {
        $config.auth.profiles | Add-Member -NotePropertyName $prov.profileKey -NotePropertyValue ([PSCustomObject]@{
            provider = $provider; mode = "token"
        })
    }

    $modelList = @()
    foreach ($m in $prov.models) {
        $modelList += [PSCustomObject]@{
            id = $m.id; name = $m.name; reasoning = $m.reasoning
            input = @("text","image")
            cost = @{ input=0; output=0; cacheRead=0; cacheWrite=0 }
            contextWindow = 200000; maxTokens = $m.maxTokens
        }
    }
    $provObj = [PSCustomObject]@{ baseUrl = $prov.baseUrl; api = $prov.api; models = $modelList }

    if ($config.models.providers.PSObject.Properties[$provider]) {
        $config.models.providers.$provider = $provObj
    } else {
        $config.models.providers | Add-Member -NotePropertyName $provider -NotePropertyValue $provObj
    }

    $config.agents.defaults.model.primary = $prov.defaultModel
    $config | ConvertTo-Json -Depth 20 | Set-Content $configPath -Encoding UTF8
}

# --- No args: show help ---
if (-not $Action) {
    Write-Host ""
    Write-Host "  armory jutsu" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  add [provider] [name] [key]   Register a key to the scroll"
    Write-Host "  [provider] [name]             Swap to a named key"
    Write-Host "  list                          Show the jutsu scroll"
    Write-Host "  remove [provider] [name]      Remove a key"
    Write-Host ""
    Write-Host "  Providers: anthropic, openai, google, k2" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# --- ADD ---
if ($Action -eq "add") {
    $provider = $Arg1.ToLower()
    $name = $Arg2
    $apiKey = $Arg3

    if (-not $provider -or -not $name -or -not $apiKey) {
        Write-Host "  Usage: armory jutsu add [provider] [name] [api-key]" -ForegroundColor Red
        exit 1
    }
    if (-not $providerDefs.ContainsKey($provider)) {
        Write-Host "  Unknown provider: $provider" -ForegroundColor Red
        exit 1
    }

    $vault = Load-Vault
    if (-not $vault.PSObject.Properties[$provider]) {
        $vault | Add-Member -NotePropertyName $provider -NotePropertyValue ([PSCustomObject]@{})
    }
    if ($vault.$provider.PSObject.Properties[$name]) {
        $vault.$provider.$name = $apiKey
    } else {
        $vault.$provider | Add-Member -NotePropertyName $name -NotePropertyValue $apiKey
    }
    Save-Vault $vault

    Write-Host ""
    Write-Host "  Sealed. $provider/$name registered to the scroll." -ForegroundColor Magenta
    Write-Host "  $(Mask-Key $apiKey)" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# --- LIST ---
if ($Action -eq "list") {
    $vault = Load-Vault
    $activeKeys = @{}
    foreach ($p in $providerDefs.Keys) {
        $envVal = [System.Environment]::GetEnvironmentVariable($providerDefs[$p].envVar, "User")
        if ($envVal) { $activeKeys[$p] = $envVal }
    }

    Write-Host ""
    Write-Host "  Jutsu Scroll" -ForegroundColor Magenta
    Write-Host ""

    $hasEntries = $false
    foreach ($p in $vault.PSObject.Properties) {
        Write-Host "  $($p.Name)" -ForegroundColor Cyan
        foreach ($k in $p.Value.PSObject.Properties) {
            $hasEntries = $true
            $masked = Mask-Key $k.Value
            $isActive = ($activeKeys.ContainsKey($p.Name) -and $k.Value -eq $activeKeys[$p.Name])
            if ($isActive) {
                Write-Host "    $($k.Name.PadRight(16)) $masked <- active" -ForegroundColor Green
            } else {
                Write-Host "    $($k.Name.PadRight(16)) $masked" -ForegroundColor DarkGray
            }
        }
        Write-Host ""
    }
    if (-not $hasEntries) {
        Write-Host "  (empty -- use 'armory jutsu add' to register keys)" -ForegroundColor DarkGray
        Write-Host ""
    }
    exit 0
}

# --- REMOVE ---
if ($Action -eq "remove") {
    $provider = $Arg1.ToLower()
    $name = $Arg2
    if (-not $provider -or -not $name) {
        Write-Host "  Usage: armory jutsu remove [provider] [name]" -ForegroundColor Red
        exit 1
    }

    $vault = Load-Vault
    if ($vault.PSObject.Properties[$provider] -and $vault.$provider.PSObject.Properties[$name]) {
        $vault.$provider.PSObject.Properties.Remove($name)
        Save-Vault $vault
        Write-Host ""
        Write-Host "  Released. $provider/$name removed from the scroll." -ForegroundColor Magenta
        Write-Host ""
    } else {
        Write-Host "  Not found: $provider/$name" -ForegroundColor Red
    }
    exit 0
}

# --- SWAP: armory jutsu [provider] [name] ---
$provider = $Action.ToLower()
$name = $Arg1

if (-not $providerDefs.ContainsKey($provider)) {
    Write-Host "  Unknown command or provider: $Action" -ForegroundColor Red
    exit 1
}

if (-not $name) {
    $vault = Load-Vault
    if ($vault.PSObject.Properties[$provider]) {
        $keys = @($vault.$provider.PSObject.Properties)
        if ($keys.Count -eq 1) {
            $name = $keys[0].Name
        } else {
            Write-Host "  Multiple keys for $provider. Specify which:" -ForegroundColor Yellow
            foreach ($k in $keys) {
                Write-Host "    armory jutsu $provider $($k.Name)" -ForegroundColor DarkGray
            }
            exit 1
        }
    } else {
        Write-Host "  No keys registered for $provider." -ForegroundColor Red
        Write-Host "    armory jutsu add $provider [name] [api-key]" -ForegroundColor DarkGray
        exit 1
    }
}

$vault = Load-Vault
if (-not $vault.PSObject.Properties[$provider] -or -not $vault.$provider.PSObject.Properties[$name]) {
    Write-Host "  Key not found: $provider/$name" -ForegroundColor Red
    Write-Host "    armory jutsu add $provider $name [api-key]" -ForegroundColor DarkGray
    exit 1
}

$apiKey = $vault.$provider.$name
Apply-Swap $provider $apiKey

Write-Host ""
Write-Host "  Jutsu activated. Chakra nature: $provider ($name)" -ForegroundColor Magenta
Write-Host "  Model: $($providerDefs[$provider].defaultModel)" -ForegroundColor DarkGray
Write-Host "  Restart gateway to take effect." -ForegroundColor Yellow
Write-Host ""

