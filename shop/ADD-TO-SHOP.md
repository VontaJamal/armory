# Add To Shop

This guide covers both implemented tools and idea-only submissions.

## Fast Path (Idea-Only)

Use this when you have a useful concept but no script yet.

1. Open `shop/catalog.json`.
2. Add a new `entries[]` object:
   - `id`
   - `class: "idea"`
   - `name`
   - `plainDescription`
   - `flavorLine`
   - `scriptPath: null`
   - `readmePath: null`
   - `status: "idea"`
   - `owner`
   - `addedOn`
3. Add a short bullet in `shop/SHOP.md`.

## Full Tool Path

Use this when you are shipping code now.

1. Create tool directory under the right category.
2. Add script and README.
3. Follow `DOCS-CONTRACT.md` section requirements.
4. Add `catalog.json` entry with `status: "active"`.
5. Update root `README.md` if this tool should appear in main tables.

## Catalog Field Rules

- `id`: kebab-case unique identifier
- `class`: `summon|weapon|spell|item|audio|idea`
- `scriptPath`: nullable, workspace-relative path
- `readmePath`: nullable, workspace-relative path
- `status`: `active|idea|planned|deprecated`
