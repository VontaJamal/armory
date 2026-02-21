#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
export ARMORY_REPO_ROOT="$repo_root"

exec python3 "$repo_root/spells/chronicle/chronicle.py" "$@"
