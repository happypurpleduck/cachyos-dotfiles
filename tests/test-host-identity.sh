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
# Privileged system/service actions must require the same enrolled profile,
# regardless of argument order; previews remain available to unconfirmed hosts.
mkdir -p "$checkout/system" "$checkout/scripts" "$tmp/fake-bin"
cat > "$checkout/system/setup" <<'SH'
#!/bin/sh
echo "system setup $*" >> "$ACTION_LOG"
SH
chmod +x "$checkout/system/setup"
cat > "$checkout/scripts/host-services.py" <<'PY'
import subprocess
import sys
if "--apply" in sys.argv:
    subprocess.run(["sudo", "true"], check=True)
else:
    print("services preview")
PY
cat > "$tmp/fake-bin/sudo" <<'SH'
#!/bin/sh
echo "sudo $*" >> "$ACTION_LOG"
exec "$@"
SH
chmod +x "$tmp/fake-bin/sudo"
export ACTION_LOG="$tmp/actions"
export PATH="$tmp/fake-bin:$PATH"
for command in system-setup services; do
    if [ "$command" = services ]; then
        args=(--confirm 'ENABLE HOST SERVICES' --apply)
    else
        args=(--apply)
    fi
    if env -u DOTFILES HOME="$home" DOT_HOST=B "$dotcmd" "$command" "${args[@]}" >"$tmp/err" 2>&1; then
        echo "unconfirmed $command mutated machine" >&2; exit 1
    fi
    grep -q 'run dot confirm-host' "$tmp/err"
    [ ! -e "$ACTION_LOG" ]
done
# Both valid ordering forms must also require enrollment.
if env -u DOTFILES HOME="$home" DOT_HOST=B "$dotcmd" services --apply --confirm 'ENABLE HOST SERVICES' >"$tmp/err" 2>&1; then
    echo "unconfirmed services first-argument form bypassed enrollment" >&2; exit 1
fi
[ ! -e "$ACTION_LOG" ]
env -u DOTFILES HOME="$home" DOT_HOST=B "$dotcmd" system-setup --dry-run >/dev/null
env -u DOTFILES HOME="$home" DOT_HOST=A "$dotcmd" system-setup --apply
env -u DOTFILES HOME="$home" DOT_HOST=A "$dotcmd" services --confirm 'ENABLE HOST SERVICES' --apply
env -u DOTFILES HOME="$home" DOT_HOST=A "$dotcmd" services --apply --confirm 'ENABLE HOST SERVICES'
[ "$(grep -c '^sudo ' "$ACTION_LOG")" -eq 3 ]

for bad in '../other' 'foo/bar' '..'; do
    if env -u DOTFILES HOME="$home" DOT_HOST=A "$dotcmd" new-host "$bad" >"$tmp/err" 2>&1; then
        echo "unsafe hostname accepted: $bad" >&2; exit 1
    fi
    grep -Eq 'invalid hostname|reserved host' "$tmp/err"
done
[ ! -e "$checkout/other" ] && [ ! -e "$checkout/hosts/foo" ]

echo 'host enrollment, privileged consent orderings and new-host validation: OK'
