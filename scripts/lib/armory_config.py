#!/usr/bin/env python3
"""Shared Armory config helpers for shell/Python runtimes."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

DEFAULT_INSTALL_DIR = str(Path.home() / ".local" / "bin")


def config_path(explicit: str | None = None) -> Path:
    if explicit:
        return Path(explicit).expanduser()
    return Path.home() / ".armory" / "config.json"


def normalize_mode(raw: Any, civilian_aliases: Any | None = None) -> str:
    value = str(raw or "").strip().lower()
    if value == "civ":
        return "civ"
    if value in {"saga", "lore", "crystal"}:
        return "saga"
    if civilian_aliases is True:
        return "civ"
    return "saga"


def _coerce_str(value: Any, fallback: str) -> str:
    if isinstance(value, str) and value.strip():
        return value
    return fallback


def _load_raw(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(parsed, dict):
        raise ValueError(f"config must be a JSON object: {path}")
    return parsed


def migrate_config(data: dict[str, Any]) -> dict[str, Any]:
    cfg = dict(data)
    mode = normalize_mode(cfg.get("mode"), cfg.get("civilianAliases"))

    cfg["mode"] = mode
    cfg["civilianAliases"] = mode == "civ"
    cfg["commandWord"] = _coerce_str(cfg.get("commandWord"), "armory")
    cfg["installDir"] = _coerce_str(cfg.get("installDir"), DEFAULT_INSTALL_DIR)

    repo_root = cfg.get("repoRoot")
    if isinstance(repo_root, str) and repo_root.strip():
        cfg["repoRoot"] = str(Path(repo_root).expanduser())

    return cfg


def load_config(path: Path) -> dict[str, Any]:
    return migrate_config(_load_raw(path))


def save_config(path: Path, data: dict[str, Any]) -> dict[str, Any]:
    cfg = migrate_config(data)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cfg, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    return cfg


def ensure_config(
    *,
    path: Path,
    command_word: str | None = None,
    install_dir: str | None = None,
    repo_root: str | None = None,
    mode: str | None = None,
) -> dict[str, Any]:
    cfg = load_config(path)

    if command_word:
        cfg["commandWord"] = command_word
    if install_dir:
        cfg["installDir"] = str(Path(install_dir).expanduser())
    if repo_root:
        cfg["repoRoot"] = str(Path(repo_root).expanduser())
    if mode is not None:
        cfg["mode"] = normalize_mode(mode, cfg.get("civilianAliases"))

    cfg.setdefault("commandWord", "armory")
    cfg.setdefault("installDir", DEFAULT_INSTALL_DIR)
    cfg.setdefault("mode", "saga")

    cfg["mode"] = normalize_mode(cfg.get("mode"), cfg.get("civilianAliases"))
    cfg["civilianAliases"] = cfg["mode"] == "civ"

    return save_config(path, cfg)


def _print_value(value: Any) -> int:
    if value is None:
        return 1
    if isinstance(value, bool):
        print("true" if value else "false")
        return 0
    if isinstance(value, (dict, list)):
        print(json.dumps(value, indent=2, sort_keys=True))
        return 0
    print(str(value))
    return 0


def _cmd_show(args: argparse.Namespace) -> int:
    try:
        cfg = load_config(config_path(args.path))
    except ValueError as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 1
    print(json.dumps(cfg, indent=2, sort_keys=False))
    return 0


def _cmd_get(args: argparse.Namespace) -> int:
    try:
        cfg = load_config(config_path(args.path))
    except ValueError as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 1

    value = cfg.get(args.key, args.default)
    return _print_value(value)


def _cmd_ensure(args: argparse.Namespace) -> int:
    try:
        cfg = ensure_config(
            path=config_path(args.path),
            command_word=args.command_word,
            install_dir=args.install_dir,
            repo_root=args.repo_root,
            mode=args.mode,
        )
    except ValueError as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 1

    print(json.dumps(cfg, indent=2, sort_keys=False))
    return 0


def _cmd_set_mode(args: argparse.Namespace) -> int:
    try:
        cfg = ensure_config(path=config_path(args.path), mode=args.mode)
    except ValueError as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 1

    print(cfg["mode"])
    return 0


def _cmd_normalize_mode(args: argparse.Namespace) -> int:
    print(normalize_mode(args.value, args.civilian_aliases))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Armory config helper")
    sub = parser.add_subparsers(dest="command", required=True)

    show = sub.add_parser("show", help="Print normalized config JSON")
    show.add_argument("--path", default="", help="Override config path")
    show.set_defaults(func=_cmd_show)

    get = sub.add_parser("get", help="Read a config value")
    get.add_argument("key")
    get.add_argument("--default", default=None)
    get.add_argument("--path", default="", help="Override config path")
    get.set_defaults(func=_cmd_get)

    ensure = sub.add_parser("ensure", help="Upsert canonical config")
    ensure.add_argument("--command-word", default="")
    ensure.add_argument("--install-dir", default="")
    ensure.add_argument("--repo-root", default="")
    ensure.add_argument("--mode", default=None)
    ensure.add_argument("--path", default="", help="Override config path")
    ensure.set_defaults(func=_cmd_ensure)

    set_mode = sub.add_parser("set-mode", help="Set mode and civilianAliases")
    set_mode.add_argument("mode", choices=["saga", "civ", "lore", "crystal"])
    set_mode.add_argument("--path", default="", help="Override config path")
    set_mode.set_defaults(func=_cmd_set_mode)

    normalize = sub.add_parser("normalize-mode", help="Normalize mode value")
    normalize.add_argument("value")
    normalize.add_argument("--civilian-aliases", action="store_true")
    normalize.set_defaults(func=_cmd_normalize_mode)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
