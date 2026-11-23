#!/usr/bin/env python3
"""Two disposable homes test owner-aware linking, conflict backups and rollback."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    repo = root / "arbitrary checkout"
    repo.mkdir()
    real = Path(__file__).resolve().parents[1]

    def add(path: str, value: str | None = None) -> Path:
        dest = repo / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        if value is None:
            dest.write_bytes((real / path).read_bytes())
        else:
            dest.write_text(value)
        return dest

    for path in (
        "scripts/effective-targets.py",
        "scripts/dot-doctor.py",
        "scripts/dot-links.py",
        "common/bin/.local/bin/dot",
        "install",
    ):
        add(path)
    for host in ("A", "B"):
        for app, suffix in (
            ("hypr", ".config/hypr/hyprland.lua"),
            ("quickshell", ".config/quickshell/shell.qml"),
            ("zsh", ".zshrc"),
        ):
            add(f"common/{app}/{suffix}", f"shared {app}")
            add(f"hosts/{host}/home/{suffix}", f"{host} {app}")
            add(f"hosts/{host}/home/.config/{app}/{host}-only", host)
    add("common/editor/.config/editor/settings.conf", "shared editor")
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)

    home_a = root / "home A"
    home_b = root / "home B"
    home_a.mkdir()
    home_b.mkdir()

    def invoke(home: Path, host: str, *args: str, ok=True) -> subprocess.CompletedProcess:
        result = subprocess.run(
            [
                sys.executable, str(repo / "scripts/dot-links.py"),
                "--repo", str(repo), "--home", str(home),
                "--host", host, *args,
            ],
            capture_output=True, text=True,
        )
        if ok:
            assert result.returncode == 0, (result.stdout, result.stderr)
        else:
            assert result.returncode != 0, (result.stdout, result.stderr)
        return result

    path = ".config/editor/settings.conf"
    preview = invoke(home_a, "A", "--dry-run")
    assert not (home_a / ".local").exists(), "dry-run mutated home"
    assert "Dry run" in preview.stdout
    invoke(home_a, "A")
    invoke(home_b, "B")
    txroot = home_a / ".local/state/dotfiles-backup/transactions"
    before_count = len(list(txroot.glob("*/journal.json")))
    assert "no-op" in invoke(home_a, "A").stdout
    assert len(list(txroot.glob("*/journal.json"))) == before_count, (
        "repeated link unexpectedly created another transaction"
    )

    for home, host in ((home_a, "A"), (home_b, "B")):
        for app, suffix in (
            ("hypr", ".config/hypr/hyprland.lua"),
            ("quickshell", ".config/quickshell/shell.qml"),
            ("zsh", ".zshrc"),
        ):
            assert (home / suffix).is_symlink()
            assert (home / suffix).read_text() == f"{host} {app}"
            assert (home / f".config/{app}/{host}-only").is_symlink()
        assert (home / path).read_text() == "shared editor"
    # The CLI must report effective links healthy (no stale Stow linked() call).
    dot = repo / "common/bin/.local/bin/dot"
    cli_env = {**os.environ, "HOME": str(home_a), "DOT_HOST": "A"}
    cli_env.pop("DOTFILES", None)
    def run_dot(*args: str, input_text: str | None = None):
        result = subprocess.run([str(dot), *args], env=cli_env,
                                input=input_text, capture_output=True, text=True)
        assert result.returncode == 0, (args, result.stdout, result.stderr)
        assert "command not found" not in result.stderr
        return result

    report = run_dot("status")
    assert "all links ok" in report.stdout, report.stdout

    # Seeds are copy-once and never overwrite an app-owned file, including
    # subsequent relinks from an existing managed host.
    add("seed/.config/waypaper/config.ini", "seed once")
    run_dot("confirm-host", input_text="A\n")
    run_dot("link")
    seed = home_a / ".config/waypaper/config.ini"
    assert seed.read_text() == "seed once"
    seed.write_text("app edited")
    run_dot("link")
    assert seed.read_text() == "app edited"

    extra = home_a / ".config/editor/unrelated-user-data"
    extra.write_text("must survive")

    # Shared changes propagate; A's zsh override never changes B.
    (repo / "common/editor/.config/editor/settings.conf").write_text("v2")
    assert (home_a / path).read_text() == "v2"
    assert (home_b / path).read_text() == "v2"
    (repo / "hosts/A/home/.zshrc").write_text("A customized")
    assert (home_a / ".zshrc").read_text() == "A customized"
    assert (home_b / ".zshrc").read_text() == "B zsh"

    # Shared file -> host override -> shared fallback, one file at a time.
    new_override = add(f"hosts/A/home/{path}", "A-only editor")
    invoke(home_a, "A")
    assert (home_a / path).read_text() == "A-only editor"
    assert (home_b / path).read_text() == "v2"
    new_override.unlink()
    invoke(home_a, "A")
    assert (home_a / path).read_text() == "v2"
    assert extra.read_text() == "must survive"

    # User's app rewrites managed link to an ordinary file. Require explicit
    # collision backup, and rollback returns the exact original file.
    target = home_a / path
    target.unlink()
    target.write_text("new app-authored content")
    changed_status = run_dot("status")
    assert "replaced by an app" in changed_status.stdout
    assert "command not found" not in changed_status.stderr
    invoke(home_a, "A", ok=False)
    result = invoke(home_a, "A", "--backup-conflicts")
    txid = re.search(r"dot rollback (\S+)", result.stdout).group(1)
    assert target.is_symlink() and target.read_text() == "v2"
    invoke(home_a, "A", "--rollback", txid)
    assert not target.is_symlink()
    assert target.read_text() == "new app-authored content"
    assert extra.read_text() == "must survive"

    # Re-apply explicit backup, then unlink only managed links, preserving
    # unrelated data. Unlink itself is reversible.
    invoke(home_a, "A", "--backup-conflicts")
    result = invoke(home_a, "A", "--unlink")
    unlink_id = re.search(r"dot rollback (\S+)", result.stdout).group(1)
    assert not (home_a / ".zshrc").exists()
    assert extra.read_text() == "must survive"
    invoke(home_a, "A", "--rollback", unlink_id)
    assert (home_a / ".zshrc").is_symlink()

    # Legacy folded Stow directory symlinks are rejected instead of silently
    # unlinking or reshaping an application's source directory.
    folded = root / "folded home"
    folded.mkdir()
    (folded / ".config").mkdir()
    (folded / ".config/hypr").symlink_to(
        repo / "common/hypr/.config/hypr", target_is_directory=True
    )
    result = invoke(folded, "A", ok=False)
    assert "folded-parent" in result.stderr
    assert (folded / ".config/hypr").is_symlink()

    # Foreign source links (another host profile) must not become 'ours'.
    alien = root / "alien home"
    alien.mkdir()
    (alien / ".zshrc").symlink_to(repo / "hosts/B/home/.zshrc")
    result = invoke(alien, "A", ok=False)
    assert "another host" in result.stderr
    assert (alien / ".zshrc").is_symlink()

print("two-host link, overrides, collision backups, unlink and rollback: OK")
