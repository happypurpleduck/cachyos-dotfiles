#!/usr/bin/env python3
"""Greeter staging/display-manager rollback tests; fake /etc and fake systemctl."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
script = repo / "scripts/greeter-control.py"
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    fake = root / "fake-root"
    home = root / "home"
    src = home / ".config/quickshell"
    home.mkdir()
    for path in (
        "core/Theme.qml", "components/StyledText.qml",
        "modules/lock/LockContent.qml", "greeter/shell.qml",
    ):
        file = src / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text("import QtQuick\n")
    state = home / ".local/state/mocha-shell"
    state.mkdir(parents=True)
    (state / "theme.json").write_text(json.dumps({"accent": "blue",
        "accentHex": "#89b4fa", "mode": "auto", "wallpaper": "/invalid/path"}))
    fallback = state / "fallback.png"
    fallback.write_bytes(b"\x89PNG\r\n\x1a\n" + b"valid enough for staged fixture")
    cfg = fake / "etc/greetd/config.toml"
    cfg.parent.mkdir(parents=True)
    cfg.write_text("old greetd config\n")
    dm = fake / "etc/systemd/system/display-manager.service"
    dm.parent.mkdir(parents=True)
    dm.symlink_to("../sddm.service")
    service_state = root / "service-state"
    service_state.write_text("sddm.service\n")
    calls = root / "calls"
    sh = root / "mock-systemctl"
    sh.write_text(
        "#!/bin/sh\n"
        "printf '%s\\n' \"$*\" >> \"$MOCK_CALLS\"\n"
        "cmd=\"$1\"; unit=\"$2\"\n"
        "case \"$cmd\" in\n"
        "  is-enabled|is-active)\n"
        "    grep -qx \"$unit\" \"$MOCK_SERVICES\" && exit 0 || exit 1 ;;\n"
        "  enable) printf '%s\\n' \"$unit\" > \"$MOCK_SERVICES\"; if [ \"${MOCK_FAIL_GREETD:-0}\" = 1 ] && [ \"$unit\" = greetd.service ]; then exit 1; fi; ln -sfn \"../$unit\" \"$MOCK_DM_LINK\"; exit 0 ;;\n"
        "  disable) sed -i \"/^$unit$/d\" \"$MOCK_SERVICES\"; [ \"$(readlink \"$MOCK_DM_LINK\" 2>/dev/null)\" = \"../$unit\" ] && rm -f \"$MOCK_DM_LINK\"; exit 0 ;;\n"
        "esac\nexit 2\n"
    )
    sh.chmod(0o755)
    env = {**os.environ, "MOCK_CALLS": str(calls),
           "MOCK_SERVICES": str(service_state), "MOCK_DM_LINK": str(dm)}

    def run(*args, good=True):
        result = subprocess.run(
            [sys.executable, str(script), "--root", str(fake),
             "--home", str(home), "--source", str(src),
             "--user", "fakeuser", "--systemctl", str(sh), *args],
            env=env, capture_output=True, text=True,
        )
        assert (result.returncode == 0) == good, (
            args, result.stdout, result.stderr
        )
        return result

    def mutations() -> list[str]:
        return [line for line in calls.read_text().splitlines()
                if line.startswith(("enable ", "disable ", "restart ", "start ", "stop "))] if calls.exists() else []

    before = cfg.read_bytes()
    report = run()
    assert "sddm.service" in report.stdout
    assert cfg.read_bytes() == before and not mutations()
    staged = run("--stage")
    stage = fake / "etc/greetd/mocha-greeter-staged"
    assert stage.is_dir()
    # greetd runs qs as the greeter user; a 0700 root makes shell.qml unfindable.
    assert stage.stat().st_mode & 0o777 == 0o755, oct(stage.stat().st_mode)
    assert (stage / "shell.qml").is_file()
    assert (stage / "wallpaper").read_bytes() == fallback.read_bytes()
    assert json.loads((stage / "theme.json").read_text())["accentHex"] == "#89b4fa"
    assert cfg.read_bytes() == before and not mutations()

    run("--activate", "--confirm", "ACTIVATE greetd", good=False)
    run("--activate", "--confirm", "ACTIVATE greetd",
        "--replace-display-manager", good=True)
    # Live running login wasn't restarted; enablement switches on next boot.
    assert "restart" not in calls.read_text()
    assert "disable sddm.service" in calls.read_text()
    assert "enable greetd.service" in calls.read_text()
    live = fake / "etc/greetd/mocha-greeter"
    assert live.is_dir() and live.joinpath("shell.qml").is_file()
    assert live.stat().st_mode & 0o777 == 0o755, oct(live.stat().st_mode)
    assert 'command = "/etc/greetd/mocha-greeter/start"' in cfg.read_text()
    launcher = live / "start"
    assert launcher.stat().st_mode & 0o777 == 0o755, oct(launcher.stat().st_mode)

    # Hybrid GPU: cage must be pinned to the boot_vga card, not the iGPU,
    # and connector entries (card1-DP-1) must be skipped.
    sysfs = root / "sysfs-drm"
    for card, vga in (("card1", "0"), ("card2", "1")):
        (sysfs / card / "device").mkdir(parents=True)
        (sysfs / card / "device/boot_vga").write_text(vga + "\n")
    (sysfs / "card1-DP-1").mkdir()
    bindir = root / "fakebin"
    bindir.mkdir()
    (bindir / "systemd-cat").write_text('#!/bin/sh\nshift 2\nexec "$@"\n')
    (bindir / "cage").write_text(
        '#!/bin/sh\nprintf "%s|%s|%s\\n" "$WLR_DRM_DEVICES" '
        '"$MOCHA_THEME_FILE" "$*"\n')
    for f in bindir.iterdir():
        f.chmod(0o755)
    def launch(**extra):
        e = {"PATH": f"{bindir}:/usr/bin:/bin", "MOCHA_DRM_SYSFS": str(sysfs), **extra}
        return subprocess.run(["sh", str(launcher)], env=e, capture_output=True,
                              text=True, check=True).stdout.strip()
    assert launch() == ("/dev/dri/card2|/etc/greetd/mocha-greeter/theme.json|"
                        "-s -m last -- qs -p /etc/greetd/mocha-greeter"), launch()
    # Without a boot_vga card, wlroots keeps its default device selection.
    (sysfs / "card2/device/boot_vga").write_text("0\n")
    assert launch().startswith("|"), launch()
    backups = list((fake / "var/backups/cachyos-dotfiles/greeter").glob("*/journal.json"))
    assert len(backups) == 1, backups
    txid = backups[0].parent.name

    cfg.write_text("manual user edit\n")
    run("--rollback", txid, good=False)
    assert cfg.read_text() == "manual user edit\n"
    cfg.write_text(
        "# Mocha greeter; recover through dot greeter --rollback TXID from TTY\n"
        "[terminal]\nvt = 1\n\n"
        "[default_session]\n"
        'command = "/etc/greetd/mocha-greeter/start"\n'
        'user = "greeter"\n'
    )
    run("--rollback", txid)
    assert cfg.read_bytes() == before
    assert "enable sddm.service" in calls.read_text()
    assert "restart" not in calls.read_text()
    assert not live.exists()

    # Updating an existing greetd must never turn off the only login manager.
    dm.unlink(missing_ok=True)
    service_state.write_text("greetd.service\n")
    cfg.write_text("existing greetd config\n")
    prior = cfg.read_bytes()
    env["MOCK_FAIL_GREETD"] = "1"
    run("--activate", "--confirm", "ACTIVATE greetd", good=False)
    env.pop("MOCK_FAIL_GREETD")
    assert service_state.read_text().strip() == "greetd.service"
    assert cfg.read_bytes() == prior

    # Successful reactivation followed by explicit rollback also keeps greetd.
    run("--activate", "--confirm", "ACTIVATE greetd")
    journals = sorted((fake / "var/backups/cachyos-dotfiles/greeter").glob("*/journal.json"))
    current = [j for j in journals if json.loads(j.read_text())["status"] == "active"]
    assert len(current) == 1
    journal = json.loads(current[0].read_text())
    assert journal["previous_greetd_enabled"] is True
    assert journal["previous_greetd_active"] is True
    run("--rollback", current[0].parent.name)
    assert service_state.read_text().strip() == "greetd.service"
    assert cfg.read_bytes() == prior


    # Default full-desktop reconciliation switches SDDM at next boot while
    # preserving its state for rollback, and is repeatable without toggling DMs.
    service_state.write_text("sddm.service\n")
    dm.unlink(missing_ok=True)
    dm.symlink_to("../sddm.service")
    cfg.write_text("stock greeter config\n")
    env["MOCK_FAIL_GREETD"] = "1"
    run("--install", good=False)
    env.pop("MOCK_FAIL_GREETD")
    assert service_state.read_text().strip() == "sddm.service"
    assert cfg.read_text() == "stock greeter config\n"
    assert not live.exists()
    first = run("--install")
    assert "greeter enabled for next boot" in first.stdout
    assert service_state.read_text().strip() == "greetd.service"
    active_journals = [
        p for p in (fake / "var/backups/cachyos-dotfiles/greeter").glob("*/journal.json")
        if json.loads(p.read_text())["status"] == "active"
    ]
    assert len(active_journals) == 1
    before_mutations = mutations()
    again = run("--install")
    assert "greeter already configured" in again.stdout
    assert mutations() == before_mutations, "repeat install switched DMs"
    assert len([p for p in (fake / "var/backups/cachyos-dotfiles/greeter").glob("*/journal.json")
                if json.loads(p.read_text())["status"] == "active"]) == 1
    run("--rollback", active_journals[0].parent.name)
    assert cfg.read_text() == "stock greeter config\n"
    assert service_state.read_text().strip() == "sddm.service"
    assert not live.exists()

print("isolated greeter staging, rollback, and pre-enabled greetd recovery: OK")
