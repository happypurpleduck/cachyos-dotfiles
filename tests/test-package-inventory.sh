#!/usr/bin/env bash
# Capture observed package state but never rewrite managed host requirements.
set -euo pipefail
source_repo=$(cd -- "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
repo="$tmp/checkout"
home="$tmp/home"
bin="$tmp/bin"
mkdir -p "$repo/common/bin/.local/bin" "$repo/hosts/A/home" "$repo/packages" "$home" "$bin"
cp "$source_repo/common/bin/.local/bin/dot" "$repo/common/bin/.local/bin/dot"
touch "$repo/install"
printf 'git\n' > "$repo/packages/common.txt"
printf 'hokum-bin\n' > "$repo/packages/aur.txt"
printf 'firefox\n' > "$repo/hosts/A/packages.txt"
printf 'google-chrome\n' > "$repo/hosts/A/aur.txt"
cat > "$bin/shelly" <<'SH'
#!/bin/sh
case "$*" in
  "list standard --explicitOnly --names-only")
    printf 'git\nfirefox\nzed\nsome-tool\ngoogle-chrome\nunapproved-aur\nmise\n' ;;
  "list aur --explicitOnly --names-only") printf 'google-chrome\nunapproved-aur\nmise\n' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$bin/shelly" "$repo/common/bin/.local/bin/dot"
export HOME="$home" DOT_HOST=A PATH="$bin:$PATH"
unset DOTFILES
before_repo=$(sha256sum "$repo/hosts/A/packages.txt")
before_foreign=$(sha256sum "$repo/hosts/A/aur.txt")
"$repo/common/bin/.local/bin/dot" packages >"$tmp/observed" 2>"$tmp/warnings"
grep -q 'some-tool' "$tmp/observed"
grep -q 'unapproved-aur' "$tmp/observed"
grep -q 'mise/Zed already package-managed' "$tmp/warnings"
[ "$(sha256sum "$repo/hosts/A/packages.txt")" = "$before_repo" ]
[ "$(sha256sum "$repo/hosts/A/aur.txt")" = "$before_foreign" ]
! grep -q unapproved-aur "$repo/hosts/A/aur.txt"
# AUR packages are reported once, as foreign, not again as repository extras.
[ "$(grep -c unapproved-aur "$tmp/observed")" -eq 1 ]
echo 'read-only package inventory leaves reviewed requirements untouched: OK'
