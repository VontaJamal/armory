# Chronicle (Cross-Repo Git Intel)

## What This Does

Shows read-only git health and recent commit activity across multiple repositories.

## Who This Is For

- Developers managing several repos at once.
- Operators who need a quick branch/dirty/ahead-behind snapshot.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\spells\chronicle\chronicle.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\spells\chronicle\chronicle.ps1
```

## Common Tasks

```powershell
# Use allowlist file (~/.armory/repos.json by default)
powershell -ExecutionPolicy Bypass -File .\spells\chronicle\chronicle.ps1

# Scan explicit repo paths
powershell -ExecutionPolicy Bypass -File .\spells\chronicle\chronicle.ps1 -RepoPath "D:\Code Repos\faye","D:\Code Repos\shadow-gate"

# Export JSON for automation
powershell -ExecutionPolicy Bypass -File .\spells\chronicle\chronicle.ps1 -Format json -Output "D:\Reports\chronicle.json"

# Add commit details
powershell -ExecutionPolicy Bypass -File .\spells\chronicle\chronicle.ps1 -Detailed
```

## Flags

| Flag | Default | Description |
|---|---|---|
| `-ReposFile <path>` | `~/.armory/repos.json` | Allowlist file path |
| `-RepoPath <path[]>` | none | Explicit repo paths override allowlist |
| `-Format table\|json\|markdown` | `table` | Output format |
| `-Detailed` | off | Include per-repo commit details |
| `-Output <path>` | none | Write output to file |
| `-Sound` | off | Enable optional sound cues |
| `-NoSound` | off | Disable optional sound cues |
| `-Help` | off | Print usage and exit |

## Config

Allowlist config file format:

```json
{
  "repos": [
    "D:/Code Repos/faye",
    "D:/Code Repos/armory"
  ]
}
```

If the file is missing and `-RepoPath` is not provided, Chronicle creates a starter file and exits cleanly.

## Output And Exit Codes

- `0`: command completed, including empty allowlist guidance cases.
- `1`: invalid config parse or fatal runtime failure.

## Troubleshooting

- "No repositories configured": add paths to `repos[]` in your allowlist file.
- "not-git" state: path exists but has no `.git` directory.
- Missing paths are shown as `state=missing` and do not crash the run.

## Automation Examples

```powershell
# JSON output for cron/scheduled jobs
powershell -ExecutionPolicy Bypass -File .\spells\chronicle\chronicle.ps1 -Format json -Output "$env:USERPROFILE\.armory\reports\chronicle.json"

# Markdown summary for chatops posting
powershell -ExecutionPolicy Bypass -File .\spells\chronicle\chronicle.ps1 -Format markdown -Detailed
```

## FAQ

**Does Chronicle edit repositories?**
No. Chronicle is read-only.

**Does Chronicle require GitHub API access?**
No. It uses local git data only.

## Migration Notes

- New in this release as the primary cross-repo intelligence tool.
- Dispatcher exposes both `chronicle` and plain alias `status`.
