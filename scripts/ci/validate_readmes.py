#!/usr/bin/env python3
"""Validate root and companion READMEs for mode-path clarity and link health."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
ROOT_README = ROOT / "README.md"
SAGA_README = ROOT / "README-SAGA.md"
CIV_README = ROOT / "README-CIV.md"

README_FILES = [ROOT_README, SAGA_README, CIV_README]
EXTERNAL_SCHEMES = ("http://", "https://", "mailto:", "tel:")

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"(?<!\!)\[[^\]]+\]\(([^)]+)\)")

REQUIRED_SAGA_SECTIONS = [
    "what armory is",
    "5-minute setup",
    "crystal saga workflow (manual + agent-first)",
    "ask your agent",
    "tool selection and equip examples",
    "mode controls (`civs`)",
    "troubleshooting",
    "validation commands",
    "contracts and references",
]

REQUIRED_CIV_SECTIONS = [
    "what armory is",
    "5-minute setup",
    "civilian workflow (manual + agent-first)",
    "ask your agent",
    "tool selection and install examples",
    "mode controls (`civs`)",
    "troubleshooting",
    "validation commands",
    "contracts and references",
]


def _normalize_heading(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def _extract_headings(text: str) -> list[str]:
    headings: list[str] = []
    for match in HEADING_RE.finditer(text):
        heading = match.group(2).strip()
        heading = re.sub(r"\s+#+$", "", heading).strip()
        headings.append(_normalize_heading(heading))
    return headings


def _slugify_heading(value: str) -> str:
    value = re.sub(r"`([^`]*)`", r"\1", value)
    value = re.sub(r"\[(.*?)\]\(.*?\)", r"\1", value)
    value = value.strip().lower()
    value = re.sub(r"[^\w\- ]", "", value)
    value = re.sub(r"\s+", "-", value)
    value = re.sub(r"-+", "-", value)
    return value.strip("-")


def _anchor_set(markdown_text: str) -> set[str]:
    seen: dict[str, int] = {}
    anchors: set[str] = set()
    for match in HEADING_RE.finditer(markdown_text):
        base = _slugify_heading(match.group(2))
        if not base:
            continue
        count = seen.get(base, 0)
        slug = base if count == 0 else f"{base}-{count}"
        seen[base] = count + 1
        anchors.add(slug)
    return anchors


def _parse_markdown_target(raw_target: str) -> str:
    target = raw_target.strip()

    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1].strip()

    titled_target = re.match(r'^(\S+)(?:\s+["\'][^"\']*["\'])?$', target)
    if titled_target:
        target = titled_target.group(1)

    return target


def _extract_markdown_links(text: str) -> list[str]:
    out: list[str] = []
    for match in LINK_RE.finditer(text):
        target = _parse_markdown_target(match.group(1))
        if target:
            out.append(target)
    return out


def _validate_required_sections(readme_path: Path, expected: list[str]) -> list[str]:
    errors: list[str] = []
    headings = _extract_headings(readme_path.read_text(encoding="utf-8"))

    cursor = 0
    for section in expected:
        found = False
        while cursor < len(headings):
            if headings[cursor] == section:
                found = True
                cursor += 1
                break
            cursor += 1
        if not found:
            errors.append(f"{readme_path.name}: missing required section '{section}'")

    return errors


def _validate_same_system_parity(readme_path: Path) -> list[str]:
    errors: list[str] = []
    text = readme_path.read_text(encoding="utf-8").lower()

    if "same system, two voices" not in text:
        errors.append(f"{readme_path.name}: missing 'Same System, Two Voices' parity note")

    for required_phrase in ("equip loadout", "install selected tools"):
        if required_phrase not in text:
            errors.append(f"{readme_path.name}: missing parity phrase '{required_phrase}'")

    return errors


def _validate_root_selector() -> list[str]:
    errors: list[str] = []
    text = ROOT_README.read_text(encoding="utf-8")
    links = _extract_markdown_links(text)

    if not any("README-SAGA.md" in link for link in links):
        errors.append("README.md: missing link to README-SAGA.md")
    if not any("README-CIV.md" in link for link in links):
        errors.append("README.md: missing link to README-CIV.md")
    if not any("mode=saga" in link for link in links):
        errors.append("README.md: missing dashboard mode deep-link for saga")
    if not any("mode=civ" in link for link in links):
        errors.append("README.md: missing dashboard mode deep-link for civ")

    return errors


def _resolve_link_target(source_path: Path, target: str) -> Path:
    parsed = urlsplit(target)
    if parsed.path:
        candidate = Path(parsed.path)
        if candidate.is_absolute():
            resolved = (ROOT / candidate.relative_to("/")).resolve()
        else:
            resolved = (source_path.parent / candidate).resolve()
        return resolved
    return source_path.resolve()


def _validate_internal_links() -> list[str]:
    errors: list[str] = []
    anchor_cache: dict[Path, set[str]] = {}
    resolved_root = ROOT.resolve()

    for readme in README_FILES:
        text = readme.read_text(encoding="utf-8")
        for target in _extract_markdown_links(text):
            lowered = target.lower()
            if lowered.startswith(EXTERNAL_SCHEMES):
                continue

            parsed = urlsplit(target)
            if parsed.scheme:
                continue

            resolved = _resolve_link_target(readme, target)
            try:
                resolved.relative_to(resolved_root)
            except ValueError:
                errors.append(f"{readme.name}: link escapes repository root -> {target}")
                continue

            if not resolved.exists():
                errors.append(f"{readme.name}: dead link -> {target}")
                continue

            if not parsed.fragment:
                continue

            if resolved.suffix.lower() != ".md" or resolved.is_dir():
                continue

            anchors = anchor_cache.get(resolved)
            if anchors is None:
                anchors = _anchor_set(resolved.read_text(encoding="utf-8"))
                anchor_cache[resolved] = anchors

            fragment = _normalize_heading(unquote(parsed.fragment).replace(" ", "-"))
            fragment = fragment.replace("_", "-")
            if fragment not in anchors:
                errors.append(
                    f"{readme.name}: missing anchor '#{parsed.fragment}' in {resolved.relative_to(ROOT)}"
                )

    return errors


def main() -> int:
    errors: list[str] = []

    for path in README_FILES:
        if not path.exists():
            errors.append(f"Missing required README file: {path.relative_to(ROOT)}")

    if errors:
        for error in errors:
            print(f"ERROR {error}")
        return 1

    errors.extend(_validate_root_selector())
    errors.extend(_validate_required_sections(SAGA_README, REQUIRED_SAGA_SECTIONS))
    errors.extend(_validate_required_sections(CIV_README, REQUIRED_CIV_SECTIONS))
    errors.extend(_validate_same_system_parity(SAGA_README))
    errors.extend(_validate_same_system_parity(CIV_README))
    errors.extend(_validate_internal_links())

    if errors:
        for error in errors:
            print(f"ERROR {error}")
        return 1

    print("OK README hub, companion guides, and link integrity are valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
