# Sentinel (Legacy Alias For Aegis)

## What This Does

Compatibility wrapper documentation for teams still calling `sentinel.ps1`.

## Who This Is For

- You have existing scripts or schedulers using Sentinel name.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\weapons\sentinel\sentinel.ps1 -Help
```

## Common Tasks

Use Aegis directly for new setups:

```powershell
powershell -ExecutionPolicy Bypass -File .\weapons\aegis\aegis.ps1
```

## Flags

Sentinel forwards all flags to Aegis.

## Config

Use Aegis config in `weapons/aegis/aegis.ps1`.

## Output And Exit Codes

Matches Aegis behavior.

## Troubleshooting

If wrapper cannot locate Aegis, pull latest repo and verify `weapons/aegis/aegis.ps1` exists.

## Automation Examples

Prefer migrating scheduler targets to Aegis path.

## FAQ

**Is Sentinel removed?**
Not yet. It remains as a one-release alias.

## Migration Notes

- Primary tool is now Aegis.
