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
    env = {**os.environ, "HOME": str(home)}
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

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

print("offline first-login and fallback themes: OK")
