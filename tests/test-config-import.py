#!/usr/bin/env python3
"""Preview-first import keeps HOME intact, respects ownership and blocks secrets."""
from pathlib import Path
import subprocess
import sys
import tempfile

actual = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    repo = root / "config repo"
    home = root / "test account"
    home.mkdir()
    for directory in ("common/demo/.config/demo", "hosts/A/home", "hosts/B/home",
                      "scripts"):
        (repo / directory).mkdir(parents=True, exist_ok=True)
    (repo / "scripts/effective-targets.py").write_bytes(
        (actual / "scripts/effective-targets.py").read_bytes()
    )
    shared = repo / "common/demo/.config/demo/settings.conf"
    shared.write_text("old common source\n")
    app = home / ".config/demo/settings.conf"
    app.parent.mkdir(parents=True)
    app.write_text("new app settings\n")
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)

    importer = actual / "scripts/import-config.py"
    def run(*args: str, ok=True):
        proc = subprocess.run([
            sys.executable, str(importer), "--repo", str(repo),
            "--home", str(home), "--host", "A", *args,
        ], capture_output=True, text=True)
        assert (proc.returncode == 0) == ok, (proc.stdout, proc.stderr)
        return proc

    # Common edits never overwrite existing repository sources implicitly.
    assert "source already exists" in run(str(app), ok=False).stderr
    preview = run("--replace-source", str(app))
    assert "PREVIEW ONLY" in preview.stdout
    assert shared.read_text() == "old common source\n"
    run("--replace-source", "--apply", str(app))
    assert shared.read_text() == "new app settings\n"
    assert app.read_text() == "new app settings\n", "app file was moved or removed"
    backups = list((home / ".local/state/dotfiles-backup/imports").glob(
        "*/common/demo/.config/demo/settings.conf"))
    assert len(backups) == 1
    assert backups[0].read_text() == "old common source\n"

    # Host overrides of a shared target are permitted, and do not alter B.
    app.write_text("host A only\n")
    run("--host-only", "--apply", str(app))
    host_src = repo / "hosts/A/home/.config/demo/settings.conf"
    assert host_src.read_text() == "host A only\n"
    assert shared.read_text() == "new app settings\n"
    assert app.read_text() == "host A only\n"

    # New shared config is copied but never staged or committed automatically.
    extra = home / ".config/demo/extra.conf"
    extra.write_text("safe file\n")
    preview = run(str(extra))
    assert "PREVIEW ONLY" in preview.stdout
    common_extra = repo / "common/demo/.config/demo/extra.conf"
    assert not common_extra.exists()
    run("--apply", str(extra))
    assert extra.read_text() == "safe file\n"
    assert common_extra.read_text() == "safe file\n"
    status = subprocess.run(["git", "-C", str(repo), "status", "--porcelain"],
                            capture_output=True, text=True, check=True).stdout
    assert "?? common/demo/.config/demo/extra.conf" in status
    assert "?" in status
    assert "no-op" in run("--apply", str(extra)).stdout

    # Secrets, binary files, outside HOME, symlinks must remain outside import.
    private = home / ".ssh/id_ed25519"
    private.parent.mkdir()
    private.write_text("do not publish")
    assert "never imported" in run(str(private), ok=False).stderr
    binary = home / ".config/demo/raw.bin"
    binary.write_bytes(b"\0example")
    assert "binary file" in run(str(binary), ok=False).stderr
    outside = root / "outside.txt"
    outside.write_text("outside")
    assert "outside HOME" in run(str(outside), ok=False).stderr
    aliased = home / ".config/demo/alias.conf"
    aliased.symlink_to(extra)
    assert "not a regular" in run(str(aliased), ok=False).stderr

print("safe app import: previews, host override, backups, secrets and copy-only OK")
