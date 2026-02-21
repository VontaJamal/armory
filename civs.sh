#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"
export ARMORY_REPO_ROOT="$repo_root"
# shellcheck source=scripts/lib/armory_common.sh
source "$repo_root/scripts/lib/armory_common.sh"

show_help() {
  cat <<'EOF'
Armory mode control

Usage:
  ./civs.sh
  ./civs.sh status
  ./civs.sh on
  ./civs.sh off
  ./civs.sh status --emit-flag
EOF
}

action="status"
emit_flag=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    on|off|status)
      action="$1"
      ;;
    --emit-flag)
      emit_flag=1
      ;;
    -h|--help|help)
      show_help
      exit 0
      ;;
    *)
      armory_fail "Unknown argument: $1"
      ;;
  esac
  shift

done

config_file="$(armory_config_path)"
if [[ ! -f "$config_file" ]]; then
  armory_fail "Missing Armory config: $config_file. Run ./awakening.sh first."
fi

case "$action" in
  on)
    armory_config_json set-mode civ >/dev/null
    armory_info "Civilian Mode enabled (mode=civ)."
    ;;
  off)
    armory_config_json set-mode saga >/dev/null
    armory_info "Crystal Saga Mode enabled (mode=saga)."
    ;;
  status)
    mode="$(armory_config_get mode saga)"
    if [[ "$mode" == "civ" ]]; then
      armory_info "Mode: Civilian (mode=civ)"
      armory_info "Civilian aliases are ON."
    else
      armory_info "Mode: Crystal Saga (mode=saga)"
      armory_info "Civilian aliases are OFF."
    fi
    ;;
esac

if [[ "$emit_flag" -eq 1 ]]; then
  mode="$(armory_config_get mode saga)"
  if [[ "$mode" == "civ" ]]; then
    printf "1\n"
  else
    printf "0\n"
  fi
fi
