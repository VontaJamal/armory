#!/usr/bin/env bash

set -euo pipefail

armory_dispatch_help() {
  local command_word="$1"
  cat <<EOF
Armory dispatcher (Mac runtime)

Usage:
  $command_word help
  $command_word civs status
  $command_word quartermaster scout --task "<task>"

Ported commands:
  civs, setup, awakening, quartermaster, remedy, chronicle, alexander, shop

Civilian aliases (only when mode=civ):
  status, repo-status, health, gate, preflight, catalog
EOF
}

armory_alias_target() {
  local cmd="$1"
  case "$cmd" in
    status|repo-status)
      printf "chronicle\n"
      ;;
    health)
      printf "remedy\n"
      ;;
    gate|preflight)
      printf "alexander\n"
      ;;
    catalog)
      printf "shop\n"
      ;;
    *)
      printf "\n"
      ;;
  esac
}

armory_is_known_but_unported() {
  local cmd="$1"
  case "$cmd" in
    list|forge|materia-forge|rename|rename-word|doctor|esuna|reload|swap|masamune|bahamut|ifrit|odin|ramuh|shiva|phoenix-down|save-point|aegis|sentinel|scan|truesight|deep-scan|libra|cure|protect|regen|bard)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

armory_print_shop_catalog() {
  local repo_root="$1"
  python3 - "$repo_root" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
catalog = root / "shop" / "catalog.json"
obj = json.loads(catalog.read_text(encoding="utf-8"))
print("Armory shop catalog (active):")
for entry in obj.get("entries", []):
    if entry.get("status") != "active":
        continue
    display = (entry.get("display") or {}).get("civ") or {}
    name = display.get("name") or entry.get("id")
    print(f"- {entry.get('id')} :: {name}")
PY
}

armory_dispatch_route() {
  local repo_root="$1"
  local command_word="$2"
  local mode="$3"
  local cmd="$4"
  shift 4

  case "$cmd" in
    ""|help)
      armory_dispatch_help "$command_word"
      ;;
    civs)
      exec "$repo_root/civs.sh" "$@"
      ;;
    setup)
      exec "$repo_root/setup.sh" "$@"
      ;;
    awakening|init)
      exec "$repo_root/awakening.sh" "$@"
      ;;
    quartermaster)
      exec "$repo_root/items/quartermaster/quartermaster.sh" "$@"
      ;;
    remedy)
      exec "$repo_root/items/remedy/remedy.sh" "$@"
      ;;
    chronicle)
      exec "$repo_root/spells/chronicle/chronicle.sh" "$@"
      ;;
    alexander)
      exec "$repo_root/summons/alexander/alexander.sh" "$@"
      ;;
    shop)
      armory_print_shop_catalog "$repo_root"
      ;;
    *)
      local alias_target
      alias_target="$(armory_alias_target "$cmd")"
      if [[ -n "$alias_target" ]]; then
        if [[ "$mode" != "civ" ]]; then
          printf "Civilian aliases are OFF in Crystal Saga Mode. Run: %s civs on\n" "$command_word" >&2
          return 1
        fi
        armory_dispatch_route "$repo_root" "$command_word" "$mode" "$alias_target" "$@"
        return $?
      fi

      if armory_is_known_but_unported "$cmd"; then
        printf "Command '%s' is not yet ported to Mac runtime.\n" "$cmd" >&2
        printf "Use one of: remedy, chronicle, alexander, quartermaster, civs.\n" >&2
        return 1
      fi

      printf "Unknown command: %s\n" "$cmd" >&2
      armory_dispatch_help "$command_word"
      return 1
      ;;
  esac
}
