# Masamune (API Key Vault And Swap)

## What This Does

Stores multiple provider API keys by name and swaps active keys without editing config files manually.

## Who This Is For

- You switch between personal/work keys.
- You use multiple providers and want fast safe swaps.

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\weapons\masamune\masamune.ps1
powershell -ExecutionPolicy Bypass -File .\weapons\masamune\masamune.ps1 add anthropic work sk-ant-example
powershell -ExecutionPolicy Bypass -File .\weapons\masamune\masamune.ps1 anthropic work
```

## Common Tasks

```powershell
# List keys
powershell -ExecutionPolicy Bypass -File .\weapons\masamune\masamune.ps1 list

# Remove a key
powershell -ExecutionPolicy Bypass -File .\weapons\masamune\masamune.ps1 remove anthropic work
```

## Flags

Masamune uses positional commands rather than switch flags.

| Command | Description |
|---|---|
| `add <provider> <name> <key>` | Add/update key entry |
| `<provider> <name>` | Activate named key |
| `<provider>` | Auto-activate if only one entry exists |
| `list` | Show masked vault entries |
| `remove <provider> <name>` | Delete entry |
| `-Help` | Print usage (when supported by wrapper) |

## Config

- Vault path: `%USERPROFILE%\.openclaw\secrets\masamune-vault.json`
- OpenClaw config: `%USERPROFILE%\.openclaw\openclaw.json`

## Output And Exit Codes

- `0`: Command handled successfully.
- `1`: Invalid provider/args or config update failure.

## Troubleshooting

- `openclaw.json` missing: initialize OpenClaw first.
- Invalid provider: use `anthropic`, `openai`, `google`, or `k2`.

## Automation Examples

```powershell
# Swap key before service restart script
powershell -ExecutionPolicy Bypass -File .\weapons\masamune\masamune.ps1 anthropic work
```

## FAQ

**Does it print full keys?**
No, key display is masked.

## Migration Notes

No rename for this tool.
