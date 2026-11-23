#!/usr/bin/env python3
"""Migrate a legacy folded directory symlink, preserving generated files."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    repo = root / "checkout with spaces"
    repo.mkdir()
    home = root / "host-home"
    home.mkdir()
    actual = Path(__file__).resolve().parents[1]

    def write(path: str, value: str | None = None) -> Path:
        dest = repo / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        if value is None:
            dest.write_bytes((actual / path).read_bytes())
        else:
            dest.write_text(value)
        return dest

    for script in (
        "scripts/effective-targets.py",
        "scripts/dot-doctor.py",
        "scripts/dot-links.py",
        "scripts/migrate-folded.py",
        "common/bin/.local/bin/dot",
        "install",
    ):
        write(script)
    common_dir = "common/hypr/.config/hypr"
    shared = write(f"{common_dir}/hyprland.lua", "SHARED\n")
    generated = write(f"{common_dir}/mocha-theme.lua", "GENERATED but gitignored\n")
    (repo / common_dir / "empty-original-directory").mkdir()
    write(".gitignore", "common/hypr/.config/hypr/mocha-theme.lua\n")
    host_override = write(
        "hosts/A/home/.config/hypr/hyprland.lua", "HOST A\n"
    )
    host_only = write("hosts/A/home/.config/hypr/host.lua", "host display\n")
    (repo / "hosts/B/home").mkdir(parents=True)
    subprocess.run(["git", "-C", str(repo), "init", "-q"], check=True)
    subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)

    folded = home / ".config/hypr"
    folded.parent.mkdir()
    folded.symlink_to(repo / common_dir, target_is_directory=True)
    original_link_text = os.readlink(folded)

    def run(script: str, *args: str, ok=True) -> subprocess.CompletedProcess:
        proc = subprocess.run(
            [
                sys.executable, str(repo / "scripts" / script),
                "--repo", str(repo), "--host", "A",
                "--home", str(home), *args,
            ],
            capture_output=True, text=True,
        )
        if ok:
            assert proc.returncode == 0, (script, proc.stdout, proc.stderr)
        else:
            assert proc.returncode != 0, (script, proc.stdout, proc.stderr)
        return proc

    preview = run("migrate-folded.py")
    assert "legacy Stow directory symlinks for A: 1" in preview.stdout
    assert folded.is_symlink()
    assert folded.joinpath("mocha-theme.lua").read_text() == generated.read_text()
    run("dot-links.py", ok=False)  # old folded directory blocks new linker

    result = run("migrate-folded.py", "--apply")
    migrated_id = re.search(r"dot rollback (\S+)", result.stdout).group(1)
    assert not folded.is_symlink()
    assert folded.is_dir()
    assert (folded / "hyprland.lua").is_symlink()
    assert (folded / "hyprland.lua").read_text() == "HOST A\n"
    assert (folded / "host.lua").read_text() == "host display\n"
    assert (folded / "empty-original-directory").is_dir()
    assert (folded / "mocha-theme.lua").is_symlink()
    assert (folded / "mocha-theme.lua").read_text() == "GENERATED but gitignored\n"
    assert shared.read_text() == "SHARED\n" and host_override.read_text() == "HOST A\n"

    # User data written after migration blocks rollback; never erase it.
    user_file = folded / "app-private-state.json"
    user_file.write_text("must survive")
    result = run("dot-links.py", "--rollback", migrated_id, ok=False)
    assert "new user file" in result.stderr
    assert user_file.read_text() == "must survive"
    user_file.unlink()
    new_user_dir = folded / "empty-user-created-directory"
    new_user_dir.mkdir()
    result = run("dot-links.py", "--rollback", migrated_id, ok=False)
    assert "new user directory" in result.stderr
    new_user_dir.rmdir()

    # Register effective links, then rollback in reverse transaction order.
    applied = run("dot-links.py")
    link_id = re.search(r"dot rollback (\S+)", applied.stdout).group(1)
    assert (folded / "hyprland.lua").is_symlink()
    # The linker-state fingerprint now changed, migration rollback must fail.
    result = run("dot-links.py", "--rollback", migrated_id, ok=False)
    assert "link state changed" in result.stderr
    run("dot-links.py", "--rollback", link_id)
    run("dot-links.py", "--rollback", migrated_id)

    assert folded.is_symlink()
    assert os.readlink(folded) == original_link_text
    assert (folded / "hyprland.lua").read_text() == "SHARED\n"
    assert (folded / "mocha-theme.lua").read_text() == "GENERATED but gitignored\n"
    assert host_only.read_text() == "host display\n"

print("legacy folded Stow migration and exact rollback: OK")
