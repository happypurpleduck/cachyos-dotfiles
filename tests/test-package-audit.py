#!/usr/bin/env python3
"""Package audit tests with fake pacman, AUR and sudo; never install packages."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

root_source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    repo = root / "repo"
    for folder in ("common/app/.config/app", "hosts/A/home", "packages/optional", "scripts"):
        (repo / folder).mkdir(parents=True, exist_ok=True)
    for rel in ("scripts/effective-targets.py", "scripts/package-audit.py"):
        (repo / rel).write_bytes((root_source / rel).read_bytes())
    (repo / "common/app/.config/app/config").write_text("shared")
    (repo / "packages/common.txt").write_text("git\neza\nbat\nfd\n")
    (repo / "packages/aur.txt").write_text("hokum-bin\n")
    (repo / "hosts/A/optional.txt").write_text("!qbittorrent\nphoto\n")
    (repo / "packages/optional/photo.txt").write_text("# Optional\nkrita\naur:mock-aura\n")
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)

    binpath = root / "bin"
    binpath.mkdir()
    installed = root / "installed"
    available = root / "available"
    installed.write_text("git\n")
    available.write_text("git\neza\nbat\nfd\nkrita\n")
    shim = r'''#!/usr/bin/env python3
import os,sys
from pathlib import Path
args=sys.argv[1:]
installed=Path(os.environ["MOCK_INSTALLED"])
available=Path(os.environ["MOCK_AVAILABLE"])
name=Path(sys.argv[0]).name
if name=="sudo":
    os.execvp(args[0],args)
if args==["-Qq"]:
    print(installed.read_text(),end="")
elif args==["-Slq"]:
    print(available.read_text(),end="")
elif args[:1]==["-S"]:
    pkgs=[v for v in args if not v.startswith("-") and v not in ("-S",)]
    with installed.open("a") as f:
        for p in pkgs: f.write(p+"\n")
else:
    raise SystemExit(f"unexpected {name}: {args}")
'''
    for tool in ("pacman", "paru", "sudo"):
        path = binpath / tool
        path.write_text(shim)
        path.chmod(0o755)
    env = {
        **os.environ,
        "MOCK_INSTALLED": str(installed),
        "MOCK_AVAILABLE": str(available),
        "PATH": str(binpath) + os.pathsep + os.environ["PATH"],
    }

    def audit(*args: str, ok=True):
        proc = subprocess.run(
            [sys.executable, str(repo / "scripts/package-audit.py"),
             "--repo", str(repo), "--host", "A", *args],
            text=True, capture_output=True, env=env,
        )
        if ok:
            assert proc.returncode == 0, (proc.stdout,proc.stderr)
        else:
            assert proc.returncode != 0, (proc.stdout,proc.stderr)
        return proc

    assert "repo missing: bat, eza, fd, krita" in audit().stdout
    assert "AUR missing: hokum-bin, mock-aura" in audit().stdout
    audit("--install")
    assert set(installed.read_text().split()) == {
        "git", "eza", "bat", "fd", "krita", "hokum-bin", "mock-aura"
    }
    assert "repo missing: none" in audit().stdout

    installed.write_text("git\n")
    (binpath / "paru").unlink()
    assert "BLOCKED" in audit(ok=False).stdout
    audit("--install", ok=False)
    assert installed.read_text() == "git\n", "blocked audit installed partial packages"

    (binpath / "paru").write_text(shim)
    (binpath / "paru").chmod(0o755)
    available.write_text("git\neza\nbat\n")  # fd/krita unavailable: block
    assert "repo unavailable: fd, krita" in audit(ok=False).stdout
    audit("--install", ok=False)
    assert installed.read_text() == "git\n"

    # Declined groups do not become attempted packages, unknown chosen groups fail.
    (repo / "hosts/A/optional.txt").write_text("nonexistent\n")
    assert "unknown optional group" in audit(ok=False).stderr
print("package gates: missing AUR tool / repo availability / explicit install: OK")
