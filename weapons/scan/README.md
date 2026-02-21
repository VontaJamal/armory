# Scan (Fast Security Scan)

## What This Does

Runs a fast manual scan for secret patterns and risky repository hygiene issues.

## Who This Is For

- You want a quick local security pass before commit/push.
- You need immediate visibility into obvious key leaks.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\weapons\scan\scan.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\weapons\scan\scan.ps1 -RepoPath "D:\Code Repos"
```

## Common Tasks

```powershell
# Scan current repo root
powershell -ExecutionPolicy Bypass -File .\weapons\scan\scan.ps1 -RepoPath "."

# Verbose output
powershell -ExecutionPolicy Bypass -File .\weapons\scan\scan.ps1 -RepoPath "D:\Code Repos" -Verbose
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-RepoPath <path>` | `D:\Code Repos` | Root path to scan |
| `-Verbose` | off | Print extra details |
| `-Sound` | off | Enable sound cues |
| `-NoSound` | off | Disable sound cues |
| `-Help` | off | Print usage and exit |

## Config

Patterns are embedded in script and can be extended in code.

## Output And Exit Codes

- `0`: scan completed with no critical findings.
- `1`: findings detected or critical runtime failure.

## Troubleshooting

- Slow scan: narrow `-RepoPath` to a smaller directory.
- False positives: tune regex patterns in script config block.

## Automation Examples

```powershell
powershell -ExecutionPolicy Bypass -File .\weapons\scan\scan.ps1 -RepoPath "D:\Code Repos"
```

## FAQ

**How is this different from Truesight?**
Scan is faster and intended for quick manual checks. Truesight is deeper and broader.

## Migration Notes

- `deep-scan.ps1` is now a wrapper alias to `..\truesight\truesight.ps1`.
