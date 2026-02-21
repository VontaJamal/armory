#!/usr/bin/env python3
"""Validate shop/catalog.json for schema, enums, and path rules."""

from __future__ import annotations

import datetime as _dt
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "shop" / "catalog.json"

REQUIRED_ENTRY_FIELDS = [
    "id",
    "class",
    "name",
    "plainDescription",
    "flavorLine",
    "scriptPath",
    "readmePath",
    "status",
    "owner",
    "addedOn",
]

ALLOWED_CLASS = {"summon", "weapon", "spell", "item", "audio", "idea"}
ALLOWED_STATUS = {"active", "idea", "planned", "deprecated"}
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def _entry_label(entry: dict[str, Any], index: int) -> str:
    entry_id = entry.get("id")
    if isinstance(entry_id, str) and entry_id.strip():
        return entry_id
    return f"entries[{index}]"


def _validate_relative_path(
    errors: list[str],
    *,
    entry_label: str,
    field_name: str,
    value: Any,
    require_exists: bool,
) -> None:
    if not isinstance(value, str) or not value.strip():
        errors.append(f"[{entry_label}] {field_name}: must be a non-empty relative path or null")
        return

    rel = Path(value)
    if rel.is_absolute():
        errors.append(f"[{entry_label}] {field_name}: must be repo-relative, not absolute")
        return

    resolved_root = ROOT.resolve()
    resolved = (ROOT / rel).resolve()
    try:
        resolved.relative_to(resolved_root)
    except ValueError:
        errors.append(f"[{entry_label}] {field_name}: path escapes repository root")
        return

    if require_exists and not resolved.exists():
        errors.append(f"[{entry_label}] {field_name}: path does not exist: {value}")


def _validate_added_on(errors: list[str], *, entry_label: str, value: Any) -> None:
    if not isinstance(value, str) or not re.match(r"^\d{4}-\d{2}-\d{2}$", value):
        errors.append(f"[{entry_label}] addedOn: must match YYYY-MM-DD")
        return

    try:
        _dt.datetime.strptime(value, "%Y-%m-%d")
    except ValueError:
        errors.append(f"[{entry_label}] addedOn: invalid calendar date")


def validate_catalog(catalog: Any) -> list[str]:
    errors: list[str] = []

    if not isinstance(catalog, dict):
        return ["top-level JSON must be an object"]

    version = catalog.get("version")
    if not isinstance(version, int):
        errors.append("top-level field 'version' must be an integer")

    entries = catalog.get("entries")
    if not isinstance(entries, list):
        errors.append("top-level field 'entries' must be an array")
        return errors

    seen_ids: set[str] = set()

    for idx, entry in enumerate(entries):
        if not isinstance(entry, dict):
            errors.append(f"entries[{idx}] must be an object")
            continue

        entry_label = _entry_label(entry, idx)

        for field in REQUIRED_ENTRY_FIELDS:
            if field not in entry:
                errors.append(f"[{entry_label}] missing required field: {field}")

        entry_id = entry.get("id")
        if isinstance(entry_id, str) and entry_id.strip():
            if not ID_PATTERN.match(entry_id):
                errors.append(f"[{entry_label}] id: must be kebab-case (lowercase letters, numbers, hyphens)")
            if entry_id in seen_ids:
                errors.append(f"[{entry_label}] id: duplicate id '{entry_id}'")
            seen_ids.add(entry_id)
        else:
            errors.append(f"[{entry_label}] id: must be a non-empty string")

        entry_class = entry.get("class")
        if entry_class not in ALLOWED_CLASS:
            errors.append(
                f"[{entry_label}] class: must be one of {sorted(ALLOWED_CLASS)}"
            )

        status = entry.get("status")
        if status not in ALLOWED_STATUS:
            errors.append(
                f"[{entry_label}] status: must be one of {sorted(ALLOWED_STATUS)}"
            )

        for text_field in ("name", "plainDescription", "flavorLine", "owner"):
            value = entry.get(text_field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"[{entry_label}] {text_field}: must be a non-empty string")

        _validate_added_on(errors, entry_label=entry_label, value=entry.get("addedOn"))

        script_path = entry.get("scriptPath")
        readme_path = entry.get("readmePath")

        if status == "idea":
            if script_path is not None:
                errors.append(f"[{entry_label}] scriptPath: must be null when status=idea")
            if readme_path is not None:
                errors.append(f"[{entry_label}] readmePath: must be null when status=idea")
        elif status == "active":
            _validate_relative_path(
                errors,
                entry_label=entry_label,
                field_name="scriptPath",
                value=script_path,
                require_exists=True,
            )
            _validate_relative_path(
                errors,
                entry_label=entry_label,
                field_name="readmePath",
                value=readme_path,
                require_exists=True,
            )
        else:
            if script_path is not None:
                _validate_relative_path(
                    errors,
                    entry_label=entry_label,
                    field_name="scriptPath",
                    value=script_path,
                    require_exists=False,
                )
            if readme_path is not None:
                _validate_relative_path(
                    errors,
                    entry_label=entry_label,
                    field_name="readmePath",
                    value=readme_path,
                    require_exists=False,
                )

    return errors


def main() -> int:
    if not CATALOG_PATH.exists():
        print(f"ERROR catalog file not found: {CATALOG_PATH}")
        return 1

    try:
        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR invalid JSON in {CATALOG_PATH}: {exc}")
        return 1

    errors = validate_catalog(catalog)
    if errors:
        for error in errors:
            print(f"ERROR {error}")
        return 1

    entries = catalog.get("entries", [])
    print(f"OK shop/catalog.json is valid ({len(entries)} entries)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
