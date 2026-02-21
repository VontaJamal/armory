#!/usr/bin/env bash

set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "WARN: git not found; skipping remote credential check"
  exit 0
fi

remote_lines="$(git remote -v 2>/dev/null || true)"
if [[ -z "$remote_lines" ]]; then
  echo "WARN: no git remotes found to inspect"
  exit 0
fi

if echo "$remote_lines" | grep -E 'https?://[^/@[:space:]]+:[^@[:space:]]+@' >/dev/null 2>&1; then
  echo "ERROR: credentialed remote URL detected"
  echo "$remote_lines" | sed -E 's#://([^:@[:space:]]+):[^@[:space:]]+@#://\1:***@#g'
  exit 1
fi

echo "OK remote URLs do not expose embedded credentials"
