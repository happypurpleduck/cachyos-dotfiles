#!/usr/bin/env python3
"""Fake-root service tests. No real systemctl, pacman or sudo invocation."""
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile

source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    repo = root / "repo"
    for host in ("A", "B"):
        (repo / "hosts" / host / "home").mkdir(parents=True)
    (repo / "hosts/A/services.txt").write_text("bluetooth\n")
    fakebin = root / "bin"
    fakebin.mkdir()
    installed = root / "installed"
    installed.write_text("bluez\n")
    unit = root / "unit-exists"
    unit.write_text("yes")
    service = root / "enabled"
    service.write_text("no")
    log = root / "sudo-log"

    ctl = fakebin / "systemctl"
    ctl.write_text(
        "#!/bin/sh\n"
        "case \"$1\" in\n"
        "  cat) test -f \"$UNIT_EXISTS\" ;;\n"
        "  is-enabled|is-active) grep -qx yes \"$SERVICE_ENABLED\" ;;\n"
        "  enable) echo yes > \"$SERVICE_ENABLED\"; exit 0 ;;\n"
        "  *) exit 2 ;;\n"
        "esac\n"
    )
    ctl.chmod(0o755)
    pacman = fakebin / "pacman"
    pacman.write_text(
        "#!/bin/sh\n"
        "test \"$1\" = -Qq && grep -qx \"$2\" \"$INSTALLED_PKGS\"\n"
    )
    pacman.chmod(0o755)
    sudo = fakebin / "sudo"
    sudo.write_text(
        "#!/bin/sh\n"
        "echo \"$*\" >> \"$SUDO_LOG\"\n"
        "exec \"$@\"\n"
    )
    sudo.chmod(0o755)
    env = {**os.environ, "PATH": str(fakebin) + os.pathsep + os.environ["PATH"],
           "UNIT_EXISTS": str(unit), "SERVICE_ENABLED": str(service),
           "INSTALLED_PKGS": str(installed), "SUDO_LOG": str(log)}

    def run(host: str, *args: str, ok=True):
        cmd = [sys.executable, str(source / "scripts/host-services.py"),
               "--repo", str(repo), "--host", host,
               "--systemctl", str(ctl), "--pacman", str(pacman), *args]
        r = subprocess.run(cmd, env=env, capture_output=True, text=True)
        assert (r.returncode == 0) == ok, (r.returncode, r.stdout, r.stderr)
        return r

    report = json.loads(run("A", "--json").stdout)
    assert report["selected"] == ["bluetooth"]
    assert report["services"]["bluetooth"]["ready"]
    assert not report["services"]["bluetooth"]["active"]
    assert not log.exists(), "read-only service inventory invoked sudo"
    assert json.loads(run("B", "--json").stdout)["services"] == {}

    run("A", "--apply", ok=False)
    assert not log.exists()
    run("A", "--apply", "--confirm", "ENABLE HOST SERVICES")
    assert service.read_text().strip() == "yes"
    assert log.read_text().count("enable --now bluetooth.service") == 1

    # Re-running activation is no-op, not another privileged service call.
    run("A", "--apply", "--confirm", "ENABLE HOST SERVICES")
    assert log.read_text().count("enable --now bluetooth.service") == 1
    run("B", "--apply", "--confirm", "ENABLE HOST SERVICES")
    assert log.read_text().count("enable --now bluetooth.service") == 1

    service.write_text("no")
    installed.write_text("")
    run("A", "--apply", "--confirm", "ENABLE HOST SERVICES", ok=False)
    assert log.read_text().count("enable --now bluetooth.service") == 1
    installed.write_text("bluez\n")
    unit.unlink()
    run("A", "--apply", "--confirm", "ENABLE HOST SERVICES", ok=False)
    assert log.read_text().count("enable --now bluetooth.service") == 1

    (repo / "hosts/A/services.txt").write_text("untrusted.service\n")
    assert "unsupported system service" in run("A", ok=False).stderr

print("host services: read-only inventories, opt-in Bluetooth, no-op and blockers OK")
