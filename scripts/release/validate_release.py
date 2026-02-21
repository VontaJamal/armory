#!/usr/bin/env python3
"""Validate release readiness for Armory."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]
CHANGELOG_PATH = ROOT / "CHANGELOG.md"
SEMVER_RE = re.compile(r"^v\d+\.\d+\.\d+$")
HEADING_RE = re.compile(r"^## \[(?P<label>[^\]]+)\](?:\s*-\s*(?P<title>.*))?$")
PLACEHOLDER_RE = re.compile(r"\b(TBD|TODO|REPLACE_ME|<version>|x\.y\.z)\b", re.IGNORECASE)


class ValidationError(Exception):
    pass


def _run(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    if proc.returncode != 0:
        raise ValidationError(f"command failed: {' '.join(cmd)}\n{proc.stderr.strip()}")
    return proc.stdout


def _read_changelog() -> list[str]:
    if not CHANGELOG_PATH.exists():
        raise ValidationError(f"missing changelog: {CHANGELOG_PATH}")
    return CHANGELOG_PATH.read_text(encoding="utf-8").splitlines()


def _find_sections(lines: list[str]) -> list[tuple[str, int, int]]:
    sections: list[tuple[str, int, int]] = []
    heading_indexes: list[tuple[str, int]] = []

    for idx, line in enumerate(lines):
        m = HEADING_RE.match(line.strip())
        if m:
            heading_indexes.append((m.group("label"), idx))

    for i, (label, start) in enumerate(heading_indexes):
        end = heading_indexes[i + 1][1] if i + 1 < len(heading_indexes) else len(lines)
        sections.append((label, start + 1, end))

    return sections


def _get_section(lines: list[str], label: str) -> list[str]:
    for sec_label, start, end in _find_sections(lines):
        if sec_label == label:
            return lines[start:end]
    raise ValidationError(f"CHANGELOG missing required section: ## [{label}]")


def _check_placeholders(lines: Iterable[str], *, scope: str) -> None:
    for idx, line in enumerate(lines, start=1):
        if PLACEHOLDER_RE.search(line):
            raise ValidationError(f"placeholder detected in {scope} at line {idx}: {line.strip()}")


def _validate_ci_mode() -> None:
    lines = _read_changelog()
    if not any(line.strip() == "## [Unreleased]" for line in lines):
        raise ValidationError("CHANGELOG must contain ## [Unreleased]")

    _check_placeholders(lines, scope="CHANGELOG")


def _validate_tag_absent(version: str) -> None:
    local_tags = _run(["git", "tag", "--list", version]).splitlines()
    if any(t.strip() == version for t in local_tags):
        raise ValidationError(f"tag already exists locally: {version}")

    remote = _run(["git", "ls-remote", "--tags", "origin", f"refs/tags/{version}"]).strip()
    if remote:
        raise ValidationError(f"tag already exists on origin: {version}")


def _fetch_check_runs(repo: str, sha: str, token: str) -> dict[str, dict[str, str]]:
    results: dict[str, dict[str, str]] = {}
    page = 1

    while True:
        query = urllib.parse.urlencode({"per_page": 100, "page": page})
        url = f"https://api.github.com/repos/{repo}/commits/{sha}/check-runs?{query}"
        req = urllib.request.Request(
            url,
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {token}",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "armory-release-validator",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="ignore")
            raise ValidationError(f"failed to query check runs: HTTP {exc.code} {body}") from exc

        check_runs = payload.get("check_runs", [])
        for run in check_runs:
            name = str(run.get("name", "")).strip()
            if not name:
                continue
            results[name] = {
                "status": str(run.get("status", "")),
                "conclusion": str(run.get("conclusion", "")),
            }

        if len(check_runs) < 100:
            break
        page += 1

    return results


def _validate_required_checks(repo: str, sha: str, token: str, required_checks: list[str]) -> None:
    if not required_checks:
        return

    runs = _fetch_check_runs(repo, sha, token)
    missing: list[str] = []
    failed: list[str] = []

    for check in required_checks:
        info = runs.get(check)
        if info is None:
            missing.append(check)
            continue
        if info.get("status") != "completed" or info.get("conclusion") != "success":
            failed.append(f"{check} (status={info.get('status')}, conclusion={info.get('conclusion')})")

    if missing:
        raise ValidationError(f"required checks missing on commit {sha}: {', '.join(missing)}")
    if failed:
        raise ValidationError(f"required checks not successful on commit {sha}: {', '.join(failed)}")


def _validate_release_mode(args: argparse.Namespace) -> None:
    version = args.version
    if not version:
        raise ValidationError("--version is required in release mode")
    if not SEMVER_RE.match(version):
        raise ValidationError(f"version must match ^v\\d+\\.\\d+\\.\\d+$: {version}")

    lines = _read_changelog()
    section_lines = _get_section(lines, version)
    if not any(line.strip() for line in section_lines):
        raise ValidationError(f"CHANGELOG section [{version}] is empty")
    _check_placeholders(section_lines, scope=f"CHANGELOG section [{version}]")

    _validate_tag_absent(version)

    repo = args.repo
    sha = args.commit_sha
    token = args.github_token
    checks = args.required_check or []

    if checks:
        if not repo or not sha or not token:
            raise ValidationError("repo, commit SHA, and github token are required when validating required checks")
        _validate_required_checks(repo, sha, token, checks)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate release metadata and gating checks.")
    parser.add_argument("--mode", choices=["ci", "release"], required=True)
    parser.add_argument("--version")
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--commit-sha", default=os.environ.get("GITHUB_SHA", ""))
    parser.add_argument("--github-token", default=os.environ.get("GITHUB_TOKEN", ""))
    parser.add_argument("--required-check", action="append", default=[])
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.mode == "ci":
            _validate_ci_mode()
        else:
            _validate_release_mode(args)
    except ValidationError as exc:
        print(f"ERROR {exc}")
        return 1

    print(f"OK release validation passed (mode={args.mode})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
