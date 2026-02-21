#!/usr/bin/env python3
"""Build docs/data/armory-manifest.v1.json from shop/catalog.json."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = ROOT / "shop" / "catalog.json"
DEFAULT_OUT = ROOT / "docs" / "data" / "armory-manifest.v1.json"


def _run(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"command failed ({' '.join(cmd)}): {proc.stderr.strip()}")
    return proc.stdout.strip()


def _repo_slug(explicit: str | None) -> str:
    if explicit:
        return explicit

    url = _run(["git", "config", "--get", "remote.origin.url"])
    m = re.search(r"github\.com[:/](?P<owner>[^/]+)/(?P<repo>[^/.]+)(?:\.git)?$", url)
    if not m:
        raise RuntimeError(
            "Could not parse GitHub slug from remote.origin.url. Use --repo owner/name."
        )
    return f"{m.group('owner')}/{m.group('repo')}"


def _commit_sha() -> str:
    return _run(["git", "rev-parse", "HEAD"])


def _commit_time_iso() -> str:
    return _run(["git", "show", "-s", "--format=%cI", "HEAD"])


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _norm_mode(mode: str) -> str:
    raw = (mode or "").strip().lower()
    if raw in {"civ"}:
        return "civ"
    if raw in {"saga", "lore", "crystal"}:
        return "saga"
    return "saga"


def build_manifest(catalog: dict[str, Any], *, repo: str, ref: str, generated_at: str) -> dict[str, Any]:
    entries_in = catalog.get("entries", [])
    entries_out: list[dict[str, Any]] = []

    for entry in sorted(entries_in, key=lambda e: e.get("id", "")):
        install = entry.get("install", {}) if isinstance(entry, dict) else {}
        bundle_paths = install.get("bundlePaths", []) if isinstance(install, dict) else []

        checksums: dict[str, str] = {}
        bundle_urls: list[str] = []

        for rel in bundle_paths:
            full = ROOT / rel
            if full.exists() and full.is_file():
                checksums[rel] = _sha256(full)
            bundle_urls.append(f"https://raw.githubusercontent.com/{repo}/{ref}/{rel}")

        script_path = entry.get("scriptPath")
        readme_path = entry.get("readmePath")

        script_url = (
            f"https://raw.githubusercontent.com/{repo}/{ref}/{script_path}"
            if isinstance(script_path, str)
            else None
        )
        readme_url = (
            f"https://raw.githubusercontent.com/{repo}/{ref}/{readme_path}"
            if isinstance(readme_path, str)
            else None
        )

        entries_out.append(
            {
                "id": entry.get("id"),
                "class": entry.get("class"),
                "status": entry.get("status"),
                "owner": entry.get("owner"),
                "addedOn": entry.get("addedOn"),
                "display": entry.get("display", {}),
                "tags": entry.get("tags", []),
                "install": {
                    "entrypointPath": install.get("entrypointPath"),
                    "bundlePaths": bundle_paths,
                    "dependencies": install.get("dependencies", []),
                    "platforms": install.get("platforms", []),
                    "bundleUrls": bundle_urls,
                    "checksums": checksums,
                },
                "source": {
                    "scriptPath": script_path,
                    "readmePath": readme_path,
                    "scriptUrl": script_url,
                    "readmeUrl": readme_url,
                },
            }
        )

    return {
        "manifestVersion": 1,
        "catalogVersion": catalog.get("version"),
        "generatedAt": generated_at,
        "repo": repo,
        "ref": ref,
        "modeContract": {
            "key": "mode",
            "allowed": ["saga", "civ"],
            "default": "saga",
            "normalization": {
                "lore": "saga",
                "crystal": "saga",
            },
            "aliases": {
                "saga": "Crystal Saga Mode",
                "civ": "Civilian Mode",
            },
        },
        "agentFlow": {
            "requiredSequence": [
                "refresh_armory_clone",
                "scout_and_shortlist",
                "request_approval",
                "equip_selected_loadout",
                "report_in_active_mode",
            ],
            "refreshCommand": "git -C <armoryRepoRoot> pull --ff-only",
            "approvalRequired": True,
        },
        "telemetry": {
            "endpoint": "",
            "eventsPath": "/v1/events",
            "enabledByDefault": True,
            "optOut": {
                "installerFlag": "-NoTelemetry",
                "env": "ARMORY_TELEMETRY=off",
                "dashboardSetting": "telemetryOptOut=true",
            },
        },
        "entries": entries_out,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build Armory manifest JSON")
    parser.add_argument("--catalog", default=str(DEFAULT_CATALOG), help="Path to catalog JSON")
    parser.add_argument("--out", default=str(DEFAULT_OUT), help="Output manifest path")
    parser.add_argument("--repo", default="", help="GitHub repo slug owner/name")
    parser.add_argument("--ref", default="", help="Git ref for raw URLs (default: HEAD SHA)")
    args = parser.parse_args()

    catalog_path = Path(args.catalog)
    out_path = Path(args.out)

    if not catalog_path.exists():
        print(f"ERROR missing catalog: {catalog_path}")
        return 1

    try:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR invalid catalog JSON: {exc}")
        return 1

    try:
        repo = _repo_slug(args.repo or None)
        ref = args.ref or _commit_sha()
        generated_at = _commit_time_iso()
    except RuntimeError as exc:
        print(f"ERROR {exc}")
        return 1

    manifest = build_manifest(catalog, repo=repo, ref=ref, generated_at=generated_at)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"OK wrote manifest: {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
