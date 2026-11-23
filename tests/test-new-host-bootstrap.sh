#!/usr/bin/env bash
# Fresh-host setup with the actual installer and dot CLI, no pacman/sudo/links.
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
state="$home/.local/state/cachyos-dotfiles/confirmed-host"

# Without explicit consent, noninteractive bootstrap must refuse to mutate.
if ./install --prepare-host </dev/null >"$tmp/output" 2>&1; then
  echo "unapproved host creation was accepted" >&2
  exit 1
fi
[ ! -e "$checkout/hosts/husain-parcel" ]
[ ! -e "$state" ]

# A declined first-install proposal must not create files.
printf 'n\n' | ./install --prepare-host >"$tmp/output" 2>&1 && {
  echo "declined bootstrap was accepted" >&2; exit 1;
}
[ ! -e "$checkout/hosts/husain-parcel" ]

# Typed creation + actual machine confirmation work before dot is installed.
printf 'y\nhusain-parcel\n' | ./install --prepare-host >"$tmp/output" 2>&1
[ -f "$checkout/hosts/husain-parcel/home/.config/hypr/host.lua" ]
[ -f "$state" ]
grep -q '^husain-parcel:' "$state"
grep -q 'host prepared' "$tmp/output"
[ ! -e "$home/.local/bin/dot" ]
[ ! -e "$home/.config/hypr/host.lua" ]

# A returning host is idempotent; no new confirmation prompts.
./install --prepare-host </dev/null >"$tmp/output" 2>&1
grep -q 'already confirmed' "$tmp/output"
[ "$(grep -c '^husain-parcel:' "$state")" -eq 1 ]

# Profile changes still require explicit human confirmation.
mkdir -p "$checkout/hosts/another-host/home"
if DOT_HOST=another-host ./install --prepare-host </dev/null >"$tmp/output" 2>&1; then
  echo "different host profile silently enrolled" >&2; exit 1
fi
grep -q '^husain-parcel:' "$state"
echo 'first-install bootstrap, refusal and idempotent confirmation: OK'
