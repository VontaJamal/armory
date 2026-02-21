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
- For dispatcher commands, document a welcoming alias and mention mode-sensitive behavior (`mode=saga|civ`) in `Quick Start` and `Migration Notes`.
- State platform compatibility explicitly (cross-platform preferred; platform-specific is acceptable with clear constraints and future-extension notes).
- When output text changes by mode, show both Crystal Saga and Civilian examples.

## Command Examples

- Show PowerShell 5.1 commands for Windows first.
- Use fully-qualified script names when confusion is possible.
- Avoid placeholders without an example value.
- If examples include validation/testing, only reference real executable scripts/functions in this repo.

## Migration Rules

When tools are renamed:

- Keep compatibility wrappers for one release.
- Put the new name first in docs.
- Document old command aliases in `Migration Notes`.
