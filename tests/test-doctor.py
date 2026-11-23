#!/usr/bin/env python3
"""Non-destructive doctor and install/link dry-run regression tests."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    repo = root / "repo"
    home = root / "home"
    repo.mkdir()
    home.mkdir()
    actual = Path(__file__).resolve().parents[1]

    def copy(path: str) -> None:
        target = repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((actual / path).read_bytes())
        target.chmod(0o755 if path in ("install", "common/bin/.local/bin/dot") else 0o644)

    for source in (
        "scripts/effective-targets.py",
        "scripts/dot-doctor.py",
        "common/bin/.local/bin/dot",
        "install",
    ):
        copy(source)
    for dirpath in ("hosts/A/home", "hosts/B/home", "packages"):
        (repo / dirpath).mkdir(parents=True, exist_ok=True)
    shared = repo / "common/app/.config/app/settings.conf"
    shared.parent.mkdir(parents=True, exist_ok=True)
    shared.write_text("common settings\n")
    override = repo / "hosts/A/home/.config/app/settings.conf"
    override.parent.mkdir(parents=True, exist_ok=True)
    override.write_text("A settings\n")
    (repo / "packages/common.txt").write_text("git\n")
    subprocess.run(["git", "-C", str(repo), "init", "-q"], check=True)
    subprocess.run(["git", "-C", str(repo), "add", "--all"], check=True)

    env = {**os.environ, "HOME": str(home), "DOT_HOST": "A"}
    env.pop("DOTFILES", None)

    def doctor(*args: str) -> dict:
        result = subprocess.run(
            [
                sys.executable, str(repo / "scripts/dot-doctor.py"),
                "--repo", str(repo), "--home", str(home), "--host", "A",
                "--json", *args,
            ],
            text=True, capture_output=True, check=True,
        )
        return json.loads(result.stdout)

    def status() -> str:
        values = doctor()["targets"]
        return {item["path"]: item["status"] for item in values}[
            ".config/app/settings.conf"
        ]

    assert status() == "missing"
    target = home / ".config/app/settings.conf"
    target.parent.mkdir(parents=True)
    target.symlink_to(override)
    assert status() == "ok"
    target.unlink()
    target.symlink_to(shared)
    assert status() == "managed-different"
    target.unlink()
    target.write_text("private user state")
    assert status() == "collision-file"
    target.unlink()
    target.symlink_to(root / "unrelated-file")
    assert status() == "foreign-symlink"
    target.unlink()
    target.parent.rmdir()
    (home / ".config/app").symlink_to(shared.parent, target_is_directory=True)
    assert status() == "folded-parent"
    report = doctor()
    assert report["blocking_targets"], report
    assert report["system_changes"]["greeter_activation"].startswith("never")
    assert not (home / ".local").exists(), "doctor modified the home"

    for command in (
        [str(repo / "common/bin/.local/bin/dot"), "doctor", "--json"],
        [str(repo / "common/bin/.local/bin/dot"), "link", "--dry-run"],
        [str(repo / "common/bin/.local/bin/dot"), "install", "--dry-run"],
        ["bash", str(repo / "install"), "--dry-run"],
    ):
        result = subprocess.run(command, env=env, text=True, capture_output=True)
        assert result.returncode == 0, (command, result.stderr, result.stdout)
        assert "folded-parent" in result.stdout, (command, result.stdout)
        assert not (home / ".local").exists(), "dry-run modified the home"

print("doctor and bootstrap dry-run are read-only: OK")
