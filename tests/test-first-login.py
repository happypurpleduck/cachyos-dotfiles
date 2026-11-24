#!/usr/bin/env python3
"""First-login/theme tests require no compositor, network, or system service."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as root_name:
    root = Path(root_name)
    home = root / "a different account"
    home.mkdir()
    script = repo / "scripts/first-login.py"
    theme = repo / "common/quickshell/.config/quickshell/scripts/mocha-theme"
    # Stub every desktop-touching tool so tests never change the live session.
    fakebin = root / "bin"
    fakebin.mkdir()
    calls = root / "calls"
    for tool in ("awww", "gsettings", "pkill", "hyprctl"):
        (fakebin / tool).write_text(f'#!/bin/sh\necho "{tool} $*" >> "{calls}"\n')
        (fakebin / tool).chmod(0o755)
    env = {**os.environ, "HOME": str(home), "MOCHA_OFFLINE": "1",
           "PATH": f"{fakebin}{os.pathsep}{os.environ['PATH']}"}
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    env.pop("XDG_CONFIG_HOME", None)
    env.pop("XDG_STATE_HOME", None)

    def invoke(*args, good=True):
        run = subprocess.run(
            [sys.executable, str(script), "--home", str(home),
             "--theme-script", str(theme), *args],
            env=env, capture_output=True, text=True,
        )
        assert (run.returncode == 0) == good, (run.stdout, run.stderr)
        return run

    assert json.loads(invoke("--check", good=False).stdout)["ready"] is False
    result = json.loads(invoke().stdout)
    fallback = home / ".local/state/mocha-shell/fallback.png"
    assert result["wallpaper"] == str(fallback)
    assert fallback.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
    state = home / ".local/state/mocha-shell/theme.json"
    assert state.is_file()
    assert json.loads(state.read_text())["accent"] in (
        "mauve", "rosewater", "blue", "teal", "green", "flamingo",
        "pink", "red", "maroon", "peach", "yellow", "sky",
        "sapphire", "lavender",
    )
    assert json.loads(invoke("--check").stdout)["ready"] is True

    # Repeated first login preserves current valid wallpaper and local state.
    first = state.read_text()
    second = invoke()
    assert json.loads(second.stdout)["wallpaper"] == str(fallback)
    assert fallback.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
    for required in (
        ".config/kitty/mocha-theme.conf",
        ".config/hokum/themes/mocha.kdl",
        ".config/hypr/mocha-theme.lua",
        ".config/zsh/p10k-mocha.zsh",
    ):
        assert (home / required).stat().st_size > 0, required

    # An account may change wallpaper; existing state is respected.
    alternate = home / "wallpaper.png"
    alternate.write_bytes(fallback.read_bytes())
    data = json.loads(state.read_text())
    data["wallpaper"] = str(alternate)
    state.write_text(json.dumps(data))
    assert json.loads(invoke().stdout)["wallpaper"] == str(alternate)

    # A chosen wallpaper that is briefly unavailable (not downloaded yet,
    # drive unmounted) is shown as a stand-in but never forgotten, neither by
    # a reinstall (first-login) nor by the login-time restore.
    chosen = home / "Pictures/chosen.png"
    data = json.loads(state.read_text())
    data["wallpaper"] = str(chosen)
    state.write_text(json.dumps(data))
    invoke()
    assert json.loads(state.read_text())["wallpaper"] == str(chosen)
    calls.unlink(missing_ok=True)
    restored = subprocess.run([sys.executable, str(theme), "restore"], env=env,
                              capture_output=True, text=True)
    assert restored.returncode == 0, restored.stderr
    assert json.loads(state.read_text())["wallpaper"] == str(chosen)
    assert f"awww img {fallback}" in calls.read_text()
    chosen.parent.mkdir(parents=True)
    chosen.write_bytes(fallback.read_bytes())
    subprocess.run([sys.executable, str(theme), "restore"], env=env, check=True,
                   capture_output=True)
    assert f"awww img {chosen}" in calls.read_text()

print("offline first-login and fallback themes: OK")
