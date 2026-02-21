#!/usr/bin/env zsh
# ──────────────────────────────────────────────────────
# Jutsu — Named key vault + SSH-aware gateway restart
# Alpha release — zsh on macOS
# ──────────────────────────────────────────────────────

JUTSU_DIR="${HOME}/.jutsu"
VAULT_FILE="${JUTSU_DIR}/vault.json"
CONFIG_FILE="${JUTSU_DIR}/config"
VERSION="0.1.0"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; DIM='\033[0;90m'; NC='\033[0m'

banner() {
  echo ""
  echo "  ${CYAN}⚔️  Jutsu${NC} ${DIM}v${VERSION}${NC}"
  echo "  ${DIM}─────────────────────────────${NC}"
}

ensure_dirs() {
  [[ -d "$JUTSU_DIR" ]] || mkdir -p "$JUTSU_DIR"
  [[ -f "$VAULT_FILE" ]] || echo '{}' > "$VAULT_FILE"
  chmod 600 "$VAULT_FILE" 2>/dev/null
}

# ── Config ──────────────────────────────────────────────
load_config() {
  GATEWAY_HOST="local"
  GATEWAY_USER=""
  GATEWAY_METHOD="local"
  SSH_KEY=""
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
  fi
}

cmd_setup() {
  banner
  echo ""
  echo "  ${WHITE}Gateway Setup${NC}"
  echo ""
  echo "  Where does your OpenClaw gateway run?"
  echo "  ${DIM}(If it's this machine, just press Enter)${NC}"
  echo ""
  printf "  Gateway host [local]: "
  read host_input
  host_input="${host_input:-local}"

  if [[ "$host_input" == "local" || "$host_input" == "localhost" || "$host_input" == "127.0.0.1" ]]; then
    cat > "$CONFIG_FILE" <<EOF
GATEWAY_HOST="local"
GATEWAY_METHOD="local"
GATEWAY_USER=""
SSH_KEY=""
EOF
    echo ""
    echo "  ${GREEN}✓${NC} Gateway set to ${WHITE}local${NC}"
  else
    printf "  SSH user: "
    read user_input
    printf "  SSH key path ${DIM}(optional, press Enter to skip)${NC}: "
    read key_input

    cat > "$CONFIG_FILE" <<EOF
GATEWAY_HOST="${host_input}"
GATEWAY_METHOD="ssh"
GATEWAY_USER="${user_input}"
SSH_KEY="${key_input}"
EOF
    echo ""
    echo "  ${GREEN}✓${NC} Gateway set to ${WHITE}${user_input}@${host_input}${NC} via SSH"
  fi
  chmod 600 "$CONFIG_FILE" 2>/dev/null
  echo ""
}

# ── Vault Operations ────────────────────────────────────
vault_read() {
  cat "$VAULT_FILE"
}

vault_write() {
  echo "$1" > "$VAULT_FILE"
  chmod 600 "$VAULT_FILE" 2>/dev/null
}

encode_key() { echo -n "$1" | base64 }
decode_key() { echo "$1" | base64 -d 2>/dev/null || echo "$1" | base64 -D 2>/dev/null }

