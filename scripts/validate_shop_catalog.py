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
    "display",
    "install",
    "tags",
]

ALLOWED_CLASS = {"summon", "weapon", "spell", "item", "audio", "idea"}
ALLOWED_STATUS = {"active", "idea", "planned", "deprecated"}
ALLOWED_MODE = {"saga", "civ"}
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
        errors.append(f"[{entry_label}] {field_name}: must be a non-empty relative path")
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


def _validate_display(errors: list[str], *, entry_label: str, value: Any) -> None:
    if not isinstance(value, dict):
        errors.append(f"[{entry_label}] display: must be an object")
        return

    for mode in sorted(ALLOWED_MODE):
        mode_obj = value.get(mode)
        if not isinstance(mode_obj, dict):
            errors.append(f"[{entry_label}] display.{mode}: must be an object")
            continue
        for field in ("name", "description"):
            field_value = mode_obj.get(field)
            if not isinstance(field_value, str) or not field_value.strip():
                errors.append(f"[{entry_label}] display.{mode}.{field}: must be a non-empty string")


def _validate_string_list(
    errors: list[str],
    *,
    entry_label: str,
    field_name: str,
    value: Any,
    allow_empty: bool,
) -> list[str]:
    if not isinstance(value, list):
        errors.append(f"[{entry_label}] {field_name}: must be an array")
        return []

    out: list[str] = []
    for idx, item in enumerate(value):
        if not isinstance(item, str) or not item.strip():
            errors.append(f"[{entry_label}] {field_name}[{idx}]: must be a non-empty string")
            continue
        out.append(item)

    if not allow_empty and not out:
        errors.append(f"[{entry_label}] {field_name}: must contain at least one value")

    return out


def _validate_install(
    errors: list[str],
    *,
    entry_label: str,
    entry: dict[str, Any],
    status: Any,
) -> None:
    value = entry.get("install")
    if not isinstance(value, dict):
        errors.append(f"[{entry_label}] install: must be an object")
        return

    for field in ("entrypointPath", "bundlePaths", "dependencies", "platforms"):
        if field not in value:
            errors.append(f"[{entry_label}] install missing field: {field}")

    entrypoint = value.get("entrypointPath")
    bundle_paths = _validate_string_list(
        errors,
        entry_label=entry_label,
        field_name="install.bundlePaths",
        value=value.get("bundlePaths"),
        allow_empty=(status == "idea"),
    )
    _validate_string_list(
        errors,
        entry_label=entry_label,
        field_name="install.dependencies",
        value=value.get("dependencies"),
        allow_empty=True,
    )
    platforms = _validate_string_list(
        errors,
        entry_label=entry_label,
        field_name="install.platforms",
        value=value.get("platforms"),
        allow_empty=(status == "idea"),
    )

    if status == "idea":
        if entrypoint is not None:
            errors.append(f"[{entry_label}] install.entrypointPath: must be null when status=idea")
        if bundle_paths:
            errors.append(f"[{entry_label}] install.bundlePaths: must be empty when status=idea")
        return

    _validate_relative_path(
        errors,
        entry_label=entry_label,
        field_name="install.entrypointPath",
        value=entrypoint,
        require_exists=(status == "active"),
    )

    for idx, path_value in enumerate(bundle_paths):
        _validate_relative_path(
            errors,
            entry_label=entry_label,
            field_name=f"install.bundlePaths[{idx}]",
            value=path_value,
            require_exists=(status == "active"),
        )

    script_path = entry.get("scriptPath")
    if status == "active" and isinstance(script_path, str) and isinstance(entrypoint, str):
        if script_path != entrypoint:
            errors.append(
                f"[{entry_label}] install.entrypointPath must match scriptPath for active entries"
            )

    if status == "active":
        if isinstance(entrypoint, str) and not entrypoint.endswith(".sh"):
            errors.append(f"[{entry_label}] install.entrypointPath must be a .sh script for active entries")
        if "macos" not in platforms:
            errors.append(f"[{entry_label}] install.platforms must include 'macos' for active entries")


def validate_catalog(catalog: Any) -> list[str]:
    errors: list[str] = []

    if not isinstance(catalog, dict):
        return ["top-level JSON must be an object"]

    version = catalog.get("version")
    if version != 2:
        errors.append("top-level field 'version' must be 2")

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

        _validate_display(errors, entry_label=entry_label, value=entry.get("display"))
        _validate_install(errors, entry_label=entry_label, entry=entry, status=status)
        _validate_string_list(
            errors,
            entry_label=entry_label,
            field_name="tags",
            value=entry.get("tags"),
            allow_empty=False,
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
