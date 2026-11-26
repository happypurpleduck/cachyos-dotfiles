#!/usr/bin/env python3
"""Package audit tests with a fake Shelly; never install packages."""
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
if name!="shelly":
    Path(os.environ["MOCK_FORBIDDEN"]).write_text(f"{name} {args}")
    raise SystemExit(f"{name} must never be invoked")
if args==["list","standard","--names-only"]:
    print(installed.read_text(),end="")
elif args==["search","standard","--available","--names-only"]:
    print(available.read_text(),end="")
elif args in (["sync","standard","--no-confirm"],["upgrade","standard","--no-confirm"]):
    with Path(os.environ["MOCK_SHELLY_INVOCATIONS"]).open("a") as f:
        f.write(" ".join(args)+"\n")
    sync_adds=Path(os.environ["MOCK_SYNC_ADDS"])
    if sync_adds.exists():
        with available.open("a") as f: f.write(sync_adds.read_text())
elif args[:1]==["install"] and args[1] in ("standard","aur"):
    with Path(os.environ["MOCK_SHELLY_INVOCATIONS"]).open("a") as f:
        f.write(" ".join(args)+"\n")
    with installed.open("a") as f:
        for p in args[2:]:
            if not p.startswith("-"): f.write(p+"\n")
else:
    raise SystemExit(f"unexpected {name}: {args}")
'''
    for tool in ("pacman", "shelly", "sudo"):
        path = binpath / tool
        path.write_text(shim)
        path.chmod(0o755)
    shelly_commands = root / "shelly-invocations"
    forbidden = root / "forbidden-invocations"
    env = {
        **os.environ,
        "MOCK_SHELLY_INVOCATIONS": str(shelly_commands),
        "MOCK_FORBIDDEN": str(forbidden),
        "MOCK_INSTALLED": str(installed),
        "MOCK_AVAILABLE": str(available),
        "MOCK_SYNC_ADDS": str(root / "sync-adds"),
        # Only the mocks (plus git): the real shelly/pacman/sudo are unreachable.
        "PATH": str(binpath),
    }
    (binpath / "git").symlink_to(shutil.which("git"))
    (binpath / "python3").symlink_to(sys.executable)

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

    report = audit().stdout
    assert "repo missing: bat, eza, fd, krita" in report
    assert "AUR missing: google-chrome, hokum-bin, mock-aura" in report
    assert "Shelly CLI: " in report and "shelly" in report
    # One non-interactive Shelly install per backend; no approval flags.
    audit("--install")
    # The package databases are refreshed first, once, before any install.
    assert shelly_commands.read_text().splitlines() == [
        "sync standard --no-confirm",
        "install standard --upgrade --needed --no-confirm bat eza fd krita",
        "install aur --needed --no-confirm google-chrome hokum-bin mock-aura",
    ]
    assert set(installed.read_text().split()) == {
        "git", "eza", "bat", "fd", "krita", "google-chrome", "hokum-bin", "mock-aura"
    }
    assert "repo missing: none" in audit().stdout
    assert not forbidden.exists(), forbidden.read_text()

    # Nothing missing: no refresh, so an up-to-date host never asks for elevation.
    shelly_commands.unlink()
    audit("--install")
    assert not shelly_commands.exists(), shelly_commands.read_text()

    # A package only in the refreshed database installs instead of blocking.
    saved_installed, saved_available = installed.read_text(), available.read_text()
    (repo / "hosts/A/packages.txt").write_text("newpkg\n")
    (root / "sync-adds").write_text("newpkg\n")
    assert "repo unavailable: newpkg" in audit(ok=False).stdout
    audit("--install")
    assert shelly_commands.read_text().splitlines() == [
        "sync standard --no-confirm",
        "install standard --upgrade --needed --no-confirm newpkg",
    ]
    (repo / "hosts/A/packages.txt").unlink()
    (root / "sync-adds").unlink()

    # Only AUR packages missing: upgrade the repo system first, then build.
    shelly_commands.unlink()
    installed.write_text(saved_installed.replace("mock-aura\n", ""))
    audit("--install")
    assert shelly_commands.read_text().splitlines() == [
        "sync standard --no-confirm",
        "upgrade standard --no-confirm",
        "install aur --needed --no-confirm mock-aura",
    ]
    installed.write_text(saved_installed); available.write_text(saved_available)
    shelly_commands.unlink()

    # Without Shelly nothing can be queried or installed.
    installed.write_text("git\n")
    shelly_commands.unlink(missing_ok=True)
    (binpath / "shelly").unlink()
    assert "Shelly CLI unavailable" in audit(ok=False).stdout
    audit("--install", ok=False)
    assert installed.read_text() == "git\n", "installed packages without Shelly"
    assert not forbidden.exists(), "fell back to pacman/sudo without Shelly"

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
print("package gates: Shelly-only backend, AUR allowlist and missing-CLI blockers: OK")
