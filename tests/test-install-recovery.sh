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
# An unselected optional group must not interrupt ordinary installation.
printf '# Optional app\nmock-optional\n' > "$checkout/packages/optional/extra.txt"
chmod +x "$checkout/common/bin/.local/bin/dot"
cat > "$checkout/scripts/package-audit.py" <<'PY'
import sys
import os
from pathlib import Path
if "--install" in sys.argv:
    (Path.home() / "package-install-invoked").write_text("yes")
    if os.environ.get("SIMULATE_AUR_REQUIRED") == "1":
        assert "--approve-aur" in sys.argv and "--non-interactive" in sys.argv, sys.argv
        (Path.home() / "auto-aur-invoked").write_text("yes")
if "--json" in sys.argv:
    print('{"missing_aur":["google-chrome"]}' if os.environ.get("SIMULATE_AUR_REQUIRED") == "1" else '{"missing_aur":[]}')
else:
    print("mock packages ready")
PY
cat > "$checkout/scripts/dot-links.py" <<'PY'
from pathlib import Path
import os
import sys
home = Path.home()
file = home / ".config/test-linked"
if "--install-preflight" in sys.argv:
    if os.environ.get("SIMULATE_UNSAFE_TARGET") == "1":
        print("BLOCKED: unsafe parent", file=sys.stderr)
        raise SystemExit(2)
    if os.environ.get("SIMULATE_EXISTING_CONFIG") == "1":
        print("Link preflight: 2 existing home config files conflict")
        raise SystemExit(3)
    print("Link preflight: no collisions")
elif "--dry-run" in sys.argv:
    print("Dry run: no files changed")
elif os.environ.get("SIMULATE_LINK_FAIL") == "1":
    print("injected linker failure", file=sys.stderr)
    raise SystemExit(2)
elif "--rollback" in sys.argv:
    file.unlink(missing_ok=True)
    (home / "rollback-invoked").write_text("yes")
    print("restored transaction")
else:
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text("new link for this test")
    if "--backup-conflicts" in sys.argv:
        (home / "backup-consent-passed").write_text("yes")
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
cat > "$checkout/scripts/upstream-apps.py" <<'PY'
from pathlib import Path
import os
import sys
home = Path.home()
if "status" in sys.argv:
    print("mise: missing; zed: missing (read-only)")
elif "install" in sys.argv:
    assert sys.argv[-2:] == ["mise", "zed"], sys.argv
    if os.environ.get("SIMULATE_UPSTREAM_FAIL") == "1":
        print("injected first-party app failure", file=sys.stderr)
        raise SystemExit(2)
    (home / "upstream-apps-invoked").write_text("mise zed")
    print("mise and zed installed from first-party installers")
PY
printf '#!/bin/sh\nexit 0\n' > "$checkout/scripts/fetch-assets"
chmod +x "$checkout/scripts/fetch-assets"
cat > "$fakebin/systemctl" <<'SH'
#!/bin/sh
# This fixture tracks actual is-enabled state; do not touch systemd.
case "$1 $2" in
  "--user is-enabled") grep -qx "$4" "$UNIT_STATE" 2>/dev/null ;;
  "--user enable") grep -qx "$3" "$UNIT_STATE" 2>/dev/null || echo "$3" >> "$UNIT_STATE" ;;
  "--user disable") sed -i "\|^$3$|d" "$UNIT_STATE" ;;
  *) exit 0 ;;
esac
SH
cat > "$fakebin/sudo" <<'SH'
#!/bin/sh
case "$*" in
  *"scripts/greeter-control.py"* )
    echo "$*" >> "$HOME/greeter-invoked"
    [ "${SIMULATE_GREETER_FAIL:-0}" = 1 ] && exit 1
    echo "greeter enabled for next boot; current session unchanged; rollback: dot greeter --rollback 20261123T000001Z-cafecafecafe"
    exit 0 ;;
esac
echo "$*" >> "$HOME/sudo-invoked"
exit 1
SH
printf '#!/bin/sh\nexit 0\n' > "$fakebin/fc-cache"
chmod +x "$fakebin/systemctl" "$fakebin/fc-cache" "$fakebin/sudo"
cat > "$checkout/hosts/A/setup" <<'SH'
#!/bin/sh
echo ran > "$HOME/host-setup-invoked"
SH
chmod +x "$checkout/hosts/A/setup"

dot="$checkout/common/bin/.local/bin/dot"
export HOME="$home"
export DOT_HOST=A
export PATH="$fakebin:$PATH"
export UNIT_STATE="$tmp/enabled-units"
: > "$UNIT_STATE"
unset DOTFILES
printf 'A\n' | "$dot" confirm-host >/dev/null 2>&1

# Unsafe targets fail before package installation.
if SIMULATE_UNSAFE_TARGET=1 "$dot" install >"$tmp/output" 2>"$tmp/error"; then
  echo "unsafe target accepted" >&2; exit 1
fi
grep -q 'unsafe home configuration targets' "$tmp/error"
[ ! -e "$home/package-install-invoked" ]
[ ! -e "$home/.config/test-linked" ]

