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
        "  enable) printf '%s\\n' \"$unit\" > \"$MOCK_SERVICES\"; exit 0 ;;\n"
        "  disable) sed -i \"/^$unit$/d\" \"$MOCK_SERVICES\"; exit 0 ;;\n"
        "esac\nexit 2\n"
    )
    sh.chmod(0o755)
    env = {**os.environ, "MOCK_CALLS": str(calls),
           "MOCK_SERVICES": str(service_state)}

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

    before = cfg.read_bytes()
    report = run()
    assert "sddm.service" in report.stdout
    assert cfg.read_bytes() == before and not calls.exists()
    staged = run("--stage")
    stage = fake / "etc/greetd/mocha-greeter-staged"
    assert stage.is_dir()
    assert (stage / "shell.qml").is_file()
    assert (stage / "wallpaper").read_bytes() == fallback.read_bytes()
    assert json.loads((stage / "theme.json").read_text())["accentHex"] == "#89b4fa"
    assert cfg.read_bytes() == before and not calls.exists()

    run("--activate", "--confirm", "ACTIVATE greetd", good=False)
    run("--activate", "--confirm", "ACTIVATE greetd",
        "--replace-display-manager", good=True)
    # Live running login wasn't restarted; enablement switches on next boot.
    assert "restart" not in calls.read_text()
    assert "disable sddm.service" in calls.read_text()
    assert "enable greetd.service" in calls.read_text()
    live = fake / "etc/greetd/mocha-greeter"
    assert live.is_dir() and live.joinpath("shell.qml").is_file()
    assert "qs -p /etc/greetd/mocha-greeter" in cfg.read_text()
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
        'command = "env MOCHA_THEME_FILE=/etc/greetd/mocha-greeter/theme.json '
        'XCURSOR_THEME=Adwaita XCURSOR_SIZE=24 QT_QPA_PLATFORM=wayland '
        'cage -s -m last -- qs -p /etc/greetd/mocha-greeter"\n'
        'user = "greeter"\n'
    )
    run("--rollback", txid)
    assert cfg.read_bytes() == before
    assert "enable sddm.service" in calls.read_text()
    assert "restart" not in calls.read_text()
    assert not live.exists()

print("isolated greeter stage, competing display manager, rollback & no restart: OK")
