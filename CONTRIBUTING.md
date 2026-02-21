# Contributing To The Armory

Thanks for helping grow the Armory.

The Armory is Final Fantasy-themed, but every addition must solve a real operational problem for regular users.

## Start Here

1. Read [`README.md`](README.md) for tool selection and command paths.
2. Read [`DOCS-CONTRACT.md`](DOCS-CONTRACT.md) for required README section structure.
3. Read [`shop/ADD-TO-SHOP.md`](shop/ADD-TO-SHOP.md) for full-tool and idea-only submission rules.
4. Read [`POLICIES/DEPRECATION.md`](POLICIES/DEPRECATION.md) for rename and alias lifecycle.
5. Read [`POLICIES/RELEASE.md`](POLICIES/RELEASE.md) for release gates.
6. Read [`POLICIES/BRANCH-PROTECTION.md`](POLICIES/BRANCH-PROTECTION.md) for required status checks.

## Two Contribution Paths

## Path A: Full Tool Submission

Use this when you are shipping script + docs in the same change.

Checklist:

1. Pick a unique Final Fantasy-themed name.
2. Put files in the right category folder (`summons/`, `weapons/`, `spells/`, `items/`, or `bard/`).
3. Add README sections in docs-contract order.
4. Ensure script has `-Help` and clear exit code behavior.
5. Define at least one welcoming "Civilian alias" for dispatcher usage when applicable.
6. Add `shop/catalog.json` entry with `status: "active"` and valid `scriptPath`/`readmePath`.
7. Include schema v2 metadata fields: `display`, `install`, and `tags`.

## Path B: Idea-Only Submission

Use this when the concept is useful but implementation is not ready.

Checklist:

1. Add `class: "idea"` and `status: "idea"` in `shop/catalog.json`.
2. Keep `scriptPath` and `readmePath` as `null`.
3. Keep `install.entrypointPath` as `null` and `install.bundlePaths` empty.
4. Write both `display.saga.description` and `display.civ.description`.
5. Add a short listing note in `shop/SHOP.md`.

## Use Materia Forge (Recommended)

`materia-forge.ps1` can scaffold full tools or idea-only entries.

```powershell
# Interactive mode
powershell -ExecutionPolicy Bypass -File .\materia-forge.ps1

# Non-interactive full tool scaffold
powershell -ExecutionPolicy Bypass -File .\materia-forge.ps1 -Category spell -Name "Astra Watch" -Description "Checks endpoint health"

# Non-interactive idea-only entry
powershell -ExecutionPolicy Bypass -File .\materia-forge.ps1 -Category idea -Name "Mognet" -Description "Unified notification relay" -FlavorLine "A reliable message network for operational updates."
```

## Required Validation Before PR

Run these checks from repo root:

```bash
python3 scripts/ci/validate_readmes.py
python3 scripts/validate_shop_catalog.py
python3 scripts/build_armory_manifest.py
python3 scripts/ci/check_manifest_determinism.py
python3 scripts/ci/secret_hygiene.py
python3 scripts/release/validate_release.py --mode ci
```

```powershell
pwsh -File .\scripts\ci\check_remote_url.ps1
pwsh -File .\scripts\ci\help-smoke.ps1
pwsh -File .\scripts\ci\run-fixture-tests.ps1 -SevenZipPath "C:\Program Files\7-Zip\7z.exe"
pwsh -File .\scripts\ci\run-chronicle-tests.ps1
pwsh -File .\items\remedy\remedy.ps1 -Detailed
pwsh -File .\summons\alexander\alexander.ps1
```

If your environment does not have PowerShell or 7-Zip, call that out in your PR validation notes.

## Remedy Command (Recommended Preflight)

Use `items/remedy/remedy.ps1` (dispatcher aliases: `remedy`, `esuna`) when you want a single read-only environment health report before shipping changes.
`doctor.ps1` is still available as a deprecated compatibility alias for two releases.

```powershell
pwsh -File .\items\remedy\remedy.ps1
pwsh -File .\items\remedy\remedy.ps1 -Check config,wrapper
pwsh -File .\items\remedy\remedy.ps1 -Detailed -Output "$env:USERPROFILE\.armory\reports\remedy.txt"
pwsh -File .\doctor.ps1 -Check scripts,ci
```

## Crystal Saga / Civilian Mode

Use `civs.ps1` (dispatcher route: `civs`) to control the shared mode flag (`mode=saga|civ`).

```powershell
pwsh -File .\civs.ps1 status
pwsh -File .\civs.ps1 off
pwsh -File .\civs.ps1 on
```

- `civs off` => Crystal Saga Mode (`mode=saga`)
- `civs on` => Civilian Mode (`mode=civ`)

## README Maintenance Rules

Armory has one root selector README plus two companion guides:

- `README.md` (path selector hub)
- `README-SAGA.md` (Crystal Saga voice)
- `README-CIV.md` (Civilian voice)

When setup, workflow, or command behavior changes:

1. Update both companion guides in the same PR.
2. Keep command semantics in parity across both guides.
3. Keep tone contract consistent with `mode=saga|civ`.
4. Crystal Saga guide can use light flavor, but instructions stay technically clear.
5. Civilian guide must remain plain and operational.
6. Keep root README links to both guides plus dashboard deep links (`?mode=saga`, `?mode=civ`).
7. Run `python3 scripts/ci/validate_readmes.py` before opening the PR.

## Quality Rules

1. Cross-platform support is preferred (`powershell` on Windows, `pwsh` on macOS), but platform-specific tools are allowed when clearly documented and built for future extension.
2. `-Help` and no-arg usage paths must not crash.
3. Docs must be copy-paste friendly for non-experts.
4. New links must resolve in-repo.
5. Rename migrations must follow the two-release policy in [`POLICIES/DEPRECATION.md`](POLICIES/DEPRECATION.md).
6. Release tags must follow semver format `vMAJOR.MINOR.PATCH`.
7. Release gating checks are mandatory and defined in [`POLICIES/RELEASE.md`](POLICIES/RELEASE.md).
8. User-facing commands should include a welcoming Civilian alias for maximum symbiosis.
9. Tests must validate real executable behavior only; do not add fabricated helper APIs.
10. If `governance/seven-shadow-system` exists, include its real check output in PR validation notes.

## PR Template Notes

Include this in PR body:

1. Problem solved.
2. Full tool vs idea-only.
3. Files changed.
4. Validation commands run and outcomes.
