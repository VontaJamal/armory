#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${ARMORY_REPO_ROOT:-}" ]]; then
  echo "ARMORY_REPO_ROOT is required before sourcing armory_common.sh" >&2
  exit 1
fi

armory_info() {
  printf "%s\n" "$*"
}

armory_warn() {
  printf "WARN: %s\n" "$*" >&2
}

armory_fail() {
  printf "ERROR: %s\n" "$*" >&2
  exit 1
}

armory_require_commands() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    armory_fail "Missing required command(s): ${missing[*]}. Install them and retry."
  fi
}

armory_user_home() {
  printf "%s\n" "${HOME}"
}

armory_config_path() {
  printf "%s\n" "$(armory_user_home)/.armory/config.json"
}

armory_quartermaster_last_plan() {
  printf "%s\n" "$(armory_user_home)/.armory/quartermaster/last-plan.json"
}

armory_resolve_path() {
  local raw="${1:-}"
  python3 - "$raw" <<'PY'
import os
import sys

raw = sys.argv[1]
if not raw:
    print("")
    raise SystemExit(0)

expanded = os.path.expanduser(os.path.expandvars(raw))
print(os.path.abspath(expanded))
PY
}

armory_config_json() {
  python3 "${ARMORY_REPO_ROOT}/scripts/lib/armory_config.py" "$@"
}

armory_config_get() {
  local key="$1"
  local default_value="${2:-}"
  if [[ -n "$default_value" ]]; then
    armory_config_json get "$key" --default "$default_value" 2>/dev/null || true
  else
    armory_config_json get "$key" 2>/dev/null || true
  fi
}

armory_is_armory_root() {
  local target="${1:-}"
  [[ -n "$target" ]] || return 1
  [[ -d "$target" ]] || return 1
  [[ -f "$target/awakening.sh" ]] || return 1
  [[ -f "$target/shop/catalog.json" ]] || return 1
}

armory_validate_command_word() {
  local value="${1:-}"
  [[ "$value" =~ ^[a-zA-Z][a-zA-Z0-9-]{1,20}$ ]]
}

armory_ensure_zsh_path() {
  local install_dir="$1"
  local zshrc="$(armory_user_home)/.zshrc"
  local marker_begin="# >>> armory path >>>"
  local marker_end="# <<< armory path <<<"
  local tmp

  touch "$zshrc"
  tmp="$(mktemp)"

  awk -v begin="$marker_begin" -v end="$marker_end" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "$zshrc" > "$tmp"

  {
    cat "$tmp"
    printf "\n%s\n" "$marker_begin"
    printf "export PATH=\"%s:\$PATH\"\n" "$install_dir"
    printf "%s\n" "$marker_end"
  } > "$zshrc"

  rm -f "$tmp"

  case ":${PATH}:" in
    *":${install_dir}:"*) ;;
    *) export PATH="${install_dir}:${PATH}" ;;
  esac

  if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
    tmux set-environment -g PATH "$PATH" || true
    armory_warn "tmux session PATH updated. Open a new pane/window if command resolution lags."
  fi
}
