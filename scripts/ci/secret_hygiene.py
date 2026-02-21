#!/usr/bin/env python3
"""Fail CI when high-risk secrets appear in tracked files."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]

RULES = [
    ("github_token", re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}\b")),
    ("openai_key", re.compile(r"\bsk-[A-Za-z0-9]{20,}\b")),
    ("anthropic_key", re.compile(r"\bsk-ant-[A-Za-z0-9\-]{20,}\b")),
    ("telegram_token", re.compile(r"\b\d{8,12}:[A-Za-z0-9_-]{30,}\b")),
    ("aws_access_key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("private_key", re.compile(r"-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    (
        "credentialed_url",
        re.compile(r"https?://[^\s/@:]+:[^\s/@]+@[^\s/]+", re.IGNORECASE),
    ),
]

DEFAULT_EXCLUDES = [
    "tests/fixtures/security/leak-repo/",
    "tests/fixtures/security/tracked-env/",
    "tests/fixtures/cure/",
]

TEXT_EXTENSIONS = {
    ".md",
    ".txt",
    ".json",
    ".yml",
    ".yaml",
    ".toml",
    ".ini",
    ".cfg",
    ".env",
    ".ps1",
    ".py",
    ".sh",
    ".cmd",
    ".xml",
    ".html",
    ".css",
    ".js",
    ".ts",
}


def _git_ls_files(root: Path) -> list[Path]:
    proc = subprocess.run(
        ["git", "-C", str(root), "ls-files"],
        check=True,
        capture_output=True,
        text=True,
    )
    files: list[Path] = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        files.append(root / line)
    return files


def _is_excluded(path: Path, excludes: Iterable[str]) -> bool:
    rel = path.relative_to(ROOT).as_posix()
    return any(rel.startswith(prefix) for prefix in excludes)


def _is_text_candidate(path: Path) -> bool:
    if path.suffix.lower() in TEXT_EXTENSIONS:
        return True
    return path.name.lower() in {".env", ".gitignore", ".gitattributes"}


def _scan_file(path: Path) -> list[tuple[str, int, str]]:
    findings: list[tuple[str, int, str]] = []
    try:
        content = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return findings

    for idx, line in enumerate(content.splitlines(), start=1):
        for name, regex in RULES:
            if regex.search(line):
                findings.append((name, idx, line.strip()))
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Scan tracked files for high-risk secrets.")
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Path prefix (repo-relative) to exclude. Can be passed multiple times.",
    )
    args = parser.parse_args()

    excludes = list(DEFAULT_EXCLUDES)
    excludes.extend(args.exclude)

    files = _git_ls_files(ROOT)
    violations: list[str] = []

    for path in files:
        if not path.exists() or not path.is_file():
            continue
        if _is_excluded(path, excludes):
            continue
        if not _is_text_candidate(path):
            continue

        findings = _scan_file(path)
        if not findings:
            continue

        rel = path.relative_to(ROOT).as_posix()
        for rule_name, line_no, sample in findings:
            truncated = sample[:140]
            violations.append(f"{rel}:{line_no} [{rule_name}] {truncated}")

    if violations:
        print("ERROR secret hygiene check failed. Remove secrets or move to secure config.")
        for item in violations:
            print(f"ERROR {item}")
        return 1

    print("OK secret hygiene check passed")
    return 0


if __name__ == "__main__":
    os.chdir(ROOT)
    sys.exit(main())
