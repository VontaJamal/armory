# Add To Shop

This guide covers both implemented tools and idea-only submissions.

For rename/deprecation behavior, follow [`../POLICIES/DEPRECATION.md`](../POLICIES/DEPRECATION.md).

## Fast Path: Idea-Only Entry

Use this when you have a useful concept but no script yet.

1. Add a new object in `shop/catalog.json` `entries[]` with:
   - `id`
   - `class: "idea"`
   - `name`
   - `plainDescription`
   - `flavorLine`
   - `scriptPath: null`
   - `readmePath: null`
   - `status: "idea"`
   - `owner`
   - `addedOn` (`YYYY-MM-DD`)
   - `display` (both `saga` and `civ` variants)
   - `install` (`entrypointPath: null`, empty `bundlePaths`)
   - `tags`
2. Add or update a short note in `shop/SHOP.md`.
3. Run validator: `python3 scripts/validate_shop_catalog.py`

## Full Tool Path

Use this when you are shipping code now.

1. Create tool directory under the right category.
2. Add script and README.
3. Follow `DOCS-CONTRACT.md` section requirements.
4. Add at least one welcoming Civilian alias for dispatcher commands (when applicable).
5. Add catalog entry with `status: "active"`.
6. Ensure `scriptPath` and `readmePath` exist and are repo-relative.
7. Populate `display`, `install`, and `tags` fields for schema v2.
7. Run validator and smoke checks.

## Recommended: Use Materia Forge

```powershell
# Interactive scaffolding
powershell -ExecutionPolicy Bypass -File .\materia-forge.ps1

# Full tool by flags
powershell -ExecutionPolicy Bypass -File .\materia-forge.ps1 -Category weapon -Name "Pulse Shield" -Description "Monitors critical services"

# Idea-only by flags
powershell -ExecutionPolicy Bypass -File .\materia-forge.ps1 -Category idea -Name "Mognet" -Description "Unified notification relay" -FlavorLine "A reliable message network for operational updates."
```

## Catalog Field Rules

- `id`: unique kebab-case identifier
- `class`: `summon|weapon|spell|item|audio|idea`
- `scriptPath`: nullable, repo-relative path
- `readmePath`: nullable, repo-relative path
- `display`: object with `saga` and `civ` text variants
- `install`: object with entrypoint, bundle paths, dependencies, platforms
- `tags`: non-empty array of strings
- `status`: `active|idea|planned|deprecated`
- `addedOn`: `YYYY-MM-DD`

## Validation Commands

```bash
python3 scripts/validate_shop_catalog.py
python3 scripts/build_armory_manifest.py
python3 scripts/ci/check_manifest_determinism.py
```

```powershell
pwsh -File .\scripts\ci\help-smoke.ps1
pwsh -File .\scripts\ci\run-fixture-tests.ps1 -SevenZipPath "C:\Program Files\7-Zip\7z.exe"
```
