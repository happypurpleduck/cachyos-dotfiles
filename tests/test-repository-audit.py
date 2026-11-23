#!/usr/bin/env python3
"""Repository-wide portable-source and policy audit (read-only).

Runs against the actual checkout, in addition to disposable two-host fixtures.
Never opens the user's real HOME or activates any configuration.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import re
import subprocess
import sys

repo = Path(__file__).resolve().parents[1]
assert (repo / "install").is_file()
assert (repo / "common").is_dir()
assert (repo / "hosts/_template").is_dir()

# Shared packages and seed files must never refer to a specific account's
# absolute path. Host-specific paths are allowed under hosts/<host>.
leaks: list[str] = []
hardcoded_home = re.compile(r"/home/[A-Za-z][A-Za-z0-9._-]*/")
for relative in ("common", "seed", "hosts/_template"):
    for path in (repo / relative).rglob("*"):
        if path.is_symlink():
            if not path.exists():
                leaks.append(f"{path.relative_to(repo)}: broken symlink")
            continue
        if not path.is_file() or path.stat().st_size > 2_000_000:
            continue
        try:
            data = path.read_bytes()
        except OSError:
            continue
        if b"\0" in data:
            continue
        content = data.decode("utf-8", errors="replace")
        for number, line in enumerate(content.splitlines(), 1):
            if hardcoded_home.search(line):
                leaks.append(f"{path.relative_to(repo)}:{number}: {line[:160]}")

# Shared sources must have unique destination targets. Host overrides are
# deliberate; an unrelated host must never be scanned into the effective plan.
def module_at(path: Path):
    spec = importlib.util.spec_from_file_location(path.stem.replace("-", "_"), path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module

planner = module_at(repo / "scripts/effective-targets.py")
hosts = sorted(
    p.name for p in (repo / "hosts").iterdir()
    if p.is_dir() and p.name != "_template"
)
assert hosts, "at least one host profile must exist"
for host in hosts:
    entries = planner.plan(repo, host)
    destinations = [e.path for e in entries]
    assert len(destinations) == len(set(destinations)), host
    assert all(e.owner == f"host:{host}" or e.owner.startswith("common:")
               for e in entries), host
    assert not any(e.owner.startswith("host:") and e.owner != f"host:{host}"
                   for e in entries), host

# AUR remains an explicit exception, not a general application channel.
auditor = module_at(repo / "scripts/package-audit.py")
for host in hosts:
    auditor.requirements(repo, host)
    for package in ("mise", "mise-bin", "zed", "zed-editor", "zed-bin", "zed-git"):
        required, aur = auditor.requirements(repo, host)
        if package in required or package in aur:
            leaks.append(f"{host}: self-managed app {package!r} listed in pacman/AUR requirements")
for group in (repo / "packages/optional").glob("*.txt"):
    text = group.read_text(encoding="utf-8")
    for line in text.splitlines():
        name = line.split("#", 1)[0].strip().removeprefix("aur:")
        if name in {"mise", "zed", "zed-editor", "mise-bin", "zed-bin", "zed-git"}:
            leaks.append(f"{group.relative_to(repo)}: self-managed app {name}")

if leaks:
    print("Repository portability/policy audit failed:", file=sys.stderr)
    for leak in leaks:
        print("  " + leak, file=sys.stderr)
    raise SystemExit(1)

print(f"repository audit: {len(hosts)} profiles, no hardcoded shared home paths, "
      "effective target isolation and minimal AUR policy OK")
