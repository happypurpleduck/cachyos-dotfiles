#!/usr/bin/env bash
# Host enrollment guard: local-only, explicit, required for mutation.
set -euo pipefail
repo=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
checkout="$tmp/dotfiles elsewhere"
home="$tmp/home"
mkdir -p "$home" "$checkout/common/bin/.local/bin" "$checkout/hosts/A/home" "$checkout/hosts/B/home"
cp "$repo/common/bin/.local/bin/dot" "$checkout/common/bin/.local/bin/dot"
cp "$repo/install" "$checkout/install"
chmod +x "$checkout/common/bin/.local/bin/dot"
git -C "$checkout" init -q
dotcmd="$checkout/common/bin/.local/bin/dot"

if env -u DOTFILES HOME="$home" DOT_HOST=A "$dotcmd" pull >"$tmp/err" 2>&1; then
  echo "unconfirmed profile was accepted" >&2; exit 1
fi
grep -q 'run dot confirm-host' "$tmp/err"
if printf 'B\n' | env -u DOTFILES HOME="$home" DOT_HOST=A "$dotcmd" confirm-host >"$tmp/err" 2>&1; then
  echo "incorrect confirmation succeeded" >&2; exit 1
fi
[ ! -e "$home/.local/state/cachyos-dotfiles/confirmed-host" ]
printf 'A\n' | env -u DOTFILES HOME="$home" DOT_HOST=A "$dotcmd" confirm-host >/dev/null 2>&1
state="$home/.local/state/cachyos-dotfiles/confirmed-host"
[ "$(cut -d: -f1 "$state")" = A ]
if env -u DOTFILES HOME="$home" DOT_HOST=B "$dotcmd" pull >"$tmp/err" 2>&1; then
  echo "different host was accepted" >&2; exit 1
fi
grep -q 'run dot confirm-host' "$tmp/err"
env -u DOTFILES HOME="$home" DOT_HOST=A "$dotcmd" pull >"$tmp/err" 2>&1 || true
! grep -q 'run dot confirm-host' "$tmp/err"
echo 'local machine/profile enrollment guards: OK'
