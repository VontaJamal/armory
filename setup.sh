#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"
export ARMORY_REPO_ROOT="$repo_root"
# shellcheck source=scripts/lib/armory_common.sh
source "$repo_root/scripts/lib/armory_common.sh"

show_help() {
  cat <<'EOF'
Armory Setup (Mac runtime)

Usage:
  ./setup.sh
  ./setup.sh --mode civ
  ./setup.sh --mode saga
  ./setup.sh --mode civ --command-word armory
  ./setup.sh --install-dir ~/.local/bin
EOF
}

mode=""
command_word=""
install_dir="$(armory_user_home)/.local/bin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      [[ $# -ge 2 ]] || armory_fail "--mode requires civ or saga"
      mode="$2"
      shift
      ;;
    --command-word)
      [[ $# -ge 2 ]] || armory_fail "--command-word requires a value"
      command_word="$2"
      shift
      ;;
    --install-dir)
      [[ $# -ge 2 ]] || armory_fail "--install-dir requires a value"
      install_dir="$2"
      shift
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

armory_require_commands git python3

if [[ -z "$mode" ]]; then
  existing_mode="$(armory_config_get mode "")"
  if [[ -n "$existing_mode" ]]; then
    mode="$existing_mode"
  else
    cat <<'EOF'
Choose your onboarding path:
  1) Civilian Mode (plain language)
  2) Crystal Saga Mode (Receive the Crystal)
EOF
    read -r -p "Selection [1]: " choice
    if [[ "$choice" == "2" ]]; then
      mode="saga"
    else
      mode="civ"
    fi
  fi
fi

case "$mode" in
  civ|saga) ;;
  lore|crystal)
    mode="saga"
    ;;
  *)
    armory_fail "Invalid mode '$mode'. Expected civ or saga."
    ;;
esac

if [[ -z "$command_word" ]]; then
  if [[ "$mode" == "civ" ]]; then
    command_word="armory"
  else
    command_word="crystal"
  fi
fi

if [[ "$mode" == "civ" ]]; then
  armory_info "Civilian onboarding selected."
else
  armory_info "Crystal Saga onboarding selected."
fi

"$repo_root/awakening.sh" --command-word "$command_word" --install-dir "$install_dir"

if [[ "$mode" == "civ" ]]; then
  "$repo_root/civs.sh" on
else
  "$repo_root/civs.sh" off
fi