cmd_add() {
  local provider="$1" name="$2" key="$3"
  if [[ -z "$provider" || -z "$name" || -z "$key" ]]; then
    echo "  ${RED}Usage:${NC} jutsu add <provider> <name> <key>"
    echo "  ${DIM}Example: jutsu add anthropic work sk-ant-...${NC}"
    return 1
  fi

  local encoded=$(encode_key "$key")
  local vault=$(vault_read)
  local updated=$(echo "$vault" | python3 -c "
import sys, json
data = json.load(sys.stdin)
p = '$provider'
if p not in data: data[p] = {}
data[p]['$name'] = '$encoded'
print(json.dumps(data, indent=2))
")
  vault_write "$updated"
  echo "  ${GREEN}✓${NC} Added ${WHITE}${provider}/${name}${NC}"
}

cmd_list() {
  banner
  local vault=$(vault_read)
  local providers=$(echo "$vault" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for p in sorted(data):
    keys = data[p]
    print(f'  {p}')
    for k in sorted(keys):
        print(f'    • {k}')
" 2>/dev/null)

  if [[ -z "$providers" ]]; then
    echo ""
    echo "  ${DIM}Vault is empty. Add keys with: jutsu add <provider> <name> <key>${NC}"
  else
    echo ""
    echo "$providers"
  fi
  echo ""
}

cmd_remove() {
  local provider="$1" name="$2"
  if [[ -z "$provider" || -z "$name" ]]; then
    echo "  ${RED}Usage:${NC} jutsu remove <provider> <name>"
    return 1
  fi

  local vault=$(vault_read)
  local updated=$(echo "$vault" | python3 -c "
import sys, json
data = json.load(sys.stdin)
p, n = '$provider', '$name'
if p in data and n in data[p]:
    del data[p][n]
    if not data[p]: del data[p]
print(json.dumps(data, indent=2))
")
  vault_write "$updated"
  echo "  ${GREEN}✓${NC} Removed ${WHITE}${provider}/${name}${NC}"
}

# ── Gateway Restart ─────────────────────────────────────
restart_gateway() {
  load_config

  if [[ "$GATEWAY_METHOD" == "ssh" ]]; then
    local ssh_cmd="ssh"
    [[ -n "$SSH_KEY" ]] && ssh_cmd="ssh -i $SSH_KEY"
    local target="${GATEWAY_USER}@${GATEWAY_HOST}"

    echo "  ${DIM}Restarting gateway on ${target}...${NC}"

    # Try openclaw first, fall back to nssm/sc
    $ssh_cmd "$target" "openclaw gateway restart 2>/dev/null || nssm restart OpenClawGateway 2>/dev/null || sc stop OpenClawGateway && sc start OpenClawGateway" 2>&1

    if [[ $? -eq 0 ]]; then
      echo "  ${GREEN}✓${NC} Gateway restarted on ${WHITE}${GATEWAY_HOST}${NC}"
    else
      echo "  ${RED}✗${NC} Failed to restart gateway on ${GATEWAY_HOST}"
      echo "  ${DIM}Check SSH access: $ssh_cmd $target${NC}"
      return 1
    fi
  else
    echo "  ${DIM}Restarting local gateway...${NC}"
    openclaw gateway restart 2>/dev/null
    if [[ $? -eq 0 ]]; then
      echo "  ${GREEN}✓${NC} Gateway restarted locally"
    else
      echo "  ${RED}✗${NC} Failed to restart local gateway"
      return 1
    fi
  fi
}

# ── Swap ────────────────────────────────────────────────
cmd_swap() {
  local provider="$1" name="$2"
  if [[ -z "$provider" || -z "$name" ]]; then
    echo "  ${RED}Usage:${NC} jutsu swap <provider> <name>"
    echo "  ${DIM}Example: jutsu swap anthropic work${NC}"
    return 1
  fi

  local vault=$(vault_read)
  local encoded=$(echo "$vault" | python3 -c "
import sys, json
data = json.load(sys.stdin)
p, n = '$provider', '$name'
if p in data and n in data[p]:
    print(data[p][n])
" 2>/dev/null)

  if [[ -z "$encoded" ]]; then
    echo "  ${RED}✗${NC} Key ${WHITE}${provider}/${name}${NC} not found in vault"
    return 1
  fi

  local key=$(decode_key "$encoded")

  # Map provider to env var
  local env_var=""
  case "$provider" in
    anthropic) env_var="ANTHROPIC_API_KEY" ;;
    openai)    env_var="OPENAI_API_KEY" ;;
    google)    env_var="GOOGLE_API_KEY" ;;
    github)    env_var="GITHUB_TOKEN" ;;
    *)         env_var="$(echo $provider | tr '[:lower:]' '[:upper:]')_API_KEY" ;;
  esac

  # Export to current shell
  export "$env_var=$key"
  echo "  ${GREEN}✓${NC} Swapped ${WHITE}${env_var}${NC} → ${CYAN}${provider}/${name}${NC}"

  # Restart gateway
  echo ""
  restart_gateway
}

# ── Reload ──────────────────────────────────────────────
cmd_reload() {
  banner
  echo ""
  restart_gateway
  echo ""
}

# ── Help ────────────────────────────────────────────────
cmd_help() {
  banner
  echo ""
  echo "  ${WHITE}Commands:${NC}"
  echo ""
  echo "    ${CYAN}setup${NC}                         Configure gateway location"
  echo "    ${CYAN}add${NC} <provider> <name> <key>   Add a named key to the vault"
  echo "    ${CYAN}list${NC}                          Show all stored keys"
  echo "    ${CYAN}remove${NC} <provider> <name>      Remove a key"
  echo "    ${CYAN}swap${NC} <provider> <name>        Swap key + restart gateway"
  echo "    ${CYAN}reload${NC}                        Restart gateway (no key swap)"
  echo ""
  echo "  ${WHITE}Examples:${NC}"
  echo ""
  echo "    ${DIM}jutsu add anthropic work sk-ant-abc123...${NC}"
  echo "    ${DIM}jutsu add anthropic personal sk-ant-xyz789...${NC}"
  echo "    ${DIM}jutsu swap anthropic work${NC}"
  echo "    ${DIM}jutsu reload${NC}"
  echo ""
}

# ── Main ────────────────────────────────────────────────
ensure_dirs

case "${1:-help}" in
  setup)   cmd_setup ;;
  add)     cmd_add "$2" "$3" "$4" ;;
  list)    cmd_list ;;
  ls)      cmd_list ;;
  remove)  cmd_remove "$2" "$3" ;;
  rm)      cmd_remove "$2" "$3" ;;
  swap)    cmd_swap "$2" "$3" ;;
  reload)  cmd_reload ;;
  help)    cmd_help ;;
  --help)  cmd_help ;;
  -h)      cmd_help ;;
  *)       echo "  ${RED}Unknown command:${NC} $1"; cmd_help ;;
esac
