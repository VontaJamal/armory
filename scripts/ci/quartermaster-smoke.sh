#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
quartermaster="$repo_root/items/quartermaster/quartermaster.sh"

if [[ ! -x "$quartermaster" ]]; then
  echo "Missing executable quartermaster script: $quartermaster"
  exit 1
fi

run_qm() {
  set +e
  QM_OUT="$("$quartermaster" "$@" 2>&1)"
  QM_RC=$?
  set -e
}

assert_exit() {
  local name="$1"
  local expected="$2"
  if [[ "$QM_RC" -ne "$expected" ]]; then
    echo "Scenario failed: $name"
    echo "  expected: $expected"
    echo "  actual:   $QM_RC"
    if [[ -n "$QM_OUT" ]]; then
      echo "  output:"
      echo "$QM_OUT"
    fi
    exit 1
  fi
  echo "PASS $name (exit $expected)"
}

tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/armory-quartermaster-smoke.XXXXXX")"
orig_home="${HOME}"

cleanup() {
  HOME="$orig_home"
  rm -rf "$tmp_home" "$problem_repo"
}
trap cleanup EXIT

export HOME="$tmp_home"

problem_repo="$(mktemp -d "$HOME/quartermaster-problem.XXXXXX")"
discovered_armory="$HOME/Documents/Code Repos/armory"
mkdir -p "$(dirname "$discovered_armory")"

if command -v git >/dev/null 2>&1; then
  git clone "$repo_root" "$discovered_armory" >/dev/null
  rsync -a --exclude '.git' "$repo_root/" "$discovered_armory/"
  discovered_branch="$(git -C "$discovered_armory" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "$discovered_branch" && "$discovered_branch" != "HEAD" ]]; then
    git -C "$discovered_armory" branch --set-upstream-to="origin/$discovered_branch" "$discovered_branch" >/dev/null 2>&1 || true
  fi
else
  echo "git is required for quartermaster smoke tests"
  exit 1
fi

cp -R "$repo_root/tests/fixtures/quartermaster/problem-repo/." "$problem_repo/"

if command -v git >/dev/null 2>&1; then
  git -C "$problem_repo" init >/dev/null
  git -C "$problem_repo" config user.email "fixtures@armory.local"
  git -C "$problem_repo" config user.name "Armory Fixtures"
  git -C "$problem_repo" add . >/dev/null
  git -C "$problem_repo" commit -m "fixture: quartermaster baseline" >/dev/null
fi

pushd "$problem_repo" >/dev/null

run_qm scout --task "release diagnostics and repo status" --repo-path "$problem_repo" --top 2
assert_exit "quartermaster discovery scout" 0

config_path="$HOME/.armory/config.json"
if [[ ! -f "$config_path" ]]; then
  echo "Scenario failed: config file not created by discovery"
  exit 1
fi

saved_repo_root="$(python3 "$repo_root/scripts/lib/armory_config.py" get repoRoot --path "$config_path")"
expected_repo_root="$(python3 - "$discovered_armory" <<'PY'
import os
import sys
print(os.path.realpath(os.path.expanduser(sys.argv[1])))
PY
)"
if [[ "$saved_repo_root" != "$expected_repo_root" ]]; then
  echo "Scenario failed: resolved repoRoot mismatch"
  echo "  expected: $expected_repo_root"
  echo "  actual:   $saved_repo_root"
  exit 1
fi

echo "PASS quartermaster saved repoRoot"

fake_armory="$HOME/fake-armory"
mkdir -p "$fake_armory/shop" "$fake_armory/docs/data"
cp "$repo_root/awakening.sh" "$fake_armory/awakening.sh"
cp "$repo_root/shop/catalog.json" "$fake_armory/shop/catalog.json"
cp "$repo_root/docs/data/armory-manifest.v1.json" "$fake_armory/docs/data/armory-manifest.v1.json"

run_qm scout --task "release checks" --repo-path "$problem_repo" --armory-root "$fake_armory"
assert_exit "quartermaster pull failure" 1

run_qm plan --task "release diagnostics" --repo-path "$problem_repo" --top 2
assert_exit "quartermaster plan" 0

last_plan="$HOME/.armory/quartermaster/last-plan.json"
if [[ ! -f "$last_plan" ]]; then
  echo "Scenario failed: last-plan.json not created"
  exit 1
fi

loadout_count="$(python3 - "$last_plan" <<'PY'
import json,sys
obj=json.load(open(sys.argv[1]))
print(len(obj.get('loadout',[])))
PY
)"
if [[ "$loadout_count" -lt 1 ]]; then
  echo "Scenario failed: plan loadout is empty"
  exit 1
fi

echo "PASS plan loadout generated"

run_qm equip --from-last-plan
assert_exit "quartermaster equip approval gate" 1

run_qm equip --from-last-plan --approve
assert_exit "quartermaster equip approved" 0

install_dir="$(python3 - "$last_plan" <<'PY'
import json,sys
obj=json.load(open(sys.argv[1]))
print(obj.get('equip',{}).get('installDir',''))
PY
)"
if [[ -z "$install_dir" || ! -d "$install_dir" ]]; then
  echo "Scenario failed: install directory missing after equip"
  exit 1
fi

first_installed="$(python3 - "$last_plan" <<'PY'
import json,sys
obj=json.load(open(sys.argv[1]))
installed=obj.get('equip',{}).get('installed',[])
print(installed[0] if installed else '')
PY
)"
if [[ -z "$first_installed" || ! -x "$install_dir/$first_installed" ]]; then
  echo "Scenario failed: expected executable shim missing: $install_dir/$first_installed"
  exit 1
fi

echo "PASS equip created executable shims"

python3 - "$last_plan" <<'PY'
import json,sys
path=sys.argv[1]
obj=json.load(open(path))
obj['mode']='civ'
json.dump(obj, open(path,'w'), indent=2)
print()
PY

run_qm report --from-last-plan
assert_exit "quartermaster civ report" 0
if ! grep -q "Quartermaster status report" <<<"$QM_OUT"; then
  echo "Scenario failed: civ report wording mismatch"
  exit 1
fi

python3 - "$last_plan" <<'PY'
import json,sys
path=sys.argv[1]
obj=json.load(open(path))
obj['mode']='saga'
json.dump(obj, open(path,'w'), indent=2)
print()
PY

run_qm report --from-last-plan
assert_exit "quartermaster saga report" 0
if ! grep -q "Quartermaster field report" <<<"$QM_OUT"; then
  echo "Scenario failed: saga report wording mismatch"
  exit 1
fi

rm -f "$last_plan"
run_qm report --from-last-plan
assert_exit "quartermaster missing plan" 1

popd >/dev/null

echo "All quartermaster smoke scenarios passed."
