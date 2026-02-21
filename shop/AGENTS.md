# Shop Agent Notes

Use `shop/catalog.json` as source data and `docs/data/armory-manifest.v1.json` when present.

During scout:

1. Read all classes (`summon`, `weapon`, `spell`, `item`, `audio`, `idea`).
2. Filter by user context and platform.
3. Recommend top options with rationale and dependencies.
4. Return full catalog only when user asks.

Always respect shared `mode=saga|civ` for report tone.
