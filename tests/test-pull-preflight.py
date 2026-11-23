#!/usr/bin/env python3
"""Two clones exercise preview-only remote changes and explicit gated sync."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile

source = Path(__file__).resolve().parents[1]

def git(repo: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(repo), *args], check=True,
                          capture_output=True, text=True).stdout.strip()

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    bare = root / "remote.git"
    seed = root / "seed"
    git(root, "init", "-q", "--bare", str(bare))
    git(root, "init", "-q", "-b", "main", str(seed))
    def put(name: str, content: str) -> None:
        path = seed / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    put("install", "#!/bin/bash\n")
    put("common/app/.config/app/settings", "shared-v1\n")
    put("hosts/A/home/.config/app/host", "host-A\n")
    put("hosts/B/home/.config/app/host", "host-B\n")
    put("packages/common.txt", "git\n")
    for name in ("scripts/effective-targets.py", "scripts/pull-preflight.py"):
        path = seed / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes((source / name).read_bytes())
    git(seed, "config", "user.email", "ci@example.invalid")
    git(seed, "config", "user.name", "CI")
    git(seed, "add", "-A")
    git(seed, "commit", "-qm", "baseline")
    git(seed, "remote", "add", "origin", str(bare))
    git(seed, "push", "-qu", "origin", "main")
    git(root, "clone", "-q", "-b", "main", str(bare), str(root / "A"))
    git(root, "clone", "-q", "-b", "main", str(bare), str(root / "B"))
    A, B = root / "A", root / "B"
    for repo in (A, B):
        git(repo, "config", "user.email", "ci@example.invalid")
        git(repo, "config", "user.name", "CI")

    home = root / "user-A"
    home.mkdir()
    local_link = home / ".config/app/settings"
    local_link.parent.mkdir(parents=True)
    local_link.symlink_to(A / "common/app/.config/app/settings")
    def preview(*args: str, good=True):
        result = subprocess.run([
            sys.executable, str(A / "scripts/pull-preflight.py"),
            "--repo", str(A), "--home", str(home), "--host", "A",
            *args], text=True, capture_output=True)
        assert (result.returncode == 0) == good, (
            args, result.returncode, result.stdout, result.stderr
        )
        return result

    # Remote-only other host edits can synchronize without affecting A links.
    (B / "hosts/B/home/.config/app/host").write_text("host-B-v2\n")
    git(B, "add", "-A")
    git(B, "commit", "-qm", "B host only")
    git(B, "push", "-q")
    assert not preview("--json").stderr
    sha = preview("--emit-sha").stdout.strip()
    assert len(sha) == 40
    git(A, "rebase", sha)
    assert local_link.read_text() == "shared-v1\n"

    # Shared change must fail closed in default preview, without mutating A.
    (B / "common/app/.config/app/settings").write_text("shared-v2\n")
    git(B, "add", "-A")
    git(B, "commit", "-qm", "shared update")
    git(B, "push", "-q")
    blocked = preview("--emit-sha", good=False)
    assert "BLOCKED" in blocked.stderr
    assert local_link.read_text() == "shared-v1\n"
    sha = preview("--apply", "--emit-sha").stdout.strip()
    assert len(sha) == 40
    git(A, "rebase", sha)
    assert local_link.read_text() == "shared-v2\n"

    # A new remote-owned path over an app-authored regular file is blocked.
    new_target = home / ".config/app/private"
    new_target.write_text("my data remains")
    new_source = B / "common/app/.config/app/private"
    new_source.write_text("remote wants my path")
    git(B, "add", "-A")
    git(B, "commit", "-qm", "new target")
    git(B, "push", "-q")
    failed = preview("--apply", "--emit-sha", good=False)
    assert "existing user state" in failed.stderr
    assert new_target.read_text() == "my data remains"
    assert not (A / "common/app/.config/app/private").exists()

print("preflight-gated remote sync: shared, other-host and user-file collisions OK")
