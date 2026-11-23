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
    (repo / "packages/aur.txt").write_text("hokum-bin\ngoogle-chrome\n")
    (repo / "packages/aur-exceptions.json").write_text(
        '{"hokum-bin":{"scope":"common","reason":"core daemon","review":"review PKGBUILD"},'
        '"google-chrome":{"scope":"common","reason":"default browser","review":"review PKGBUILD"},'
        '"mock-aura":{"scope":"host","reason":"fixture","review":"review fixture"}}'
    )
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
elif name=="shelly" and args[:2]==["install","aur"]:
    with installed.open("a") as f:
        for p in args[2:]: f.write(p+"\n")
    Path(os.environ["MOCK_SHELLY_INVOCATIONS"]).write_text(" ".join(args))
elif name=="pacman" and args[:1]==["-S"]:
    pkgs=[v for v in args if not v.startswith("-") and v not in ("-S",)]
    with installed.open("a") as f:
        for p in pkgs: f.write(p+"\n")
else:
    raise SystemExit(f"unexpected {name}: {args}")
'''
    for tool in ("pacman", "shelly", "sudo"):
        path = binpath / tool
        path.write_text(shim)
        path.chmod(0o755)
    shelly_commands = root / "shelly-invocations"
    env = {
        **os.environ,
        "MOCK_SHELLY_INVOCATIONS": str(shelly_commands),
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
    assert "AUR missing: google-chrome, hokum-bin, mock-aura" in audit().stdout
    audit("--install", ok=False)
    assert installed.read_text() == "git\n", "AUR installed without explicit approval"
    audit("--install", "--approve-aur")
    assert set(installed.read_text().split()) == {
        "git", "eza", "bat", "fd", "krita", "google-chrome", "hokum-bin", "mock-aura"
    }
    assert "repo missing: none" in audit().stdout
    # Reset the log after the successful authorized scenario before testing
    # that a subsequent unapproved installation never invokes Shelly.
    shelly_commands.unlink(missing_ok=True)

    installed.write_text("git\n")
    (binpath / "shelly").unlink()
    assert "BLOCKED" in audit(ok=False).stdout
    assert "Shelly CLI is required" in audit(ok=False).stdout
    audit("--install", ok=False)
    assert installed.read_text() == "git\n", "missing Shelly installed packages"

    # A CachyOS install with only Shelly can install explicit AUR exceptions.
    (binpath / "shelly").write_text(shim)
    (binpath / "shelly").chmod(0o755)
    shelly_report = audit()
    assert "Shelly CLI: " in shelly_report.stdout
    assert "shelly" in shelly_report.stdout
    audit("--install", ok=False)
    assert installed.read_text() == "git\n", "Shelly bypassed required AUR approval"
    assert not shelly_commands.exists(), "Shelly executed before approval"
    audit("--install", "--approve-aur")
    assert shelly_commands.read_text() == "install aur google-chrome hokum-bin mock-aura"
    assert "repo missing: none" in audit().stdout
    (binpath / "shelly").unlink()
    installed.write_text("git\n")
    shelly_commands.unlink(missing_ok=True)
    assert "BLOCKED" in audit(ok=False).stdout

    (binpath / "shelly").write_text(shim)
    (binpath / "shelly").chmod(0o755)
    available.write_text("git\neza\nbat\n")  # fd/krita unavailable: block
    assert "repo unavailable: fd, krita" in audit(ok=False).stdout
    audit("--install", ok=False)
    assert installed.read_text() == "git\n"

    (repo / "hosts/A/aur.txt").write_text("random-unapproved-bin\n")
    assert "unapproved AUR package" in audit(ok=False).stderr
    (repo / "hosts/A/aur.txt").unlink()

    (repo / "hosts/A/packages.txt").write_text("zed\n")
    assert "first-party self-managed" in audit(ok=False).stderr
    (repo / "hosts/A/packages.txt").unlink()
    (repo / "hosts/A/aur.txt").write_text("mise\n")
    assert "first-party self-managed" in audit(ok=False).stderr
    (repo / "hosts/A/aur.txt").unlink()

    # Declined groups do not become attempted packages, unknown chosen groups fail.
    (repo / "hosts/A/optional.txt").write_text("nonexistent\n")
    assert "unknown optional group" in audit(ok=False).stderr
print("package gates: Shelly-only AUR, missing CLI, repo availability and consent: OK")
