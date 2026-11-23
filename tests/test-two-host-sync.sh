#!/usr/bin/env bash
# Non-destructive two-clone Git synchronization tests; no host install/link.
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

git init -q --bare "$tmp/remote.git"
git init -q -b main "$tmp/seed"
mkdir -p "$tmp/seed/common/bin/.local/bin" "$tmp/seed/common/demo/.config/demo"
mkdir -p "$tmp/seed/hosts/A/home/.config/demo" "$tmp/seed/hosts/B/home/.config/demo"
cp "$repo/common/bin/.local/bin/dot" "$tmp/seed/common/bin/.local/bin/dot"
cp "$repo/install" "$tmp/seed/install"
printf 'shared base\n' >"$tmp/seed/common/demo/.config/demo/settings.conf"
printf 'host A base\n' >"$tmp/seed/hosts/A/home/.config/demo/only.conf"
printf 'host B base\n' >"$tmp/seed/hosts/B/home/.config/demo/only.conf"
git -C "$tmp/seed" config user.name CI
git -C "$tmp/seed" config user.email ci@example.invalid
git -C "$tmp/seed" add -A
git -C "$tmp/seed" commit -qm base
git -C "$tmp/seed" remote add origin "$tmp/remote.git"
git -C "$tmp/seed" push -q -u origin main

git clone -q -b main "$tmp/remote.git" "$tmp/A"
git clone -q -b main "$tmp/remote.git" "$tmp/B"
for host in A B; do
  git -C "$tmp/$host" config user.name CI
  git -C "$tmp/$host" config user.email ci@example.invalid
  mkdir -p "$tmp/home-$host"
done

dot_for() {
  local host=$1
  shift
  env -u DOTFILES HOME="$tmp/home-$host" DOT_HOST="$host" \
    "$tmp/$host/common/bin/.local/bin/dot" "$@" 2>"$tmp/log-$host"
}
settings='common/demo/.config/demo/settings.conf'

# Common and host-specific tracked changes from A; untracked private data
# must not leave this clone.
printf 'shared from A\n' >"$tmp/A/$settings"
printf 'host A edited\n' >"$tmp/A/hosts/A/home/.config/demo/only.conf"
printf 'private token\n' >"$tmp/A/common/demo/.config/demo/local-token"
dot_for A save "A updates"
if git --git-dir="$tmp/remote.git" cat-file -e "main:common/demo/.config/demo/local-token" 2>/dev/null; then
  echo 'dot save unexpectedly published an untracked file' >&2
  exit 1
fi
dot_for B pull
[ "$(cat "$tmp/B/$settings")" = "shared from A" ]
[ "$(cat "$tmp/B/hosts/A/home/.config/demo/only.conf")" = "host A edited" ]
printf 'host B edited\n' >"$tmp/B/hosts/B/home/.config/demo/only.conf"
dot_for B save "B updates"
dot_for A pull
[ "$(cat "$tmp/A/hosts/B/home/.config/demo/only.conf")" = "host B edited" ]

# An ordinary save may not publish the other host's tracked edits.
printf 'unapproved edit\n' >"$tmp/A/hosts/B/home/.config/demo/only.conf"
if dot_for A save "should refuse"; then
  echo 'dot save accepted other-host edits' >&2
  exit 1
fi
git -C "$tmp/A" restore -- hosts/B/home/.config/demo/only.conf

# Explicitly staging a maintenance file is possible with --allow-staged.
printf 'notes\n' >"$tmp/A/NOTES.md"
git -C "$tmp/A" add NOTES.md
if dot_for A save "should refuse staged file"; then
  echo 'dot save silently accepted staged out-of-scope file' >&2
  exit 1
fi
dot_for A save --allow-staged "deliberately publish notes"
git --git-dir="$tmp/remote.git" cat-file -e main:NOTES.md

# Diff works outside the checkout (and is scoped to this host).
printf 'shared prospective conflict A\n' >"$tmp/A/$settings"
(cd / && dot_for A diff) >"$tmp/diff"
grep -q 'shared prospective conflict A' "$tmp/diff"
dot_for A save "A shared conflict"
printf 'shared prospective conflict B\n' >"$tmp/B/$settings"
if dot_for B save "B shared conflict"; then
  echo 'dot save silently overwrote a conflicting shared change' >&2
  exit 1
fi
# Rebase conflict must remain locally recoverable and the remote must retain A.
[ "$(git --git-dir="$tmp/remote.git" show "main:$settings")" = "shared prospective conflict A" ]
git -C "$tmp/B" rebase --abort
[ "$(git -C "$tmp/B" show "HEAD:$settings")" = "shared prospective conflict B" ]

echo 'two-host sync scope, safety and conflict tests: OK'
