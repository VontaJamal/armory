# Contributing To The Armory

Thanks for helping grow the Armory.

The Armory is Final Fantasy-themed, but every addition must solve a real operational problem for regular users.

## Start Here

1. Read [`README.md`](README.md) for tool selection and command paths.
2. Read [`DOCS-CONTRACT.md`](DOCS-CONTRACT.md) for required README section structure.
3. Read [`shop/ADD-TO-SHOP.md`](shop/ADD-TO-SHOP.md) for full-tool and idea-only submission rules.
4. Read [`POLICIES/DEPRECATION.md`](POLICIES/DEPRECATION.md) for rename and alias lifecycle.

## Two Contribution Paths

## Path A: Full Tool Submission

Use this when you are shipping script + docs in the same change.

Checklist:

1. Pick a unique Final Fantasy-themed name.
2. Put files in the right category folder (`summons/`, `weapons/`, `spells/`, `items/`, or `bard/`).
3. Add README sections in docs-contract order.
4. Ensure script has `-Help` and clear exit code behavior.
5. Add `shop/catalog.json` entry with `status: "active"` and valid `scriptPath`/`readmePath`.

## Path B: Idea-Only Submission

Use this when the concept is useful but implementation is not ready.

Checklist:

1. Add `class: "idea"` and `status: "idea"` in `shop/catalog.json`.
2. Keep `scriptPath` and `readmePath` as `null`.
3. Write a plain-language `plainDescription`.
4. Add a short listing note in `shop/SHOP.md`.

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
python3 scripts/validate_shop_catalog.py
```

```powershell
pwsh -File .\scripts\ci\help-smoke.ps1
pwsh -File .\scripts\ci\run-fixture-tests.ps1 -SevenZipPath "C:\Program Files\7-Zip\7z.exe"
```

If your environment does not have PowerShell or 7-Zip, call that out in your PR validation notes.

## Quality Rules

1. Runtime target is Windows PowerShell 5.1 unless explicitly documented otherwise.
2. `-Help` and no-arg usage paths must not crash.
3. Docs must be copy-paste friendly for non-experts.
4. New links must resolve in-repo.
5. Rename migrations must follow the two-release policy in [`POLICIES/DEPRECATION.md`](POLICIES/DEPRECATION.md).

## PR Template Notes

Include this in PR body:

1. Problem solved.
2. Full tool vs idea-only.
3. Files changed.
4. Validation commands run and outcomes.