# Dry run previews automatic backups without installing anything.
SIMULATE_EXISTING_CONFIG=1 "$dot" install --dry-run </dev/null >"$tmp/output" 2>"$tmp/error"
grep -q '2 existing home config' "$tmp/output"
grep -q 'Dry run: no files changed' "$tmp/output"
[ ! -e "$home/package-install-invoked" ]
[ ! -e "$home/.config/test-linked" ]

# Stock home config collisions are automatically backed up, without stdin.
SIMULATE_EXISTING_CONFIG=1 "$dot" install </dev/null >"$tmp/output" 2>"$tmp/error"
grep -q '2 existing home config' "$tmp/output"
grep -q 'backed up automatically' "$tmp/output"
[ "$(cat "$home/backup-consent-passed")" = yes ]
[ -e "$home/package-install-invoked" ]
[ -e "$home/.config/test-linked" ]
rm -f "$home/backup-consent-passed" "$home/package-install-invoked" "$home/.config/test-linked"

# A linker failure must remain fatal despite Bash conditional errexit rules.
if SIMULATE_LINK_FAIL=1 "$dot" install >"$tmp/output" 2>"$tmp/error"; then
    echo "installer reported success after injected linker failure" >&2; exit 1
fi
grep -q 'managed link transaction failed' "$tmp/error"
[ ! -e "$home/.config/test-linked" ]
! grep -q 'install complete' "$tmp/output"

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

# A failed first-party app bootstrap is not reported as successful: installed
# upstream apps are user-local, but managed links and newly enabled units recover.
if SIMULATE_UPSTREAM_FAIL=1 "$dot" install >"$tmp/output" 2>"$tmp/error"; then
  echo "upstream installer failure was swallowed" >&2; exit 1
fi
grep -q 'installation stopped during: self-managed application bootstrap' "$tmp/error"
[ ! -e "$home/.config/test-linked" ]

# A greeter activation failure also triggers managed-link recovery.
if SIMULATE_GREETER_FAIL=1 "$dot" install >"$tmp/output" 2>"$tmp/error"; then
  echo "failed greeter activation was accepted" >&2; exit 1
fi
grep -q 'installation stopped during: Mocha greeter staging/activation' "$tmp/error"
grep -q 'managed link changes restored' "$tmp/error"
[ ! -e "$home/.config/test-linked" ]
! grep -q 'install complete' "$tmp/output"

# A successful retry must not run host scripts or change /etc automatically.
SIMULATE_THEME_FAIL=0 "$dot" install >"$tmp/output" 2>"$tmp/error"
[ "$(cat "$home/.config/test-linked")" = "new link for this test" ]
[ "$(cat "$home/upstream-apps-invoked")" = "mise zed" ]
grep -q 'Mocha greeter ready (next boot)' "$tmp/output"
grep -q -- '--install' "$home/greeter-invoked"
[ ! -e "$checkout/hosts/A/optional.txt" ]
[ ! -e "$home/host-setup-invoked" ]
"$dot" host-setup >"$tmp/preview"
[ ! -e "$home/host-setup-invoked" ]
printf 'RUN HOST SETUP\n' | "$dot" host-setup --apply >/dev/null
[ "$(cat "$home/host-setup-invoked")" = ran ]

# A later privileged-phase failure must undo only newly enabled user units.
: > "$UNIT_STATE"
if "$dot" install --apply-system >"$tmp/output" 2>"$tmp/error"; then
    echo "system-setup failure must fail installation" >&2; exit 1
fi
grep -q 'restored initially disabled user unit: hokum.service' "$tmp/error"
! grep -qx 'hokum.service' "$UNIT_STATE"
! grep -qx 'gnome-keyring-daemon.socket' "$UNIT_STATE"
[ -f "$home/sudo-invoked" ]

# An already-enabled user service must survive the same failure.
printf 'hokum.service\n' > "$UNIT_STATE"
if "$dot" install --apply-system >"$tmp/output" 2>"$tmp/error"; then
    echo "system-setup failure must fail installation" >&2; exit 1
fi
grep -qx 'hokum.service' "$UNIT_STATE"
! grep -qx 'gnome-keyring-daemon.socket' "$UNIT_STATE"

# Allowlisted AUR packages are installed without a second typed approval.
SIMULATE_AUR_REQUIRED=1 "$dot" install </dev/null >"$tmp/output" 2>"$tmp/error"
[ "$(cat "$home/auto-aur-invoked")" = yes ]
grep -q 'installing declared AUR exceptions via Shelly: google-chrome' "$tmp/output"
[ ! -e "$checkout/hosts/A/optional.txt" ]

# Repeat installation with stock config collisions succeeds noninteractively.
SIMULATE_EXISTING_CONFIG=1 "$dot" install </dev/null >"$tmp/output" 2>"$tmp/error"
[ "$(cat "$home/backup-consent-passed")" = yes ]
grep -q '2 existing home config' "$tmp/output"
[ -e "$home/package-install-invoked" ]

echo 'installer checkpoint rollback, first-party apps, greeter enablement and host setup: OK'
