#!/usr/bin/env python3
"""Quartermaster Mac runtime: scout, plan, equip, and report."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_LIB = REPO_ROOT / "scripts" / "lib"
if str(SCRIPTS_LIB) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_LIB))

from armory_config import DEFAULT_INSTALL_DIR, ensure_config, load_config, normalize_mode  # noqa: E402


STOP_WORDS = {
    "this",
    "that",
    "with",
    "from",
    "have",
    "need",
    "repo",
    "issue",
    "task",
    "help",
    "please",
    "about",
    "into",
    "when",
    "your",
    "their",
    "the",
    "and",
}


@dataclass
class RefreshResult:
    success: bool
    command: str
    output: str


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def config_path() -> Path:
    return Path.home() / ".armory" / "config.json"


def last_plan_path() -> Path:
    return Path.home() / ".armory" / "quartermaster" / "last-plan.json"


def expand_path(raw: str | None) -> Path | None:
    if not raw:
        return None
    return Path(os.path.expandvars(os.path.expanduser(raw))).resolve()


def is_armory_root(path: Path) -> bool:
    return (
        path.is_dir()
        and (path / "awakening.sh").is_file()
        and (path / "shop" / "catalog.json").is_file()
    )


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def run_git(args: list[str], cwd: Path) -> tuple[int, str]:
    proc = subprocess.run(
        ["git", *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )
    output = "\n".join(part for part in [proc.stdout.strip(), proc.stderr.strip()] if part)
    return proc.returncode, output


def refresh_armory(armory_root: Path) -> RefreshResult:
    command = "git -C <armoryRepoRoot> pull --ff-only"

    code, output = run_git(["-C", str(armory_root), "pull", "--ff-only"], cwd=armory_root)
    if code == 0:
        return RefreshResult(True, command, output)

    if "not currently on a branch" in output.lower():
        fcode, foutput = run_git(["-C", str(armory_root), "fetch", "--all", "--prune"], cwd=armory_root)
        if fcode == 0:
            joined = "\n".join(
                part
                for part in [
                    output,
                    "[detached HEAD fallback succeeded]",
                    foutput,
                ]
                if part
            )
            return RefreshResult(
                True,
                command + " (detached-head fallback: git -C <armoryRepoRoot> fetch --all --prune)",
                joined,
            )

    return RefreshResult(False, command, output)


def load_manifest_entries(armory_root: Path) -> tuple[str, list[dict[str, Any]]]:
    manifest = armory_root / "docs" / "data" / "armory-manifest.v1.json"
    if manifest.exists():
        obj = load_json(manifest)
        entries = obj.get("entries", []) if isinstance(obj, dict) else []
        return str(obj.get("ref", "local")), [e for e in entries if isinstance(e, dict)]

    catalog = armory_root / "shop" / "catalog.json"
    obj = load_json(catalog)
    entries = []
    for raw in obj.get("entries", []):
        if not isinstance(raw, dict):
            continue
        entries.append(
            {
                "id": raw.get("id"),
                "class": raw.get("class"),
                "status": raw.get("status"),
                "display": raw.get("display", {}),
                "tags": raw.get("tags", []),
                "install": raw.get("install", {}),
                "source": {
                    "scriptPath": raw.get("scriptPath"),
                    "readmePath": raw.get("readmePath"),
                },
            }
        )
    return "local", entries


def parse_repo_context(repo_path: Path) -> dict[str, Any]:
    summary: list[str] = [f"Repo path: {repo_path}"]
    terms: set[str] = set()

    code, branch = run_git(["-C", str(repo_path), "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo_path)
    if code == 0 and branch:
        summary.append(f"Git branch: {branch.strip()}")

    code, dirty = run_git(["-C", str(repo_path), "status", "--porcelain"], cwd=repo_path)
    if code == 0:
        dirty_lines = [line for line in dirty.splitlines() if line.strip()]
        summary.append(f"Dirty files: {len(dirty_lines)}")
        if dirty_lines:
            terms.update({"stability", "diagnostics"})

    ext_counts: dict[str, int] = {}
    scanned = 0
    for path in repo_path.rglob("*"):
        if scanned >= 400:
            break
        if not path.is_file():
            continue
        scanned += 1
        ext = path.suffix.lower()
        ext_counts[ext] = ext_counts.get(ext, 0) + 1

    top_ext = sorted(ext_counts, key=lambda k: ext_counts[k], reverse=True)[:5]
    for ext in top_ext:
        if ext == ".sh":
            terms.update({"shell", "automation", "macos"})
        elif ext == ".ps1":
            terms.update({"powershell", "automation"})
        elif ext in {".yml", ".yaml"}:
            terms.update({"ci", "release"})
        elif ext == ".py":
            terms.add("python")
        elif ext == ".md":
            terms.add("docs")

    if (repo_path / ".github" / "workflows").exists():
        terms.update({"release", "preflight"})

    return {"summary": summary, "terms": sorted(terms)}


def task_terms(task: str, repo_terms: list[str]) -> list[str]:
    source = f"{task} {' '.join(repo_terms)}".strip().lower()
    tokens = re.split(r"[^a-z0-9]+", source)
    filtered = {tok for tok in tokens if len(tok) >= 3 and tok not in STOP_WORDS}
    return sorted(filtered)


def score_entry(entry: dict[str, Any], terms: list[str]) -> tuple[int, list[str]]:
    score = 0
    matched: set[str] = set()

    entry_id = str(entry.get("id", "")).lower()
    entry_class = str(entry.get("class", "")).lower()
    tags = " ".join(str(t) for t in entry.get("tags", []))
    tags = tags.lower()

    display = entry.get("display", {})
    saga = display.get("saga", {}) if isinstance(display, dict) else {}
    civ = display.get("civ", {}) if isinstance(display, dict) else {}
    display_text = " ".join(
        [
            str(saga.get("name", "")),
            str(saga.get("description", "")),
            str(civ.get("name", "")),
            str(civ.get("description", "")),
        ]
    ).lower()

    for term in terms:
        if term in entry_id or term in entry_class or term in tags:
            score += 4
            matched.add(term)
        if term in display_text:
            score += 2
            matched.add(term)

    if score == 0:
        score = 2 if entry_class in {"item", "spell"} else 1

    return score, sorted(matched)


def build_shortlist(entries: list[dict[str, Any]], terms: list[str], top: int, mode: str) -> list[dict[str, Any]]:
    scored: list[dict[str, Any]] = []
    for entry in entries:
        score, matched = score_entry(entry, terms)
        display = entry.get("display", {})
        display_mode = (display.get(mode, {}) if isinstance(display, dict) else {}) or {}

        name = display_mode.get("name") or entry.get("id")
        desc = display_mode.get("description") or "No description available."
        rationale = (
            f"Matches task/context terms: {', '.join(matched)}."
            if matched
            else "General-purpose active Armory tool for diagnostics/readiness."
        )

        install = entry.get("install", {}) if isinstance(entry.get("install"), dict) else {}
        scored.append(
            {
                "id": str(entry.get("id")),
                "class": str(entry.get("class")),
                "score": score,
                "name": str(name),
                "description": str(desc),
                "rationale": rationale,
                "dependencies": [str(x) for x in install.get("dependencies", [])],
                "entrypointPath": install.get("entrypointPath"),
            }
        )

    scored.sort(key=lambda row: (-row["score"], row["id"]))
    return scored[:top]


def expand_dependencies(seed_ids: list[str], entry_by_id: dict[str, dict[str, Any]]) -> dict[str, list[str]]:
    ordered: list[str] = []
    missing: set[str] = set()
    seen: set[str] = set()
    queue: deque[str] = deque([sid for sid in seed_ids if sid])

    while queue:
        item_id = queue.popleft()
        if item_id in seen:
            continue
        seen.add(item_id)

        entry = entry_by_id.get(item_id)
        if not entry:
            missing.add(item_id)
            continue

        ordered.append(item_id)
        deps = entry.get("install", {}).get("dependencies", [])
        for dep in deps:
            dep_id = str(dep)
            if dep_id and dep_id not in seen:
                queue.append(dep_id)

    return {"ids": ordered, "missing": sorted(missing)}


def print_failure(mode: str, headline: str, detail: str = "") -> None:
    print()
    if mode == "civ":
        print(headline)
    else:
        print(f"Tactical setback: {headline}")
    if detail:
        print(detail)
    print()


def print_scout(mode: str, task: str, repo_context: dict[str, Any], shortlist: list[dict[str, Any]], deps: dict[str, list[str]]) -> None:
    print()
    print("Quartermaster scout report")
    print("------------------------")
    if mode == "saga":
        print("Crystal resonance confirmed. Scouting report follows.")

    print(f"Task context: {task}")
    for line in repo_context.get("summary", []):
        print(f"- {line}")

    print("\nRecommended loadout:")
    for item in shortlist:
        dep_text = ", ".join(item.get("dependencies", [])) or "none"
        print(f"- {item['id']} ({item['class']})")
        print(f"  Why: {item['rationale']}")
        print(f"  Dependencies: {dep_text}")

    missing = deps.get("missing", [])
    if missing:
        print(f"\nDependency warnings: missing entries [{', '.join(missing)}]")

    print("\nRisk/impact: tools are read-only unless you run equip/install actions.")
    print("Full catalog available on request.")
    print()


def print_equip(mode: str, installed: list[str], failed: list[str], install_dir: Path) -> None:
    print()
    if mode == "civ":
        print("Install complete.")
    else:
        print("Loadout equipped. The party is battle-ready.")

    print(f"Installed tool IDs: {', '.join(sorted(installed))}")
    if failed:
        print(f"Failed tool IDs: {', '.join(sorted(failed))}")
    print(f"Install directory: {install_dir}")
    print()


def resolve_mode(
    args_mode: str | None,
    config: dict[str, Any],
    target_repo: Path,
) -> str:
    if args_mode:
        return normalize_mode(args_mode)

    cfg_mode = config.get("mode")
    if cfg_mode is not None:
        return normalize_mode(cfg_mode, config.get("civilianAliases"))

    sovereign = target_repo / ".sovereign.json"
    if sovereign.exists():
        try:
            obj = load_json(sovereign)
            if isinstance(obj, dict) and "mode" in obj:
                return normalize_mode(obj.get("mode"))
        except Exception:
            pass

    env_mode = os.getenv("ARMORY_MODE") or os.getenv("SOVEREIGN_MODE")
    if env_mode:
        return normalize_mode(env_mode)

    return "saga"


def resolve_armory_root(args_root: str | None, config: dict[str, Any]) -> Path:
    explicit = expand_path(args_root)

    candidates: list[Path] = []
    if explicit:
        candidates.append(explicit)

    cfg_root = expand_path(str(config.get("repoRoot", ""))) if config.get("repoRoot") else None
    if cfg_root:
        candidates.append(cfg_root)

    env_root = expand_path(os.getenv("ARMORY_REPO_ROOT"))
    if env_root:
        candidates.append(env_root)

    cwd = Path.cwd().resolve()
    candidates.extend(
        [
            cwd,
            cwd / "armory",
            cwd.parent / "armory",
            Path.home() / "armory",
            Path.home() / "Documents" / "Code Repos" / "armory",
        ]
    )

    seen: set[Path] = set()
    for candidate in candidates:
        c = candidate.resolve()
        if c in seen:
            continue
        seen.add(c)
        if is_armory_root(c):
            if not explicit or c != explicit:
                ensure_config(path=config_path(), repo_root=str(c))
            return c

    print("Armory path was not auto-discovered.")
    print("Enter the Armory repository path once to persist it for future runs.")
    if sys.stdin.isatty():
        manual = input("Armory path: ").strip()
        manual_path = expand_path(manual)
        if manual_path and is_armory_root(manual_path):
            ensure_config(path=config_path(), repo_root=str(manual_path))
            return manual_path

    raise RuntimeError("Unable to resolve Armory path. Run setup with: ./setup.sh")


def plan_target_path(plan_path_arg: str | None, from_last_plan: bool) -> Path:
    if plan_path_arg:
        return expand_path(plan_path_arg) or last_plan_path()
    if from_last_plan:
        return last_plan_path()
    return last_plan_path()


def read_plan(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise RuntimeError(f"Plan file not found: {path}")
    try:
        obj = load_json(path)
    except Exception as exc:
        raise RuntimeError(f"Plan file parse failed: {path}: {exc}") from exc
    if not isinstance(obj, dict):
        raise RuntimeError(f"Plan file parse failed: {path}")
    return obj


def _active_entries(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for entry in entries:
        if entry.get("status") != "active":
            continue
        if entry.get("class") == "idea":
            continue
        install = entry.get("install", {}) if isinstance(entry.get("install"), dict) else {}
        if not install.get("entrypointPath"):
            continue
        rows.append(entry)
    return rows


def _build_entry_map(entries: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for entry in entries:
        entry_id = entry.get("id")
        if isinstance(entry_id, str):
            out[entry_id] = entry
    return out


def scout_action(args: argparse.Namespace, config: dict[str, Any], active_mode: str, armory_root: Path, repo_path: Path) -> int:
    refresh = refresh_armory(armory_root)
    if not refresh.success:
        print_failure(active_mode, "Armory refresh failed; stopping before scout.", refresh.output)
        return 1

    _, entries = load_manifest_entries(armory_root)
    active_entries = _active_entries(entries)

    repo_context = parse_repo_context(repo_path)
    terms = task_terms(args.task, repo_context["terms"])
    shortlist = build_shortlist(active_entries, terms, args.top, active_mode)

    entry_by_id = _build_entry_map(active_entries)
    dep_result = expand_dependencies([s["id"] for s in shortlist], entry_by_id)

    print_scout(active_mode, args.task, repo_context, shortlist, dep_result)
    return 0


def plan_action(args: argparse.Namespace, config: dict[str, Any], active_mode: str, armory_root: Path, repo_path: Path) -> int:
    refresh = refresh_armory(armory_root)
    if not refresh.success:
        print_failure(active_mode, "Armory refresh failed; stopping before cart planning.", refresh.output)
        return 1

    manifest_ref, entries = load_manifest_entries(armory_root)
    active_entries = _active_entries(entries)

    repo_context = parse_repo_context(repo_path)
    terms = task_terms(args.task, repo_context["terms"])
    shortlist = build_shortlist(active_entries, terms, args.top, active_mode)
    entry_by_id = _build_entry_map(active_entries)
    dep_result = expand_dependencies([s["id"] for s in shortlist], entry_by_id)

    loadout_entries: list[dict[str, Any]] = []
    for entry_id in dep_result["ids"]:
        entry = entry_by_id.get(entry_id)
        if not entry:
            continue
        display = entry.get("display", {})
        display_mode = display.get(active_mode, {}) if isinstance(display, dict) else {}
        install = entry.get("install", {}) if isinstance(entry.get("install"), dict) else {}
        loadout_entries.append(
            {
                "id": str(entry.get("id")),
                "class": str(entry.get("class")),
                "name": str(display_mode.get("name") or entry.get("id")),
                "description": str(display_mode.get("description") or "No description available."),
                "entrypointPath": str(install.get("entrypointPath")),
                "dependencies": [str(x) for x in install.get("dependencies", [])],
            }
        )

    plan_obj: dict[str, Any] = {
        "planVersion": 1,
        "status": "planned",
        "createdAt": now_iso(),
        "mode": active_mode,
        "task": args.task,
        "repoPath": str(repo_path),
        "armoryRoot": str(armory_root),
        "manifestRef": manifest_ref,
        "shortlist": [row["id"] for row in shortlist],
        "loadout": dep_result["ids"],
        "dependencyMissing": dep_result["missing"],
        "loadoutEntries": loadout_entries,
        "refresh": {
            "success": refresh.success,
            "command": refresh.command,
            "output": refresh.output,
        },
        "approvalRequired": True,
        "approved": False,
        "approvedAt": None,
        "equip": {
            "installed": [],
            "failed": [],
            "installDir": "",
            "completedAt": None,
        },
    }

    plan_path = plan_target_path(args.plan_path, args.from_last_plan)
    write_json(plan_path, plan_obj)
    write_json(last_plan_path(), plan_obj)

    print_scout(active_mode, args.task, repo_context, shortlist, dep_result)
    print(f"Cart prepared: {', '.join(sorted(dep_result['ids']))}")
    print(f"Plan saved: {plan_path}")
    print("Approval required before equip. Run: quartermaster equip --from-last-plan --approve")
    return 0


def equip_action(args: argparse.Namespace, config: dict[str, Any], active_mode: str) -> int:
    plan_path = plan_target_path(args.plan_path, args.from_last_plan)
    try:
        plan = read_plan(plan_path)
    except RuntimeError as exc:
        print_failure(active_mode, "No plan available for equip.", str(exc))
        return 1

    if not args.approve:
        print_failure(
            active_mode,
            "Approval gate not satisfied.",
            "Re-run with --approve after explicit human approval.",
        )
        return 1

    plan_armory_root = expand_path(str(plan.get("armoryRoot", "")))
    if not plan_armory_root or not is_armory_root(plan_armory_root):
        print_failure(active_mode, "Plan Armory root is invalid.", str(plan.get("armoryRoot", "")))
        return 1

    install_dir = expand_path(str(config.get("installDir") or DEFAULT_INSTALL_DIR))
    if not install_dir:
        install_dir = Path(DEFAULT_INSTALL_DIR)
    install_dir.mkdir(parents=True, exist_ok=True)

    installed: list[str] = []
    failed: list[str] = []
    entry_map = {str(row.get("id")): row for row in plan.get("loadoutEntries", []) if isinstance(row, dict)}

    for tool_id in plan.get("loadout", []):
        tid = str(tool_id)
        entry = entry_map.get(tid)
        if not entry:
            failed.append(tid)
            continue
        entrypoint = entry.get("entrypointPath")
        if not isinstance(entrypoint, str) or not entrypoint:
            failed.append(tid)
            continue

        script_path = plan_armory_root / entrypoint
        if not script_path.exists():
            failed.append(tid)
            continue

        shim_path = install_dir / tid
        shim_body = "\n".join(
            [
                "#!/usr/bin/env bash",
                "set -euo pipefail",
                f'ARMORY_ROOT="{plan_armory_root}"',
                "export ARMORY_ROOT",
                f'exec "$ARMORY_ROOT/{entrypoint}" "$@"',
            ]
        )
        shim_path.write_text(shim_body + "\n", encoding="utf-8")
        shim_path.chmod(0o755)
        installed.append(tid)

    plan["status"] = "partial" if failed else "equipped"
    plan["approved"] = True
    plan["approvedAt"] = now_iso()
    plan["mode"] = active_mode
    plan["equip"] = {
        "installed": installed,
        "failed": failed,
        "installDir": str(install_dir),
        "completedAt": now_iso(),
    }

    write_json(plan_path, plan)
    write_json(last_plan_path(), plan)

    print_equip(active_mode, installed, failed, install_dir)
    if failed:
        print("Tactical report: partial equip complete, resolve failed IDs before continuing.")
        return 1
    return 0


def report_action(args: argparse.Namespace, active_mode: str) -> int:
    plan_path = plan_target_path(args.plan_path, args.from_last_plan)
    try:
        plan = read_plan(plan_path)
    except RuntimeError as exc:
        print_failure(active_mode, "No saved plan/report data.", str(exc))
        return 1

    report_mode = normalize_mode(plan.get("mode"), plan.get("civilianAliases"))
    installed = [str(x) for x in plan.get("equip", {}).get("installed", [])]
    failed = [str(x) for x in plan.get("equip", {}).get("failed", [])]

    print()
    if report_mode == "civ":
        print("Quartermaster status report")
        print("-------------------------")
        print(f"Status: {plan.get('status', 'unknown')}")
        print(f"Installed tool IDs: {', '.join(sorted(installed))}")
        if failed:
            print(f"Failed tool IDs: {', '.join(sorted(failed))}")
    else:
        print("Quartermaster field report")
        print("------------------------")
        print(f"Quest status: {plan.get('status', 'unknown')}")
        print(f"Equipped tool IDs: {', '.join(sorted(installed))}")
        if failed:
            print(f"Unresolved tool IDs: {', '.join(sorted(failed))}")

    armory_root = expand_path(str(plan.get("armoryRoot", "")))
    shadow_path = armory_root / "governance" / "seven-shadow-system" if armory_root else None
    if shadow_path and shadow_path.exists():
        print("Seven Shadow path detected. Run real shadow checks before final sign-off.")
    else:
        print("Seven Shadow path not found; reported and continuing with Armory-native checks.")

    print()
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Quartermaster (Mac runtime)")
    sub = parser.add_subparsers(dest="action", required=True)

    scout = sub.add_parser("scout", help="Scout recommended loadout")
    scout.add_argument("--task", required=True)
    scout.add_argument("--top", type=int, default=5)
    scout.add_argument("--repo-path", default=os.getcwd())
    scout.add_argument("--armory-root", default="")
    scout.add_argument("--mode", choices=["saga", "civ", "lore", "crystal"], default=None)

    plan = sub.add_parser("plan", help="Build dependency-aware plan")
    plan.add_argument("--task", required=True)
    plan.add_argument("--top", type=int, default=5)
    plan.add_argument("--repo-path", default=os.getcwd())
    plan.add_argument("--armory-root", default="")
    plan.add_argument("--plan-path", default="")
    plan.add_argument("--from-last-plan", action="store_true")
    plan.add_argument("--mode", choices=["saga", "civ", "lore", "crystal"], default=None)

    equip = sub.add_parser("equip", help="Equip plan (approval required)")
    equip.add_argument("--plan-path", default="")
    equip.add_argument("--from-last-plan", action="store_true")
    equip.add_argument("--approve", action="store_true")
    equip.add_argument("--mode", choices=["saga", "civ", "lore", "crystal"], default=None)

    report = sub.add_parser("report", help="Report plan outcome")
    report.add_argument("--plan-path", default="")
    report.add_argument("--from-last-plan", action="store_true")
    report.add_argument("--mode", choices=["saga", "civ", "lore", "crystal"], default=None)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    cfg_path = config_path()
    try:
        config = load_config(cfg_path)
    except Exception:
        config = {}

    repo_path = Path(getattr(args, "repo_path", os.getcwd())).expanduser().resolve()
    if not repo_path.exists():
        print_failure("civ", "RepoPath not found", str(repo_path))
        return 1

    try:
        armory_root = resolve_armory_root(getattr(args, "armory_root", ""), config)
    except Exception as exc:
        print_failure("civ", "Armory root resolution failed", str(exc))
        return 1

    active_mode = resolve_mode(getattr(args, "mode", None), config, repo_path)
    explicit_armory_root = getattr(args, "armory_root", "")
    if explicit_armory_root:
        ensure_config(path=cfg_path, mode=active_mode)
    else:
        ensure_config(path=cfg_path, repo_root=str(armory_root), mode=active_mode)

    top_value = max(1, int(getattr(args, "top", 5)))
    args.top = top_value

    if args.action == "scout":
        return scout_action(args, config, active_mode, armory_root, repo_path)
    if args.action == "plan":
        return plan_action(args, config, active_mode, armory_root, repo_path)
    if args.action == "equip":
        return equip_action(args, config, active_mode)
    if args.action == "report":
        return report_action(args, active_mode)

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
