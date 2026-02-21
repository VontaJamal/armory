#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

run_assert() {
  local name="$1"
  shift
  echo "RUN $name"
  "$@"
  echo "PASS $name"
}

tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/armory-mac-smoke.XXXXXX")"
orig_home="${HOME}"

cleanup() {
  HOME="$orig_home"
  rm -rf "$tmp_home"
}
trap cleanup EXIT

export HOME="$tmp_home"

run_assert "setup civ" "$repo_root/setup.sh" --mode civ --command-word armory --install-dir "$HOME/.local/bin"

config_path="$HOME/.armory/config.json"
if [[ ! -f "$config_path" ]]; then
  echo "FAIL config file missing: $config_path"
  exit 1
fi

mode="$(python3 "$repo_root/scripts/lib/armory_config.py" get mode --path "$config_path")"
if [[ "$mode" != "civ" ]]; then
  echo "FAIL expected civ mode after setup, got: $mode"
  exit 1
fi

echo "PASS mode persisted as civ"

run_assert "civs status" "$repo_root/civs.sh" status
run_assert "dispatcher help" "$HOME/.local/bin/armory" help
run_assert "dispatcher remedy" "$HOME/.local/bin/armory" remedy --check config --check scripts
run_assert "dispatcher chronicle" "$HOME/.local/bin/armory" chronicle --repo-path "$repo_root" --format json

run_assert "switch saga" "$repo_root/civs.sh" off
mode="$(python3 "$repo_root/scripts/lib/armory_config.py" get mode --path "$config_path")"
if [[ "$mode" != "saga" ]]; then
  echo "FAIL expected saga mode after civs off, got: $mode"
  exit 1
fi

echo "PASS mode switched to saga"

echo "All mac smoke scenarios passed."
