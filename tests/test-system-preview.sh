#!/usr/bin/env bash
# Verify previews and default system setup cannot mutate /etc on CI.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

home="$tmp/home"
checkout="$tmp/checkout"
mkdir -p "$home" "$checkout/common/bin/.local/bin" "$checkout/hosts/A"
cp "$repo/common/bin/.local/bin/dot" "$checkout/common/bin/.local/bin/dot"
mkdir -p "$checkout/system" "$checkout/common"
cp "$repo/system/setup" "$checkout/system/setup"
cp "$repo/install" "$checkout/install"
chmod +x "$checkout/system/setup" "$checkout/common/bin/.local/bin/dot"

before=$(find "$home" -mindepth 1 | wc -l)
result=$(env HOME="$home" DOT_HOST=A "$checkout/system/setup")
[[ "$result" == *"read-only system setup preview"* ]]
result=$(env HOME="$home" DOT_HOST=A "$checkout/common/bin/.local/bin/dot" system-setup)
[[ "$result" == *"read-only system setup preview"* ]]
result=$(env HOME="$home" DOT_HOST=A "$checkout/common/bin/.local/bin/dot" system-setup --dry-run)
[[ "$result" == *"read-only system setup preview"* ]]

if [ "$(id -u)" -ne 0 ]; then
  if env HOME="$home" DOT_HOST=A "$checkout/system/setup" --apply >"$tmp/output" 2>&1; then
    echo "system/setup allowed a non-root apply" >&2
    exit 1
  fi
fi
after=$(find "$home" -mindepth 1 | wc -l)
[ "$before" -eq "$after" ] || { echo "preview created files in HOME" >&2; exit 1; }
echo "system setup is opt-in and previews are read-only: OK"
