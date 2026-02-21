# Armory Documentation Contract

Use this contract for every tool README in the Armory.

## Goals

- Be usable by regular developers, not only power users.
- Keep flavor names, but always explain plain purpose first.
- Make commands copy-paste ready.
- Make failure handling explicit.

## Required Section Order

1. `What This Does`
2. `Who This Is For`
3. `Quick Start`
4. `Common Tasks`
5. `Flags`
6. `Config`
7. `Output And Exit Codes`
8. `Troubleshooting`
9. `Automation Examples`
10. `FAQ`
11. `Migration Notes`

## Writing Rules

- Open with one sentence in plain language.
- Include at least one minimal working example.
- Include at least one production-style example.
- List defaults for all flags and config keys.
- State exactly what `0` and `1` mean for exit codes.
- Include one "if this fails" section with concrete fixes.
- Keep themed words in headings or flavor lines, not in core instructions.
- For dispatcher commands, document a welcoming "Civilian alias" in `Quick Start` and `Migration Notes`.

## Command Examples

- Show PowerShell 5.1 commands for Windows first.
- Use fully-qualified script names when confusion is possible.
- Avoid placeholders without an example value.

## Migration Rules

When tools are renamed:

- Keep compatibility wrappers for one release.
- Put the new name first in docs.
- Document old command aliases in `Migration Notes`.
