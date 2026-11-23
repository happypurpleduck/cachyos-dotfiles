#!/usr/bin/env python3
"""Ensure host-specific desktop/MIME settings are isolated and no source path leaks."""
from pathlib import Path
import os
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
shared = (repo / "common/xdg/.config/mimeapps.list").read_text()
original = (repo / "hosts/husain-pc/home/.config/mimeapps.list").read_text()
launch = (repo / "common/applications/.local/share/applications/t3code.desktop").read_text()
wrapper = repo / "common/bin/.local/bin/t3code-launch"
seed = (repo / "seed/.config/waypaper/config.ini").read_text()
assert "google-chrome.desktop" not in shared
assert "dev.zed.Zed.desktop" not in shared
assert "google-chrome.desktop" in original
assert "dev.zed.Zed.desktop" in original
assert "t3code-launch %U" in launch
assert "/home/husain" not in launch + seed + shared
assert "wallpaper =\n" in seed

with tempfile.TemporaryDirectory() as temp:
    tmp = Path(temp)
    target = tmp / ".local/opt/t3code/T3-Code.AppImage"
    target.parent.mkdir(parents=True)
    target.write_text("#!/bin/sh\nprintf '%s\\n' \"$*\" > \"$HOME/called\"\n")
    target.chmod(0o755)
    result = subprocess.run(
        ["bash", str(wrapper), "one", "two with spaces"],
        env={**os.environ, "HOME": str(tmp)}, capture_output=True, text=True
    )
    assert result.returncode == 0, result.stderr
    assert (tmp / "called").read_text().strip() == (
        "--password-store=gnome-libsecret one two with spaces"
    )
    target.unlink()
    result = subprocess.run(
        ["bash", str(wrapper)],
        env={**os.environ, "HOME": str(tmp)}, capture_output=True, text=True
    )
    assert result.returncode == 127

print("portable desktop launcher, MIME defaults and wallpaper seed: OK")
