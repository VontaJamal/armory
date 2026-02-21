#!/usr/bin/env python3
"""Remedy (Mac runtime) - read-only environment health checks."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_LIB = REPO_ROOT / "scripts" / "lib"
if str(SCRIPTS_LIB) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_LIB))

from armory_config import DEFAULT_INSTALL_DIR, load_config, normalize_mode  # noqa: E402


@dataclass
class CheckResult:
    check: str
    status: str
    message: str
    details: list[str]


ALL_CHECKS = ["config", "wrapper", "scripts", "repos", "ci", "shadow", "remote", "deps"]


def config_file() -> Path:
    return Path.home() / ".armory" / "config.json"


def add_result(rows: list[CheckResult], check: str, status: str, message: str, details: list[str] | None = None) -> None:
    rows.append(CheckResult(check=check, status=status, message=message, details=details or []))


def check_config(rows: list[CheckResult]) -> dict[str, Any] | None:
    path = config_file()
    if not path.exists():
        add_result(rows, "config", "FAIL", "Armory config missing", [str(path)])
        return None

    try:
        cfg = load_config(path)
    except Exception as exc:
        add_result(rows, "config", "FAIL", "Armory config unreadable", [str(exc)])
        return None

    issues: list[str] = []
    command_word = str(cfg.get("commandWord", ""))
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9-]{1,20}$", command_word):
        issues.append("invalid or missing commandWord")

    install_dir = str(cfg.get("installDir", ""))
    if not install_dir:
        issues.append("missing installDir")

    repo_root = str(cfg.get("repoRoot", ""))
    if not repo_root:
        issues.append("missing repoRoot")

    mode = normalize_mode(cfg.get("mode"), cfg.get("civilianAliases"))
    if mode not in {"saga", "civ"}:
        issues.append("invalid mode")

    if issues:
        add_result(rows, "config", "FAIL", "Armory config present but invalid", issues)
    else:
        add_result(
            rows,
            "config",
            "PASS",
            "Armory config is valid",
            [f"commandWord={command_word}", f"installDir={install_dir}", f"repoRoot={repo_root}", f"mode={mode}"],
        )

    return cfg


def check_wrapper(rows: list[CheckResult], cfg: dict[str, Any] | None) -> None:
    if not cfg:
        add_result(rows, "wrapper", "FAIL", "Cannot validate wrapper without config", [])
        return

    command_word = str(cfg.get("commandWord", "armory"))
    install_dir = Path(os.path.expanduser(str(cfg.get("installDir") or DEFAULT_INSTALL_DIR)))
    wrapper = install_dir / command_word

    if not wrapper.exists():
        add_result(rows, "wrapper", "FAIL", "Command shim not found", [str(wrapper)])
        return

    path_parts = os.environ.get("PATH", "").split(":")
    if str(install_dir) in path_parts:
        add_result(rows, "wrapper", "PASS", "Wrapper exists and installDir is on PATH", [str(wrapper)])
    else:
        add_result(rows, "wrapper", "WARN", "Wrapper exists but installDir is not on current PATH", [str(wrapper)])


def check_scripts(rows: list[CheckResult]) -> None:
    required = [
        "setup.sh",
        "awakening.sh",
        "civs.sh",
        "bin/armory-dispatch",
        "scripts/lib/armory_common.sh",
        "scripts/lib/armory_config.py",
        "scripts/lib/dispatch_routes.sh",
        "items/remedy/remedy.sh",
        "spells/chronicle/chronicle.sh",
        "summons/alexander/alexander.sh",
        "items/quartermaster/quartermaster.sh",
    ]
    missing = [rel for rel in required if not (REPO_ROOT / rel).exists()]

    if missing:
        add_result(rows, "scripts", "FAIL", "Critical Mac runtime scripts missing", missing)
    else:
        add_result(rows, "scripts", "PASS", "Critical Mac runtime scripts are present", [f"count={len(required)}"])


def check_repos(rows: list[CheckResult]) -> None:
    repos_file = Path.home() / ".armory" / "repos.json"
    if not repos_file.exists():
        add_result(rows, "repos", "WARN", "Repos allowlist missing", [str(repos_file)])
        return

    try:
        obj = json.loads(repos_file.read_text(encoding="utf-8"))
    except Exception as exc:
        add_result(rows, "repos", "FAIL", "Repos allowlist parse failed", [str(exc)])
        return

    repos = obj.get("repos") if isinstance(obj, dict) else None
    if not isinstance(repos, list):
        add_result(rows, "repos", "FAIL", "repos[] key missing in allowlist", [str(repos_file)])
        return

    bad = [entry for entry in repos if not isinstance(entry, str) or not entry.strip()]
    if bad:
        add_result(rows, "repos", "FAIL", "Repos allowlist has invalid entries", ["entries must be non-empty strings"])
        return

    if not repos:
        add_result(rows, "repos", "WARN", "Repos allowlist is valid but empty", [str(repos_file)])
        return

    add_result(rows, "repos", "PASS", "Repos allowlist is present and parseable", [f"count={len(repos)}", f"file={repos_file}"])


def check_ci(rows: list[CheckResult]) -> None:
    required = [
        "scripts/ci/mac-smoke.sh",
        "scripts/ci/quartermaster-smoke.sh",
        "scripts/ci/validate_readmes.py",
        "scripts/ci/validate_trust_store.py",
        "scripts/ci/secret_hygiene.py",
        "scripts/validate_shop_catalog.py",
        "scripts/build_armory_manifest.py",
        "scripts/ci/check_manifest_determinism.py",
        "scripts/release/validate_release.py",
    ]
    missing = [rel for rel in required if not (REPO_ROOT / rel).exists()]
    if missing:
        add_result(rows, "ci", "FAIL", "CI helper files missing", missing)
    else:
        add_result(rows, "ci", "PASS", "CI helper files are present", [f"count={len(required)}"])


def check_shadow(rows: list[CheckResult]) -> None:
    shadow_path = REPO_ROOT / "governance" / "seven-shadow-system"
    if shadow_path.exists():
        add_result(rows, "shadow", "PASS", "Seven Shadow System repository detected", [str(shadow_path)])
    else:
        add_result(rows, "shadow", "WARN", "Seven Shadow System not found in expected path", [str(shadow_path)])


def check_remote(rows: list[CheckResult]) -> None:
    if shutil.which("git") is None:
        add_result(rows, "remote", "WARN", "git not installed; remote credential check skipped", [])
        return

    proc = subprocess.run(["git", "remote", "-v"], cwd=str(REPO_ROOT), capture_output=True, text=True)
    lines = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    if proc.returncode != 0 or not lines:
        add_result(rows, "remote", "WARN", "No git remotes found to inspect", [])
        return

    pattern = re.compile(r"https?://[^/@\s]+:[^@\s]+@[^\s]+")
    hits: list[str] = []
    for line in lines:
        if pattern.search(line):
            scrubbed = re.sub(r"://([^:@\s]+):[^@\s]+@", r"://\1:***@", line)
            hits.append(scrubbed)

    if hits:
        add_result(rows, "remote", "FAIL", "Credentialed remote URL detected", sorted(set(hits)))
    else:
        add_result(rows, "remote", "PASS", "Remote URLs do not expose embedded credentials", [])


def check_deps(rows: list[CheckResult]) -> None:
    details: list[str] = []
    missing: list[str] = []

    for cmd in ["git", "python3", "zsh"]:
        if shutil.which(cmd):
            details.append(f"{cmd}=present")
        else:
            missing.append(cmd)
            details.append(f"{cmd}=missing")

    if shutil.which("tmux"):
        details.append("tmux=present")
    else:
        details.append("tmux=missing")

    if missing:
        add_result(rows, "deps", "WARN", f"Required dependencies missing: {', '.join(missing)}", details)
    else:
        add_result(rows, "deps", "PASS", "Required dependencies are available", details)


def render_table(rows: list[CheckResult]) -> str:
    headers = ["Check", "Status", "Message"]
    widths = [len(h) for h in headers]
    body: list[list[str]] = []
    for row in rows:
        vals = [row.check, row.status, row.message]
        body.append(vals)
        for i, val in enumerate(vals):
            widths[i] = max(widths[i], len(val))

    lines = []
    lines.append("  ".join(headers[i].ljust(widths[i]) for i in range(3)))
    lines.append("  ".join("-" * widths[i] for i in range(3)))
    for vals in body:
        lines.append("  ".join(vals[i].ljust(widths[i]) for i in range(3)))
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Remedy - Armory environment checks")
    parser.add_argument("--check", action="append", choices=ALL_CHECKS, default=[])
    parser.add_argument("--detailed", action="store_true")
    parser.add_argument("--output", default="")
    args = parser.parse_args()

    selected = args.check or ALL_CHECKS
    rows: list[CheckResult] = []

    cfg: dict[str, Any] | None = None
    for check in selected:
        if check == "config":
            cfg = check_config(rows)
        elif check == "wrapper":
            if cfg is None:
                cfg = check_config(rows)
            check_wrapper(rows, cfg)
        elif check == "scripts":
            check_scripts(rows)
        elif check == "repos":
            check_repos(rows)
        elif check == "ci":
            check_ci(rows)
        elif check == "shadow":
            check_shadow(rows)
        elif check == "remote":
            check_remote(rows)
        elif check == "deps":
            check_deps(rows)

    fail_count = sum(1 for row in rows if row.status == "FAIL")
    warn_count = sum(1 for row in rows if row.status == "WARN")
    pass_count = sum(1 for row in rows if row.status == "PASS")

    lines = [
        "Remedy (Mac runtime)",
        "--------------------",
        render_table(rows),
        "",
        f"Summary: PASS={pass_count} WARN={warn_count} FAIL={fail_count}",
    ]

    if args.detailed:
        lines.append("")
        lines.append("Details")
        lines.append("-------")
        for row in rows:
            lines.append(f"[{row.check}] {row.status} - {row.message}")
            if row.details:
                for detail in row.details:
                    lines.append(f"  - {detail}")
            else:
                lines.append("  - (no details)")

    output = "\n".join(lines)

    if args.output:
        out_path = Path(os.path.expanduser(args.output)).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(output + "\n", encoding="utf-8")
        print(f"Remedy report written: {out_path}")
    else:
        print(output)

    return 1 if fail_count > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
