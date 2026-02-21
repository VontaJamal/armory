#!/usr/bin/env python3
"""Alexander (Mac runtime) - release preflight gate."""

from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


@dataclass
class GateResult:
    name: str
    status: str
    exit_code: int
    message: str
    command: str
    output: str


def run_capture(cmd: list[str], cwd: Path) -> tuple[int, str]:
    proc = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)
    out = "\n".join(part for part in [proc.stdout.strip(), proc.stderr.strip()] if part)
    return proc.returncode, out


def parse_skip(values: list[str]) -> set[str]:
    out: set[str] = set()
    for value in values:
        parts = [item.strip().lower() for item in value.split(",") if item.strip()]
        out.update(parts)
    return out


def gate_checks() -> list[dict[str, object]]:
    return [
        {
            "name": "catalog",
            "description": "Validate shop catalog schema and paths",
            "command": ["python3", "scripts/validate_shop_catalog.py"],
        },
        {
            "name": "secrets",
            "description": "Scan tracked files for secret patterns",
            "command": ["python3", "scripts/ci/secret_hygiene.py"],
        },
        {
            "name": "remote",
            "description": "Ensure git remotes do not embed credentials",
            "command": ["bash", "scripts/ci/check_remote_url.sh"],
        },
        {
            "name": "smoke",
            "description": "Run Mac runtime smoke checks",
            "command": ["bash", "scripts/ci/mac-smoke.sh"],
        },
        {
            "name": "fixtures",
            "description": "Run quartermaster smoke tests",
            "command": ["bash", "scripts/ci/quartermaster-smoke.sh"],
        },
        {
            "name": "chronicle",
            "description": "Run chronicle self-check",
            "command": ["bash", "spells/chronicle/chronicle.sh", "--repo-path", str(REPO_ROOT), "--format", "json"],
        },
        {
            "name": "release",
            "description": "Validate changelog/release baseline",
            "command": ["python3", "scripts/release/validate_release.py", "--mode", "ci"],
        },
        {
            "name": "remedy",
            "description": "Run remedy environment checks",
            "command": ["bash", "items/remedy/remedy.sh"],
        },
    ]


def render_table(rows: list[GateResult]) -> str:
    headers = ["Check", "Status", "Exit", "Message"]
    widths = [len(header) for header in headers]

    body: list[list[str]] = []
    for row in rows:
        vals = [row.name, row.status, str(row.exit_code), row.message]
        body.append(vals)
        for idx, val in enumerate(vals):
            widths[idx] = max(widths[idx], len(val))

    lines = ["  ".join(headers[i].ljust(widths[i]) for i in range(len(headers)))]
    lines.append("  ".join("-" * widths[i] for i in range(len(headers))))
    for vals in body:
        lines.append("  ".join(vals[i].ljust(widths[i]) for i in range(len(headers))))
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Alexander - release preflight gate")
    parser.add_argument("--skip", action="append", default=[])
    parser.add_argument("--detailed", action="store_true")
    parser.add_argument("--output", default="")
    args = parser.parse_args()

    skip = parse_skip(args.skip)
    checks = gate_checks()

    rows: list[GateResult] = []
    for check in checks:
        name = str(check["name"])
        cmd = [str(item) for item in check["command"]]  # type: ignore[index]

        if name in skip:
            rows.append(
                GateResult(name=name, status="WARN", exit_code=0, message="Skipped by request", command=" ".join(shlex.quote(p) for p in cmd), output="")
            )
            continue

        code, output = run_capture(cmd, cwd=REPO_ROOT)
        status = "PASS" if code == 0 else "FAIL"
        message = "Check passed" if code == 0 else f"Check failed (exit {code})"
        rows.append(
            GateResult(
                name=name,
                status=status,
                exit_code=code,
                message=message,
                command=" ".join(shlex.quote(p) for p in cmd),
                output=output,
            )
        )

    fail_count = sum(1 for row in rows if row.status == "FAIL")
    warn_count = sum(1 for row in rows if row.status == "WARN")
    pass_count = sum(1 for row in rows if row.status == "PASS")

    lines = [
        "Alexander Preflight Gate (Mac runtime)",
        "-------------------------------------",
        f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"Repo: {REPO_ROOT}",
        "",
        render_table(rows),
        "",
        f"Summary: PASS={pass_count} WARN={warn_count} FAIL={fail_count}",
    ]

    if args.detailed:
        lines += ["", "Detailed Output", "--------------"]
        for row in rows:
            lines += ["", f"[{row.name}] {row.command}"]
            lines.append(row.output if row.output else "(no output)")

    final = "\n".join(lines)

    if args.output:
        out_path = Path(os.path.expanduser(args.output)).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(final + "\n", encoding="utf-8")
        print(f"Alexander report written: {out_path}")
    else:
        print(final)

    return 1 if fail_count > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
