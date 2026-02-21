# Armory Deprecation Policy

This policy defines how renamed commands and compatibility wrappers are handled.

## Default Window

Compatibility aliases stay available for **two releases** by default.

## Required Lifecycle States

Every deprecated interface must be tracked with these release markers:

1. Introduced release: when the new primary command is shipped.
2. Deprecated release: when the old alias starts printing deprecation guidance.
3. Removal release: when the old alias is removed (default is two releases after deprecation).

## Release Counting Source

Release counting is measured from entries in `CHANGELOG.md`.
Each release entry must explicitly list:

- active aliases,
- deprecations started,
- aliases removed.

## Alias Requirements During Deprecation Window

1. Alias still executes the new primary script.
2. Alias prints a plain-language migration hint.
3. Primary README and root README list the new command first.

## Exceptions

Security or legal requirements can shorten the window. If shortened, document the reason in the changelog and release notes.
