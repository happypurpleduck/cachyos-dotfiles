#!/usr/bin/env python3
"""Pure fixture tests for the read-only per-host target planner."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

PLANNER = Path(__file__).resolve().parents[1] / "scripts/effective-targets.py"

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    checkout = root / "config-repo"
    checkout.mkdir()
    (checkout / "common").mkdir()
    (checkout / "hosts").mkdir()

    def write(rel: str, value: str) -> None:
        dst = checkout / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(value, encoding="utf-8")

    shared = {
        "hypr": ".config/hypr/hyprland.lua",
        "quickshell": ".config/quickshell/shell.qml",
        "zsh": ".zshrc",
    }
    for app, dest in shared.items():
        write(f"common/{app}/{dest}", f"shared {app}")
        for host in ("A", "B"):
            write(f"hosts/{host}/home/{dest}", f"{host} {app}")
            write(
                f"hosts/{host}/home/.config/{app}/{host.lower()}-extra.conf",
                f"{host} only",
            )
    write("common/editor/.config/editor/settings.conf", "shared editor")
    write("hosts/A/home/.config/editor/custom.conf", "A only")
    write(".gitignore", "common/hypr/.config/hypr/generated.conf\n")
    write("common/hypr/.config/hypr/generated.conf", "private generated state")

    subprocess.run(["git", "init", "-q", str(checkout)], check=True)
    subprocess.run(["git", "-C", str(checkout), "add", "--all"], check=True)

    def preview(host: str) -> dict:
        home = root / f"user-{host}"
        cmd = [
            sys.executable, str(PLANNER), "--repo", str(checkout),
            "--host", host, "--home", str(home), "--json",
        ]
        output = subprocess.run(cmd, capture_output=True, check=True, text=True)
        assert not home.exists(), "read-only planner wrote to HOME"
        return json.loads(output.stdout)

    for host in ("A", "B"):
        plan = preview(host)
        rows = {x["path"]: x for x in plan["entries"]}
        assert plan["overrides"] == 3, plan
        for app, path in shared.items():
            assert rows[path]["owner"] == f"host:{host}", (host, app)
            assert rows[path]["source"].endswith(
                f"hosts/{host}/home/{path}"
            ), (host, app)
            assert rows[path]["overridden_source"].endswith(
                f"common/{app}/{path}"
            ), (host, app)
            own = f".config/{app}/{host.lower()}-extra.conf"
            other = f".config/{app}/{'b' if host == 'A' else 'a'}-extra.conf"
            assert own in rows, own
            assert other not in rows, other
        assert rows[".config/editor/settings.conf"]["owner"] == "common:editor"
        assert str(checkout / "common/hypr/.config/hypr/generated.conf") not in {
            str(x["source"]) for x in plan["entries"]
        }
        if host == "B":
            assert ".config/editor/custom.conf" not in rows

    # Removing one host override restores the corresponding shared default.
    (checkout / "hosts/B/home/.zshrc").unlink()
    plan = preview("B")
    rows = {x["path"]: x for x in plan["entries"]}
    assert rows[".zshrc"]["owner"] == "common:zsh"
    assert rows[".zshrc"]["overridden_source"] is None
    assert {x["path"]: x for x in preview("A")["entries"]}[".zshrc"][
        "owner"
    ] == "host:A"

    # Duplicate common owners are an error, not an arbitrary first-wins result.
    write("common/other/.config/hypr/hyprland.lua", "collision")
    failed = subprocess.run(
        [
            sys.executable, str(PLANNER), "--repo", str(checkout),
            "--host", "B", "--home", str(root / "unused"),
        ],
        capture_output=True,
        text=True,
    )
    assert failed.returncode == 2, failed
    assert "multiple common packages" in failed.stderr, failed.stderr

print("per-host precedence, isolation, fallback and collisions: OK")
