# Truesight (Deep Security Scan)

## What This Does

Runs a deeper scan than Scan, including expanded pattern checks and optional public-repo-oriented checks.

## Who This Is For

- You want a stronger pre-release security sweep.
- You need broader repository and secret exposure checks.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\weapons\truesight\truesight.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\weapons\truesight\truesight.ps1 -RepoPath "D:\Code Repos"
```

## Common Tasks

```powershell
# Scan only current project
powershell -ExecutionPolicy Bypass -File .\weapons\truesight\truesight.ps1 -RepoPath "."

# Quiet mode with exit code for CI
powershell -ExecutionPolicy Bypass -File .\weapons\truesight\truesight.ps1 -RepoPath "D:\Code Repos" -Quiet
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-RepoPath <path>` | `D:\Code Repos` | Root scan path |
| `-Quiet` | off | Show only findings summary |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Pattern and ignore lists are configurable in script config block.

## Output And Exit Codes

- `0`: no findings.
- `1`: findings detected or critical failure.

## Troubleshooting

- API rate limits on GitHub checks: set `GITHUB_TOKEN` or reduce external checks.
- Very large scans: scope `-RepoPath` to targeted directories.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\weapons\truesight\truesight.ps1 -RepoPath "D:\Code Repos" -Quiet
```

## FAQ

**How is this different from Protect?**
Truesight is manual deep scan. Protect is scheduled automation.

## Migration Notes

- New primary name: `truesight.ps1`
- Legacy alias: `..\scan\deep-scan.ps1` (one release)
