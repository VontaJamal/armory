# Contributing To The Armory

Thanks for helping grow the Armory.

The Armory is a Final Fantasy-themed toolbox, but every item should solve a real problem for real developers.

## Where To Start

1. Read [`README.md`](README.md) to understand current categories.
2. Read [`DOCS-CONTRACT.md`](DOCS-CONTRACT.md) for README expectations.
3. Read [`shop/ADD-TO-SHOP.md`](shop/ADD-TO-SHOP.md) to submit a full tool or an idea-only entry.

## Two Contribution Paths

## Path A: Full Tool Submission

Use this when you are adding a script and docs now.

Checklist:

1. Pick a unique Final Fantasy-themed name.
2. Put the tool in the correct category folder (`summons/`, `weapons/`, `spells/`, `items/`, or `bard/`).
3. Add/update README using the docs contract.
4. Ensure script supports `-Help` and clean exit codes.
5. Add an entry in `shop/catalog.json` with `status: "active"`.

## Path B: Idea-Only Submission

Use this when the concept is useful but not implemented yet.

Checklist:

1. Add an entry in `shop/catalog.json` with `class: "idea"` and `status: "idea"`.
2. Provide a plain-language description of the problem it solves.
3. Keep `scriptPath` and `readmePath` as `null`.
4. Add a short note in `shop/SHOP.md` under the idea list.

## Naming Guidelines

1. Keep names themed, but keep descriptions practical.
2. Avoid duplicate names or near-duplicates of existing tools.
3. If renaming an existing tool, add migration notes and a compatibility alias plan.

## Quality Rules

1. Scripts should target PowerShell 5.1 unless explicitly documented otherwise.
2. Help paths should not crash.
3. Docs should be copy-paste friendly for regular users.
4. New links must resolve locally.

## Pull Request Notes

Include this in your PR body:

1. What problem does this solve?
2. Is this a full tool or idea-only shop entry?
3. Which files were added/changed?
4. How did you validate it?
