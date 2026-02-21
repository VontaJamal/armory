#!/usr/bin/env python3
"""Verify build_armory_manifest.py is deterministic for same inputs."""

from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "scripts" / "build_armory_manifest.py"
CATALOG = ROOT / "shop" / "catalog.json"


def _run_build(out_path: Path) -> None:
    cmd = [
        sys.executable,
        str(BUILDER),
        "--catalog",
        str(CATALOG),
        "--out",
        str(out_path),
    ]
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "manifest build failed")


def _sha(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="armory-manifest-") as tmp:
        a = Path(tmp) / "a.json"
        b = Path(tmp) / "b.json"

        _run_build(a)
        _run_build(b)

        sha_a = _sha(a)
        sha_b = _sha(b)
        if sha_a != sha_b:
            print("ERROR manifest build is not deterministic")
            print(f"a={sha_a}")
            print(f"b={sha_b}")
            return 1

    print("OK manifest build is deterministic")
    return 0


if __name__ == "__main__":
    sys.exit(main())
