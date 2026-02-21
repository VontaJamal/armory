# Jutsu (macOS zsh Key Swap)

## What This Does

Provides zsh commands for key vault operations and optional gateway restart on macOS.

## Who This Is For

- You run a zsh-based workflow on macOS.
- You want shell-native key swapping.

## Quick Start

```bash
chmod +x ./weapons/jutsu/jutsu.sh
./weapons/jutsu/jutsu.sh help
./weapons/jutsu/jutsu.sh add anthropic work sk-ant-example
```

## Common Tasks

```bash
./weapons/jutsu/jutsu.sh list
./weapons/jutsu/jutsu.sh swap anthropic work
./weapons/jutsu/jutsu.sh reload
```

## Flags

Jutsu uses subcommands.

| Command | Description |
|---|---|
| `setup` | Configure gateway target |
| `add` | Add a named key |
| `list` | List keys |
| `remove` | Remove key |
| `swap` | Activate key + restart gateway |
| `reload` | Restart gateway only |
| `help` | Print usage |

## Config

- `~/.jutsu/vault.json`
- `~/.jutsu/config`

## Output And Exit Codes

- `0`: command succeeded.
- `1`: command failed due to input/config/runtime issue.

## Troubleshooting

- SSH errors: rerun `setup` and verify host/user/key.
- Missing python3: required for JSON mutation helpers.

## Automation Examples

```bash
./weapons/jutsu/jutsu.sh swap anthropic work
```

## FAQ

**Is Jutsu required on Windows?**
No. Use Masamune + Awakening on Windows.

## Migration Notes

No rename for this tool.
