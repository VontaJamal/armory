<#
.SYNOPSIS
  Remedy - one-command Armory environment health check.
#>

param(
    [ValidateSet("config", "wrapper", "scripts", "repos", "ci", "shadow", "remote", "deps")]
    [string[]]$Check,
    [switch]$Detailed,
    [string]$Output,
    [switch]$Help,
    [switch]$Sound,
    [switch]$NoSound
)

$ErrorActionPreference = "Continue"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$hooks = Join-Path $repoRoot "bard\lib\bard-hooks.ps1"
if (Test-Path $hooks) { . $hooks }

$soundContext = $null
if (Get-Command Initialize-ArmorySound -ErrorAction SilentlyContinue) {
    $soundContext = Initialize-ArmorySound -Sound:$Sound -NoSound:$NoSound -RepoRoot $repoRoot
    Invoke-ArmoryCue -Context $soundContext -Type start
}

function Show-HelpText {
    Write-Host ""
    Write-Host "  Remedy" -ForegroundColor Cyan
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Read-only environment checks for Armory setup and tooling health."
    Write-Host ""
    Write-Host "  Usage:"
    Write-Host "    .\items\remedy\remedy.ps1"
    Write-Host "    .\items\remedy\remedy.ps1 -Detailed"
    Write-Host "    .\items\remedy\remedy.ps1 -Check config,wrapper"
    Write-Host "    .\items\remedy\remedy.ps1 -Output \"$env:USERPROFILE\.armory\reports\remedy.txt\""
    Write-Host ""
}

if ($Help) {
    Show-HelpText
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
    exit 0
}

function Expand-ArmoryPath {
    param([string]$PathValue)

    if (-not $PathValue) { return $PathValue }

    $expanded = [Environment]::ExpandEnvironmentVariables($PathValue)
    if ($expanded.StartsWith("~")) {
        $trimmed = $expanded.Substring(1).TrimStart('/', '\\')
        if ($trimmed) {
            return (Join-Path $HOME $trimmed)
        }
        return $HOME
    }

    return $expanded
}

$script:configLoaded = $false
$script:configObject = $null
$script:configError = $null

function Get-ArmoryConfig {
    if ($script:configLoaded) {
        return $script:configObject
    }

    $script:configLoaded = $true
    $configPath = Expand-ArmoryPath -PathValue "~/.armory/config.json"

    if (-not (Test-Path $configPath)) {
        $script:configError = "missing config file: $configPath"
        return $null
    }

    try {
        $raw = Get-Content -Path $configPath -Raw
        $script:configObject = $raw | ConvertFrom-Json
        return $script:configObject
    } catch {
        $script:configError = "config parse failed: $configPath"
        return $null
    }
}

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$CheckName,
        [ValidateSet("PASS", "WARN", "FAIL")]
        [string]$Status,
        [string]$Message,
        [string[]]$Details
    )

    $results.Add([PSCustomObject]@{
        Check = $CheckName
        Status = $Status
        Message = $Message
        Details = @($Details)
    }) | Out-Null
}

$allChecks = @("config", "wrapper", "scripts", "repos", "ci", "shadow", "remote", "deps")
$selectedChecks = if ($Check -and $Check.Count -gt 0) { @($Check | Select-Object -Unique) } else { $allChecks }

