#!/usr/bin/env bash
# Read-only bootstrap/discovery smoke tests. Does not invoke link or install.
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

checkout="$tmp/another location/my dotfiles"
mkdir -p "$checkout/common/bin/.local/bin" "$checkout/hosts/_template" "$tmp/home/.local/bin"
cp "$repo/common/bin/.local/bin/dot" "$checkout/common/bin/.local/bin/dot"
cp "$repo/install" "$checkout/install"
ln -s "$checkout/common/bin/.local/bin/dot" "$tmp/home/.local/bin/dot"

assert_checkout() {
  local got
  got=$(cd / && env -u DOTFILES HOME="$tmp/home" DOT_HOST=test-host "$1" cd 2>/dev/null)
  [ "$got" = "$checkout" ] || {
    printf 'wrong checkout: got %s, expected %s\n' "$got" "$checkout" >&2
    exit 1
  }
}

assert_checkout "$checkout/common/bin/.local/bin/dot"
assert_checkout "$tmp/home/.local/bin/dot"

# An explicit checkout override remains possible and is checked for validity.
actual=$(env HOME="$tmp/home" DOTFILES="$checkout" DOT_HOST=test-host "$tmp/home/.local/bin/dot" cd 2>/dev/null)
[ "$actual" = "$checkout" ]
if env HOME="$tmp/home" DOTFILES="$tmp/nonexistent" DOT_HOST=test-host "$tmp/home/.local/bin/dot" cd >/dev/null 2>&1; then
  echo 'invalid DOTFILES accepted' >&2
  exit 1
fi

for bad_host in ../outside _template '.' '..' ''; do
  # Empty DOT_HOST deliberately means using the system hostname; not invalid.
  [ -n "$bad_host" ] || continue
  if env -u DOTFILES HOME="$tmp/home" DOT_HOST="$bad_host" "$tmp/home/.local/bin/dot" cd >/dev/null 2>&1; then
    printf 'invalid host accepted: %s\n' "$bad_host" >&2
    exit 1
  fi
done

echo 'checkout discovery and host validation: OK'
