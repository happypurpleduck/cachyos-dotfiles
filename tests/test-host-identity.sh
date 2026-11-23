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
# Unsafe names must be rejected before touching hosts/ or parent folders.
for bad in '../other' 'nested/host' '..' '_template'; do
  if env -u DOTFILES HOME="$home" DOT_HOST=A "$dotcmd" new-host "$bad" >"$tmp/err" 2>&1; then
    echo "unsafe host name accepted: $bad" >&2; exit 1
  fi
  grep -Eq 'invalid hostname|reserved host' "$tmp/err"
done
[ ! -e "$checkout/other" ] && [ ! -e "$checkout/hosts/nested" ]

# Explicit PAM/DDC setup must not bypass this host's enrollment.
mkdir -p "$checkout/system" "$tmp/fakebin"
printf '#!/bin/sh\necho system-setup >> "$ACTION_LOG"\n' > "$checkout/system/setup"
printf '#!/bin/sh\necho sudo >> "$ACTION_LOG"\nexec "$@"\n' > "$tmp/fakebin/sudo"
chmod +x "$checkout/system/setup" "$tmp/fakebin/sudo"
export ACTION_LOG="$tmp/mutations"
export PATH="$tmp/fakebin:$PATH"
if env -u DOTFILES HOME="$home" DOT_HOST=B "$dotcmd" system-setup --apply >"$tmp/err" 2>&1; then
  echo "unconfirmed profile invoked privileged setup" >&2; exit 1
fi
[ ! -e "$ACTION_LOG" ]
env -u DOTFILES HOME="$home" DOT_HOST=B "$dotcmd" system-setup --dry-run >/dev/null
env -u DOTFILES HOME="$home" DOT_HOST=A "$dotcmd" system-setup --apply
[ "$(grep -c '^sudo' "$ACTION_LOG")" -eq 1 ]

echo 'host enrollment, name validation and privileged system setup: OK'