foreach ($c in $selectedChecks) {
    switch ($c) {
        "config" {
            $config = Get-ArmoryConfig
            if (-not $config) {
                Add-Result -CheckName "config" -Status "FAIL" -Message "Armory config missing or unreadable" -Details @($script:configError)
                break
            }

            $issues = @()
            if (-not $config.commandWord -or [string]$config.commandWord -notmatch "^[a-zA-Z][a-zA-Z0-9-]{1,20}$") {
                $issues += "invalid or missing commandWord"
            }
            if (-not $config.installDir) {
                $issues += "missing installDir"
            }
            if (-not $config.repoRoot) {
                $issues += "missing repoRoot"
            }
            if (-not ($config.PSObject.Properties.Name -contains "mode")) {
                $issues += "missing mode (expected saga|civ)"
            } else {
                $modeValue = [string]$config.mode
                if ($modeValue -notin @("saga", "civ", "lore", "crystal")) {
                    $issues += "invalid mode (expected saga|civ)"
                }
            }

            if ($issues.Count -gt 0) {
                Add-Result -CheckName "config" -Status "FAIL" -Message "Armory config present but invalid" -Details $issues
            } else {
                Add-Result -CheckName "config" -Status "PASS" -Message "Armory config is valid" -Details @(
                    "commandWord=$($config.commandWord)",
                    "installDir=$($config.installDir)",
                    "repoRoot=$($config.repoRoot)",
                    "mode=$([string]$config.mode)"
                )
            }
        }

        "wrapper" {
            $config = Get-ArmoryConfig
            if (-not $config) {
                Add-Result -CheckName "wrapper" -Status "FAIL" -Message "Cannot validate wrapper without a valid config" -Details @($script:configError)
                break
            }

            $installDir = [string]$config.installDir
            $commandWord = [string]$config.commandWord
            if (-not $installDir -or -not $commandWord) {
                Add-Result -CheckName "wrapper" -Status "FAIL" -Message "Config missing installDir or commandWord" -Details @()
                break
            }

            $wrapperPath = Join-Path $installDir ("{0}.cmd" -f $commandWord)
            if (-not (Test-Path $wrapperPath)) {
                Add-Result -CheckName "wrapper" -Status "FAIL" -Message "Command wrapper not found" -Details @($wrapperPath)
                break
            }

            $pathUser = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($pathUser -and $pathUser -like "*${installDir}*") {
                Add-Result -CheckName "wrapper" -Status "PASS" -Message "Wrapper exists and installDir is on user PATH" -Details @($wrapperPath)
            } else {
                Add-Result -CheckName "wrapper" -Status "WARN" -Message "Wrapper exists but installDir not detected on user PATH" -Details @($wrapperPath)
            }
        }

        "scripts" {
            $required = @(
                "awakening.ps1",
                "setup.ps1",
                "rename-command-word.ps1",
                "weapons/scan/scan.ps1",
                "weapons/truesight/truesight.ps1",
                "spells/cure/cure.ps1",
                "spells/chronicle/chronicle.ps1",
                "bard/bard.ps1",
                "items/remedy/remedy.ps1",
                "items/quartermaster/quartermaster.ps1"
            )

            $missing = @()
            foreach ($rel in $required) {
                $full = Join-Path $repoRoot $rel
                if (-not (Test-Path $full)) {
                    $missing += $rel
                }
            }

            if ($missing.Count -gt 0) {
                Add-Result -CheckName "scripts" -Status "FAIL" -Message "Critical scripts missing" -Details $missing
            } else {
                Add-Result -CheckName "scripts" -Status "PASS" -Message "Critical scripts are present" -Details @("count=$($required.Count)")
            }
        }

        "repos" {
            $reposFile = Expand-ArmoryPath -PathValue "~/.armory/repos.json"
            if (-not (Test-Path $reposFile)) {
                Add-Result -CheckName "repos" -Status "FAIL" -Message "Repos allowlist missing" -Details @($reposFile)
                break
            }

            try {
                $raw = Get-Content -Path $reposFile -Raw
                $obj = $raw | ConvertFrom-Json
            } catch {
                Add-Result -CheckName "repos" -Status "FAIL" -Message "Repos allowlist parse failed" -Details @($reposFile)
                break
            }

            if (-not ($obj.PSObject.Properties.Name -contains "repos")) {
                Add-Result -CheckName "repos" -Status "FAIL" -Message "repos[] key missing in allowlist" -Details @($reposFile)
                break
            }

            $repos = @($obj.repos)
            if ($repos.Count -eq 0) {
                Add-Result -CheckName "repos" -Status "WARN" -Message "Repos allowlist is valid but empty" -Details @($reposFile)
                break
            }

            $badTypes = @($repos | Where-Object { $_ -isnot [string] -or -not $_ })
            if ($badTypes.Count -gt 0) {
                Add-Result -CheckName "repos" -Status "FAIL" -Message "Repos allowlist has invalid entries" -Details @("entries must be non-empty strings")
            } else {
                Add-Result -CheckName "repos" -Status "PASS" -Message "Repos allowlist is present and parseable" -Details @("file=$reposFile", "count=$($repos.Count)")
            }
        }

        "ci" {
            $requiredCiFiles = @(
                "scripts/ci/help-smoke.ps1",
                "scripts/ci/run-fixture-tests.ps1",
                "scripts/ci/run-chronicle-tests.ps1",
                "scripts/ci/quartermaster-smoke.ps1",
                "scripts/ci/check_remote_url.ps1",
                "scripts/ci/secret_hygiene.py",
                "scripts/validate_shop_catalog.py",
                "scripts/build_armory_manifest.py",
                "scripts/ci/check_manifest_determinism.py",
                "scripts/release/validate_release.py"
            )

            $missingCi = @()
            foreach ($rel in $requiredCiFiles) {
                if (-not (Test-Path (Join-Path $repoRoot $rel))) {
                    $missingCi += $rel
                }
            }

            if ($missingCi.Count -gt 0) {
                Add-Result -CheckName "ci" -Status "FAIL" -Message "CI helper files missing" -Details $missingCi
            } else {
                Add-Result -CheckName "ci" -Status "PASS" -Message "CI helper files are present" -Details @("count=$($requiredCiFiles.Count)")
            }
        }

        "shadow" {
            $shadowPath = Join-Path $repoRoot "governance\seven-shadow-system"
            if (Test-Path $shadowPath) {
                Add-Result -CheckName "shadow" -Status "PASS" -Message "Seven Shadow System repository detected" -Details @(
                    "path=$shadowPath",
                    "Run real checks from Seven Shadow before release sign-off"
                )
            } else {
                Add-Result -CheckName "shadow" -Status "WARN" -Message "Seven Shadow System not found in expected path" -Details @(
                    "expected=$shadowPath"
                )
            }
        }

        "remote" {
            $gitCmd = Get-Command git -ErrorAction SilentlyContinue
            if (-not $gitCmd) {
                Add-Result -CheckName "remote" -Status "WARN" -Message "git not installed; remote credential check skipped" -Details @()
                break
            }

            $credentialPattern = 'https?://[^/@\s]+:[^@\s]+@[^\s]+'
            $remoteLines = @(git remote -v 2>$null)

            if ($LASTEXITCODE -ne 0 -or $remoteLines.Count -eq 0) {
                Add-Result -CheckName "remote" -Status "WARN" -Message "No git remotes found to inspect" -Details @()
                break
            }

            $hits = @()
            foreach ($line in $remoteLines) {
                if ($line -match $credentialPattern) {
                    $hits += ($line -replace '://([^:@\s]+):[^@\s]+@', '://$1:***@')
                }
            }

            if ($hits.Count -gt 0) {
                Add-Result -CheckName "remote" -Status "FAIL" -Message "Credentialed remote URL detected" -Details ($hits | Select-Object -Unique)
            } else {
                Add-Result -CheckName "remote" -Status "PASS" -Message "Remote URLs do not expose embedded credentials" -Details @()
            }
        }

        "deps" {
            $details = @()
            $missing = @()

            $git = Get-Command git -ErrorAction SilentlyContinue
            if ($git) {
                $details += "git=present"
            } else {
                $missing += "git"
                $details += "git=missing"
            }

            $shell = Get-Command powershell -ErrorAction SilentlyContinue
            if (-not $shell) { $shell = Get-Command pwsh -ErrorAction SilentlyContinue }
            if ($shell) {
                $details += "powershell=present"
            } else {
                $missing += "powershell/pwsh"
                $details += "powershell=missing"
            }

            $sevenZipPaths = @(
                "C:\Program Files\7-Zip\7z.exe",
                "C:\Program Files (x86)\7-Zip\7z.exe"
            )
            $sevenZipCmd = Get-Command 7z -ErrorAction SilentlyContinue
            if (-not $sevenZipCmd) { $sevenZipCmd = Get-Command 7za -ErrorAction SilentlyContinue }
            $sevenZipFile = $sevenZipPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($sevenZipCmd -or $sevenZipFile) {
                $details += "7zip=present"
            } else {
                $missing += "7zip"
                $details += "7zip=missing"
            }

            if ($missing.Count -gt 0) {
                Add-Result -CheckName "deps" -Status "WARN" -Message ("Optional dependencies missing: " + ($missing -join ", ")) -Details $details
            } else {
                Add-Result -CheckName "deps" -Status "PASS" -Message "Optional dependencies are available" -Details $details
            }
        }
    }
}

$failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = @($results | Where-Object { $_.Status -eq "WARN" }).Count
$passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count

$hostName = if ($env:COMPUTERNAME) {
    $env:COMPUTERNAME
} elseif ($env:HOSTNAME) {
    $env:HOSTNAME
} else {
    [System.Net.Dns]::GetHostName()
}

$summaryLines = @()
$summaryLines += "Remedy Environment Check"
$summaryLines += "------------------------"
$summaryLines += "Timestamp: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$summaryLines += "Host: $hostName"
$summaryLines += ""
$summaryLines += (($results | Select-Object Check, Status, Message | Format-Table -AutoSize | Out-String).TrimEnd())
$summaryLines += ""
$summaryLines += "Summary: PASS=$passCount WARN=$warnCount FAIL=$failCount"

if ($Detailed) {
    $payload = [ordered]@{
        generatedAt = (Get-Date).ToString("o")
        host = $hostName
        counts = [ordered]@{
            pass = $passCount
            warn = $warnCount
            fail = $failCount
        }
        results = @($results)
    }
    $summaryLines += ""
    $summaryLines += "Detailed JSON"
    $summaryLines += "-------------"
    $summaryLines += ($payload | ConvertTo-Json -Depth 8)
}

$finalText = $summaryLines -join "`r`n"

if ($Output) {
    $outPath = Expand-ArmoryPath -PathValue $Output
    $outDir = Split-Path $outPath -Parent
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -Path $outPath -Value $finalText -Encoding UTF8
    Write-Host "Remedy report written: $outPath" -ForegroundColor Green
} else {
    Write-Output $finalText
}

if ($failCount -gt 0) {
    if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type fail }
    exit 1
}

if ($soundContext) { Invoke-ArmoryCue -Context $soundContext -Type success }
exit 0
