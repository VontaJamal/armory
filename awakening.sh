#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"
export ARMORY_REPO_ROOT="$repo_root"
# shellcheck source=scripts/lib/armory_common.sh
source "$repo_root/scripts/lib/armory_common.sh"

show_help() {
  cat <<'EOF'
Awakening (Mac runtime)

Usage:
  ./awakening.sh
  ./awakening.sh --command-word crystal
  ./awakening.sh --command-word armory --install-dir ~/.local/bin

Notes:
- Default command word prompt suggests: crystal
- Default install dir: ~/.local/bin
EOF
}

command_word=""
install_dir="$(armory_user_home)/.local/bin"

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ -z "$command_word" ]]; then
  printf "Receive the Crystal and begin the journey.\n"
  read -r -p "Command word [crystal]: " entered
  command_word="${entered:-crystal}"
fi

if ! armory_validate_command_word "$command_word"; then
  armory_fail "Invalid command word '$command_word'. Use letters, numbers, and dashes only."
fi

install_dir="$(armory_resolve_path "$install_dir")"
mkdir -p "$install_dir"

shim_path="$install_dir/$command_word"
cat > "$shim_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
ARMORY_ROOT="$repo_root"
export ARMORY_ROOT
exec "\$ARMORY_ROOT/bin/armory-dispatch" "\$@"
EOF
chmod +x "$shim_path"

existing_mode="$(armory_config_get mode saga)"
if [[ -z "$existing_mode" ]]; then
  existing_mode="saga"
fi

armory_config_json ensure \
  --command-word "$command_word" \
  --install-dir "$install_dir" \
  --repo-root "$repo_root" \
  --mode "$existing_mode" >/dev/null

armory_ensure_zsh_path "$install_dir"

cat <<EOF

Awakening complete.
Command word: $command_word
Wrapper:      $shim_path
Config:       $(armory_config_path)

Try:
  $command_word help
  $command_word quartermaster scout --task "repo readiness"
EOF
