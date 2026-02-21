#!/usr/bin/env python3
"""Chronicle (Mac runtime) - cross-repo git intelligence."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class ChronicleRecord:
    repo: str
    path: str
    state: str
    branch: str
    ahead: int
    behind: int
    dirty: int
    untracked: int
    commits: list[dict[str, str]]


def expand_path(raw: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(raw))).resolve()


def run_git(repo: Path, args: list[str]) -> tuple[int, str]:
    proc = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    out = proc.stdout.strip() if proc.returncode == 0 else proc.stderr.strip()
    return proc.returncode, out


def load_targets(repos_file: Path, repo_paths: list[str]) -> list[Path]:
    if repo_paths:
        return [expand_path(raw) for raw in repo_paths]

    if not repos_file.exists():
        repos_file.parent.mkdir(parents=True, exist_ok=True)
        starter = {"repos": [], "note": "Add absolute repo paths to repos[]"}
        repos_file.write_text(json.dumps(starter, indent=2) + "\n", encoding="utf-8")
        return []

    try:
        obj = json.loads(repos_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        raise RuntimeError(f"Failed to parse repos file: {repos_file}") from None

    repos = obj.get("repos") if isinstance(obj, dict) else None
    if not isinstance(repos, list):
        return []

    targets: list[Path] = []
    for entry in repos:
        if isinstance(entry, str) and entry.strip():
            targets.append(expand_path(entry))

    dedup = sorted({str(path): path for path in targets}.values(), key=lambda p: str(p))
    return dedup


def collect_record(repo_path: Path) -> ChronicleRecord:
    repo_name = repo_path.name or str(repo_path)

    if not repo_path.exists():
        return ChronicleRecord(repo_name, str(repo_path), "missing", "-", 0, 0, 0, 0, [])

    if not (repo_path / ".git").exists():
        return ChronicleRecord(repo_name, str(repo_path), "not-git", "-", 0, 0, 0, 0, [])

    branch = "-"
    ahead = 0
    behind = 0
    dirty = 0
    untracked = 0

    code, out = run_git(repo_path, ["rev-parse", "--abbrev-ref", "HEAD"])
    if code == 0 and out:
        branch = out.strip()

    code, out = run_git(repo_path, ["status", "--porcelain"])
    if code == 0 and out:
        for line in out.splitlines():
            if line.startswith("??"):
                untracked += 1
            else:
                dirty += 1

    code, _ = run_git(repo_path, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"])
    if code == 0:
        code, out = run_git(repo_path, ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"])
        if code == 0 and out:
            parts = out.split()
            if len(parts) >= 2:
                behind = int(parts[0])
                ahead = int(parts[1])

    commits: list[dict[str, str]] = []
    code, out = run_git(repo_path, ["log", "-n", "3", "--pretty=format:%h|%s|%cr"])
    if code == 0 and out:
        for line in out.splitlines():
            parts = line.split("|", 2)
            if len(parts) == 3:
                commits.append({"hash": parts[0], "subject": parts[1], "relativeTime": parts[2]})

    return ChronicleRecord(repo_name, str(repo_path), "ok", branch, ahead, behind, dirty, untracked, commits)


def render_table(records: list[ChronicleRecord], detailed: bool) -> str:
    rows = [
        ["Repo", "Branch", "Ahead", "Behind", "Dirty", "Untracked", "State"],
    ]
    for rec in records:
        rows.append(
            [
                rec.repo,
                rec.branch,
                str(rec.ahead),
                str(rec.behind),
                str(rec.dirty),
                str(rec.untracked),
                rec.state,
            ]
        )

    widths = [max(len(row[idx]) for row in rows) for idx in range(len(rows[0]))]
    lines = ["Chronicle", "---------"]
    for row in rows:
        lines.append("  ".join(row[idx].ljust(widths[idx]) for idx in range(len(row))))

    if detailed:
        lines += ["", "Details", "-------"]
        for rec in records:
            lines.append(f"[{rec.repo}]")
            lines.append(f"  Path: {rec.path}")
            if rec.commits:
                for commit in rec.commits:
                    lines.append(f"  - {commit['hash']} {commit['subject']} ({commit['relativeTime']})")
            else:
                lines.append("  - no commit history available")
            lines.append("")

    return "\n".join(lines).rstrip()


def render_markdown(records: list[ChronicleRecord], detailed: bool) -> str:
    lines = [
        "| Repo | Branch | Ahead | Behind | Dirty | Untracked | State |",
        "|---|---|---:|---:|---:|---:|---|",
    ]
    for rec in records:
        lines.append(
            f"| {rec.repo} | {rec.branch} | {rec.ahead} | {rec.behind} | {rec.dirty} | {rec.untracked} | {rec.state} |"
        )

    if detailed:
        lines.append("")
        for rec in records:
            lines.append(f"### {rec.repo}")
            lines.append(f"- Path: {rec.path}")
            if rec.commits:
                for commit in rec.commits:
                    lines.append(f"- {commit['hash']} {commit['subject']} ({commit['relativeTime']})")
            else:
                lines.append("- no commit history available")
            lines.append("")

    return "\n".join(lines).rstrip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Chronicle - repo intelligence")
    parser.add_argument("--repos-file", default="~/.armory/repos.json")
    parser.add_argument("--repo-path", action="append", default=[])
    parser.add_argument("--format", choices=["table", "json", "markdown"], default="table")
    parser.add_argument("--detailed", action="store_true")
    parser.add_argument("--output", default="")
    args = parser.parse_args()

    repos_file = expand_path(args.repos_file)

    try:
        targets = load_targets(repos_file, args.repo_path)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if not targets:
        print("No repositories configured. Add entries to repos file or pass --repo-path.")
        return 0

    records = [collect_record(path) for path in targets]

    if args.format == "json":
        rendered = json.dumps([rec.__dict__ for rec in records], indent=2)
    elif args.format == "markdown":
        rendered = render_markdown(records, args.detailed)
    else:
        rendered = render_table(records, args.detailed)

    if args.output:
        out_path = expand_path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(rendered + "\n", encoding="utf-8")
        print(f"Chronicle output written: {out_path}")
    else:
        print(rendered)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
