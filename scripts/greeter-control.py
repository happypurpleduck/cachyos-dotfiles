#!/usr/bin/env python3
"""Safe, opt-in Quickshell greeter staging, activation and TTY rollback.

Never restarts a running display manager. Activation requires an explicit
confirmation token and refuses to replace SDDM/GDM/LightDM without separate
consent. Supports --root for isolated disposable-root tests.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import getpass
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import sys
import tempfile
from uuid import uuid4

UNITS = ("sddm.service", "gdm.service", "lightdm.service", "ly.service")
TX_ID = re.compile(r"^\d{8}T\d{6}Z-[a-f0-9]{12}$")


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}-{uuid4().hex[:8]}")
    try:
        tmp.write_text(json.dumps(value, indent=2) + "\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


def hash_tree(root: Path) -> str | None:
    if not root.is_dir():
        return None
    digest = hashlib.sha256()
    for p in sorted(root.rglob("*")):
        if p.is_symlink():
            raise ValueError(f"symlink in staged greeter: {p}")
        if p.is_file():
            digest.update(p.relative_to(root).as_posix().encode())
            digest.update(p.read_bytes())
    return digest.hexdigest()


def run_systemctl(cmd: str, *args: str, check=True) -> subprocess.CompletedProcess:
    return subprocess.run([cmd, *args], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True, check=check, timeout=30)


def present_display_manager(root: Path, ctl: str | None) -> list[str]:
    found: set[str] = set()
    display = root / "etc/systemd/system/display-manager.service"
    if display.is_symlink():
        target = display.resolve(strict=False).name
        if target != "greetd.service":
            found.add(target)
    if ctl:
        for unit in UNITS:
            for action in ("is-enabled", "is-active"):
                result = run_systemctl(ctl, action, unit, check=False)
                if result.returncode == 0:
                    found.add(unit)
    return sorted(found)


def check_prereqs(root: Path, source: Path, user: str) -> None:
    expected = [
        source / "core/Theme.qml",
        source / "components/StyledText.qml",
        source / "modules/lock/LockContent.qml",
        source / "greeter/shell.qml",
    ]
    missing = [str(p) for p in expected if not p.is_file()]
    if missing:
        raise ValueError("missing greeter source: " + ", ".join(missing))
    if root == Path("/"):
        for command in ("cage", "qs", "greetd", "start-hyprland"):
            if not shutil.which(command):
                raise ValueError(f"greeter requires {command}")
        try:
            pwd.getpwnam("greeter")
            pwd.getpwnam(user)
        except KeyError as exc:
            raise ValueError(f"missing required greetd account: {exc}") from exc
        if not (root / "etc/pam.d/greetd").is_file():
            raise ValueError("missing /etc/pam.d/greetd")


def stage(root: Path, source: Path, home: Path, user: str) -> Path:
    check_prereqs(root, source, user)
    parent = root / "etc/greetd"
    parent.mkdir(parents=True, exist_ok=True)
    dest = parent / "mocha-greeter-staged"
    temp = Path(tempfile.mkdtemp(prefix=".mocha-stage-", dir=parent))
    try:
        shutil.copytree(source / "core", temp / "core")
        shutil.copytree(source / "components", temp / "components")
        (temp / "modules/lock").mkdir(parents=True)
        shutil.copy2(source / "modules/lock/LockContent.qml",
                     temp / "modules/lock/LockContent.qml")
        shutil.copy2(source / "greeter/shell.qml", temp / "shell.qml")
        state_path = home / ".local/state/mocha-shell/theme.json"
        try:
            settings = json.loads(state_path.read_text())
        except (OSError, json.JSONDecodeError):
            settings = {"accent": "mauve", "mode": "auto"}
        picture = Path(settings.get("wallpaper") or "")
        if not picture.is_file():
            picture = home / ".local/state/mocha-shell/fallback.png"
        if picture.is_file():
            shutil.copy2(picture, temp / "wallpaper")
            wallpaper = "/etc/greetd/mocha-greeter/wallpaper"
        else:
            wallpaper = ""
        theme = {"accent": settings.get("accent", "mauve"),
                 "accentHex": settings.get("accentHex", "#cba6f7"),
                 "mode": settings.get("mode", "auto"),
                 "wallpaper": wallpaper}
        (temp / "theme.json").write_text(json.dumps(theme, indent=2))
        face = ""
        if (home / ".face").is_file():
            shutil.copy2(home / ".face", temp / "face")
            face = "/etc/greetd/mocha-greeter/face"
        (temp / "greeter.json").write_text(json.dumps({
            "user": user, "face": face, "session": ["start-hyprland"],
        }, indent=2))
        # Greeter must not need permission to read the owner's home.
        for file in temp.rglob("*"):
            if file.is_dir():
                file.chmod(0o755)
            elif file.is_file():
                file.chmod(0o644)
        if not (temp / "greeter.json").is_file() or hash_tree(temp) is None:
            raise ValueError("invalid greeter stage")
        if dest.exists():
            old = parent / f"mocha-greeter-staged.previous-{uuid4().hex[:12]}"
            os.replace(dest, old)
            print(f"previous staging retained: {old}")
        os.replace(temp, dest)
        print(f"greeter staged at {dest}; not activated")
        return dest
    finally:
        if temp.exists():
            shutil.rmtree(temp)


def current_config(root: Path) -> Path:
    return root / "etc/greetd/config.toml"


def build_config() -> str:
    return (
        "# Mocha greeter; recover through dot greeter --rollback TXID from TTY\n"
        "[terminal]\nvt = 1\n\n"
        "[default_session]\n"
        'command = "env MOCHA_THEME_FILE=/etc/greetd/mocha-greeter/theme.json '
        'XCURSOR_THEME=Adwaita XCURSOR_SIZE=24 QT_QPA_PLATFORM=wayland '
        'cage -s -m last -- qs -p /etc/greetd/mocha-greeter"\n'
        'user = "greeter"\n'
    )


def activate(root: Path, source: Path, home: Path, user: str, *,
             ctl: str | None, confirm: str | None, replace: bool) -> str:
    if confirm != "ACTIVATE greetd":
        raise ValueError("explicit --confirm 'ACTIVATE greetd' is required")
    check_prereqs(root, source, user)
    parent = root / "etc/greetd"
    staged = parent / "mocha-greeter-staged"
    if not staged.is_dir() or hash_tree(staged) is None:
        raise ValueError("stage and validate the greeter before activation")
    others = present_display_manager(root, ctl)
    if len(others) > 1:
        raise ValueError("multiple conflicting display managers: " + ", ".join(others))
    if others and not replace:
        raise ValueError(
            "existing display manager: " + ", ".join(others)
            + "; use --replace-display-manager only after reviewing recovery"
        )
    if not ctl:
        raise ValueError("systemctl is required for display-manager activation")
    root_backups = root / "var/backups/cachyos-dotfiles/greeter"
    root_backups.mkdir(parents=True, exist_ok=True)
    txid = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid4().hex[:12]
    backup = root_backups / txid
    backup.mkdir(mode=0o700)
    cfg = current_config(root)
    live = parent / "mocha-greeter"
    previous_cfg = cfg.read_bytes() if cfg.exists() else None
    if previous_cfg is not None:
        (backup / "config.toml.original").write_bytes(previous_cfg)
    if live.exists():
        shutil.copytree(live, backup / "mocha-greeter.original")
    journal = {"version": 1, "kind": "greeter", "id": txid,
               "user": user, "previous_dm": others[0] if others else None,
               "previous_config": previous_cfg is not None,
               "previous_live": live.exists(), "status": "started"}
    write_json(backup / "journal.json", journal)
    disabled = False
    try:
        if live.exists():
            old = parent / f".mocha-live-old-{uuid4().hex[:12]}"
            os.replace(live, old)
        else:
            old = None
        # Copying the complete staged tree avoids consuming staged fallback
        # assets that may be needed for disaster recovery.
        shutil.copytree(staged, live)
        if old is not None:
            shutil.rmtree(old)
        cfg.parent.mkdir(parents=True, exist_ok=True)
        tmp = cfg.with_name(f".config-{uuid4().hex[:12]}")
        tmp.write_text(build_config())
        os.chmod(tmp, 0o644)
        os.replace(tmp, cfg)
        if others:
            run_systemctl(ctl, "disable", others[0])
            disabled = True
        run_systemctl(ctl, "enable", "greetd.service")
        journal["active_config_sha256"] = hashlib.sha256(cfg.read_bytes()).hexdigest()
        journal["active_tree_sha256"] = hash_tree(live)
        journal["status"] = "active"
        write_json(backup / "journal.json", journal)
    except BaseException:
        # Restore configuration, old directory and enablement after failures.
        if previous_cfg is None:
            cfg.unlink(missing_ok=True)
        else:
            cfg.write_bytes(previous_cfg)
        if live.exists():
            shutil.rmtree(live)
        if (backup / "mocha-greeter.original").exists():
            shutil.copytree(backup / "mocha-greeter.original", live)
        if disabled:
            run_systemctl(ctl, "enable", others[0], check=False)
        run_systemctl(ctl, "disable", "greetd.service", check=False)
        raise
    print(f"greeter enabled for next boot; current session unchanged; rollback: dot greeter --rollback {txid}")
    return txid


def rollback(root: Path, txid: str, ctl: str) -> None:
    if not TX_ID.fullmatch(txid):
        raise ValueError("invalid greeter transaction id")
    backup = root / "var/backups/cachyos-dotfiles/greeter" / txid
    journal_file = backup / "journal.json"
    if not journal_file.is_file():
        raise ValueError("unknown greeter transaction")
    journal = json.loads(journal_file.read_text())
    if journal.get("kind") != "greeter" or journal.get("status") != "active":
        raise ValueError("transaction not active")
    cfg = current_config(root)
    live = root / "etc/greetd/mocha-greeter"
    if (not cfg.is_file() or
            hashlib.sha256(cfg.read_bytes()).hexdigest() != journal["active_config_sha256"]
            or hash_tree(live) != journal["active_tree_sha256"]):
        raise ValueError("greeter config/assets changed since activation; refusing to delete edits")
    run_systemctl(ctl, "disable", "greetd.service")
    if live.exists():
        shutil.rmtree(live)
    if journal["previous_live"]:
        shutil.copytree(backup / "mocha-greeter.original", live)
    if journal["previous_config"]:
        shutil.copy2(backup / "config.toml.original", cfg)
    else:
        cfg.unlink(missing_ok=True)
    if journal["previous_dm"]:
        run_systemctl(ctl, "enable", journal["previous_dm"])
    journal["status"] = "rolled_back"
    write_json(journal_file, journal)
    print(f"restored previous login configuration; reboot or switch DM from a TTY: {txid}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("/"))
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--source", type=Path)
    parser.add_argument("--user", default=os.environ.get("SUDO_USER") or getpass.getuser())
    parser.add_argument("--systemctl", default=shutil.which("systemctl"))
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--stage", action="store_true")
    actions.add_argument("--activate", action="store_true")
    actions.add_argument("--rollback", metavar="TXID")
    parser.add_argument("--replace-display-manager", action="store_true")
    parser.add_argument("--confirm")
    args = parser.parse_args()
    try:
        root = args.root.resolve(strict=True)
        home = args.home.expanduser().resolve(strict=True)
        source = (args.source or home / ".config/quickshell").resolve(strict=True)
        if root == Path("/") and (args.stage or args.activate or args.rollback):
            if os.geteuid() != 0 or not os.environ.get("SUDO_USER"):
                raise ValueError("use sudo from the intended account; no direct root activation")
        if args.stage:
            stage(root, source, home, args.user)
        elif args.activate:
            activate(root, source, home, args.user, ctl=args.systemctl,
                     confirm=args.confirm, replace=args.replace_display_manager)
        elif args.rollback:
            rollback(root, args.rollback, args.systemctl or "systemctl")
        else:
            check_prereqs(root, source, args.user)
            others = present_display_manager(root, args.systemctl)
            print("greeter preflight (read-only):")
            print("  source:", source)
            print("  active/enabled competing DM:", ", ".join(others) or "none")
            print("  stage path:", root / "etc/greetd/mocha-greeter-staged")
            print("  activation requires explicit --confirm 'ACTIVATE greetd'")
            print("  no running display manager will be restarted")
        return 0
    except (OSError, ValueError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
        print(f"greeter-control: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
