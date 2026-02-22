#!/usr/bin/env python3
"""Fail CI if dashboard renderer uses unsafe HTML injection APIs."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "docs" / "assets" / "app.js"

BANNED_PATTERNS = (
    re.compile(r"\binnerHTML\s*="),
    re.compile(r"\binsertAdjacentHTML\s*\("),
    re.compile(r"\bouterHTML\s*="),
)


def main() -> int:
    if not TARGET.exists():
        print(f"ERROR missing dashboard script: {TARGET.relative_to(ROOT)}")
        return 1

    source = TARGET.read_text(encoding="utf-8")
    findings: list[tuple[int, str, str]] = []

    for lineno, line in enumerate(source.splitlines(), start=1):
        for pattern in BANNED_PATTERNS:
            if pattern.search(line):
                findings.append((lineno, pattern.pattern, line.strip()))

    if findings:
        print("ERROR dashboard security check failed. Unsafe HTML assignment detected.")
        for lineno, pattern, line in findings:
            print(f"ERROR docs/assets/app.js:{lineno} [{pattern}] {line}")
        return 1

    print("OK dashboard security check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
