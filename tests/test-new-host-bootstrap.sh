#!/usr/bin/env bash
# Fresh-host setup with the actual installer and dot CLI, no shelly/sudo/links.
set -euo pipefail
source_repo=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
checkout="$tmp/non-default checkout"
home="$tmp/brand-new-home"
mkdir -p "$checkout/common/bin/.local/bin" "$checkout/hosts" "$home"
cp "$source_repo/install" "$checkout/install"
cp "$source_repo/common/bin/.local/bin/dot" "$checkout/common/bin/.local/bin/dot"
cp -a "$source_repo/hosts/_template" "$checkout/hosts/_template"
chmod +x "$checkout/install" "$checkout/common/bin/.local/bin/dot"
export HOME="$home" DOT_HOST=husain-parcel
unset DOTFILES
cd "$checkout"
# A first install creates the host profile without prompting, before dot is installed.
./install --prepare-host </dev/null >"$tmp/output" 2>&1
[ -f "$checkout/hosts/husain-parcel/home/.config/hypr/host.lua" ]
grep -q 'creating hosts/husain-parcel' "$tmp/output"
grep -q 'host prepared' "$tmp/output"
[ ! -e "$home/.local/bin/dot" ]
[ ! -e "$home/.config/hypr/host.lua" ]

# A returning host is idempotent and does not recreate the profile.
echo 'local edit' >> "$checkout/hosts/husain-parcel/README.md"
./install --prepare-host </dev/null >"$tmp/output" 2>&1
! grep -q 'creating hosts' "$tmp/output"
grep -q 'local edit' "$checkout/hosts/husain-parcel/README.md"
echo 'first-install bootstrap creates the host profile without prompts: OK'
