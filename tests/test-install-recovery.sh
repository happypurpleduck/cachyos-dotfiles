#!/usr/bin/env bash
# Disposable bootstrap failure injection. Never invokes a real package manager,
# user service, systemd system manager or /etc mutation.
set -euo pipefail
source_repo=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
checkout="$tmp/checkout with spaces"
home="$tmp/user-home"
fakebin="$tmp/fake-bin"
mkdir -p "$home" "$checkout/common/bin/.local/bin" "$checkout/hosts/A/home" "$checkout/scripts" "$checkout/packages/optional" "$fakebin"
cp "$source_repo/common/bin/.local/bin/dot" "$checkout/common/bin/.local/bin/dot"
cp "$source_repo/install" "$checkout/install"
chmod +x "$checkout/common/bin/.local/bin/dot"
cat > "$checkout/scripts/package-audit.py" <<'PY'
import sys
if "--json" in sys.argv:
    print('{"missing_aur":[]}')
else:
    print("mock packages ready")
PY
cat > "$checkout/scripts/dot-links.py" <<'PY'
from pathlib import Path
import sys
home = Path.home()
file = home / ".config/test-linked"
if "--dry-run" in sys.argv:
    print("Dry run: no files changed")
elif "--rollback" in sys.argv:
    file.unlink(missing_ok=True)
    (home / "rollback-invoked").write_text("yes")
    print("restored transaction")
else:
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text("new link for this test")
    print("applied; rollback with: dot rollback 20261123T000000Z-deadbeefcafe")
PY
cat > "$checkout/scripts/first-login.py" <<'PY'
import os
import sys
if os.environ.get("SIMULATE_THEME_FAIL") == "1":
    print("intentional theme failure", file=sys.stderr)
    raise SystemExit(1)
print("mock first-login complete")
PY
printf '#!/bin/sh\nexit 0\n' > "$checkout/scripts/fetch-assets"
chmod +x "$checkout/scripts/fetch-assets"
printf '#!/bin/sh\nexit 0\n' > "$fakebin/systemctl"
printf '#!/bin/sh\nexit 0\n' > "$fakebin/fc-cache"
chmod +x "$fakebin/systemctl" "$fakebin/fc-cache"
cat > "$checkout/hosts/A/setup" <<'SH'
#!/bin/sh
echo ran > "$HOME/host-setup-invoked"
SH
chmod +x "$checkout/hosts/A/setup"

dot="$checkout/common/bin/.local/bin/dot"
export HOME="$home"
export DOT_HOST=A
export PATH="$fakebin:$PATH"
unset DOTFILES
printf 'A\n' | "$dot" confirm-host >/dev/null 2>&1

# Theme generation failure follows a successful link transaction and must
# invoke its exact rollback, preserving a usable home directory.
if SIMULATE_THEME_FAIL=1 "$dot" install >"$tmp/output" 2>"$tmp/error"; then
    echo "installer reported success after a required theme failure" >&2
    exit 1
fi
grep -q 'managed link changes restored' "$tmp/error"
grep -q 'NOT automatically removed' "$tmp/error"
[ ! -e "$home/.config/test-linked" ]
[ "$(cat "$home/rollback-invoked")" = yes ]
[ ! -e "$home/host-setup-invoked" ]

# A successful retry must not run host scripts or change /etc automatically.
SIMULATE_THEME_FAIL=0 "$dot" install >"$tmp/output" 2>"$tmp/error"
[ "$(cat "$home/.config/test-linked")" = "new link for this test" ]
[ ! -e "$home/host-setup-invoked" ]
"$dot" host-setup >"$tmp/preview"
[ ! -e "$home/host-setup-invoked" ]
printf 'RUN HOST SETUP\n' | "$dot" host-setup --apply >/dev/null
[ "$(cat "$home/host-setup-invoked")" = ran ]

echo 'installer checkpoint rollback, retry and explicit host setup: OK'
