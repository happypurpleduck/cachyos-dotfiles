#!/usr/bin/env python3
"""Fetch and inspect prospective changes before Git mutates linked config.

A normal pull never updates active shared/current-host sources unexpectedly.
Use --apply only after reviewing changes and satisfying dependencies.
"""
from __future__ import annotations

import argparse
from io import BytesIO
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tarfile
import tempfile


def git(repo: Path, *args: str, output=False) -> str:
    p = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True, text=True, check=True, timeout=90,
    )
    return p.stdout.strip() if output else ""


def active_path(path: str, host: str) -> bool:
    return (
        path.startswith("common/")
        or path.startswith(f"hosts/{host}/home/")
        or path.startswith(f"hosts/{host}/packages.txt")
        or path.startswith(f"hosts/{host}/aur.txt")
        or path.startswith(f"hosts/{host}/optional.txt")
        or path.startswith("packages/")
        or path.startswith("system/")
        or path.startswith("scripts/")
        or path == "install"
    )


def preview(repo: Path, host: str, home: Path, *, apply=False) -> dict:
    git(repo, "fetch", "--quiet", "--prune")
    upstream = git(repo, "rev-parse", "--abbrev-ref",
                   "--symbolic-full-name", "@{upstream}", output=True)
    remote_sha = git(repo, "rev-parse", upstream, output=True)
    merge_base = git(repo, "merge-base", "HEAD", upstream, output=True)
    raw = subprocess.run(
        ["git", "-C", str(repo), "diff", "--name-only", "-z",
         merge_base, upstream], capture_output=True, check=True, timeout=30,
    ).stdout
    changed = [p.decode("utf-8", "surrogateescape") for p in raw.split(b"\0") if p]
    active = [p for p in changed if active_path(p, host)]
    result = {"upstream": upstream, "upstream_sha": remote_sha, "changed": changed,
              "active": active, "package_missing": []}
    if active and not apply:
        return result
    if not active:
        return result

    # Use an archive to inspect exactly the remote commit, without checking it
    # out into HOME or modifying the working tree / any live linked source.
    with tempfile.TemporaryDirectory(prefix="dotfiles-preflight-") as temp:
        staged = Path(temp) / "repo"
        staged.mkdir()
        proc = subprocess.run(["git", "-C", str(repo), "archive", "--format=tar",
                               upstream], capture_output=True, check=True, timeout=60)
        with tarfile.open(fileobj=BytesIO(proc.stdout), mode="r:") as archive:
            archive.extractall(staged, filter="data")
        git(staged, "init", "-q")
        git(staged, "add", "-A")
        planner = staged / "scripts/effective-targets.py"
        current = repo / "scripts/effective-targets.py"
        if planner.is_file() and current.is_file():
            prospective = runpy.run_path(str(planner))["plan"](staged, host)
            existing = runpy.run_path(str(current))["plan"](repo, host)
            existing_paths = {entry.path for entry in existing}
            # A remote newly managed target must not replace a local app
            # file/symlink or sit under a legacy folded Stow directory.
            for entry in prospective:
                if entry.path in existing_paths:
                    continue
                target = home / entry.path
                if os.path.lexists(target):
                    raise ValueError(
                        f"remote adds managed target over existing user state: {target}"
                    )
                parent = target.parent
                while parent != home:
                    if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
                        raise ValueError(f"remote target has obstructed parent: {parent}")
                    parent = parent.parent
        if any(p.startswith("packages/") or
               p.startswith(f"hosts/{host}/packages.txt") or
               p.startswith(f"hosts/{host}/aur.txt") or
               p.startswith(f"hosts/{host}/optional.txt")
               for p in active):
            auditor = staged / "scripts/package-audit.py"
            if auditor.is_file():
                audit = runpy.run_path(str(auditor))["audit"](staged, host)
                if audit["blocking"]:
                    raise ValueError(
                        "remote package/AUR requirements unavailable: "
                        + ", ".join(audit["unavailable_repo"] or audit["missing_aur"])
                    )
                needed = sorted(set(audit["missing_repo"] + audit["missing_aur"]))
                result["package_missing"] = needed
                if needed:
                    raise ValueError(
                        "remote config requires packages before sync: "
                        + ", ".join(needed)
                        + "; explicitly install and verify prerequisites first"
                    )
        if not (staged / "hosts" / host / "home").is_dir():
            raise ValueError(f"remote profile hosts/{host}/home missing")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--host", required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--emit-sha", action="store_true")
    args = parser.parse_args()
    try:
        data = preview(args.repo.resolve(strict=True), args.host,
                       args.home.expanduser().resolve(strict=True),
                       apply=args.apply)
        if args.json:
            print(json.dumps(data, indent=2))
        else:
            stream = sys.stderr if args.emit_sha else sys.stdout
            print(f"remote: {data['upstream']} ({data['upstream_sha'][:12]})", file=stream)
            for path in data["changed"]:
                print(f"  {'ACTIVE' if path in data['active'] else 'foreign/metadata'}: {path}", file=stream)
            if data["active"] and not args.apply:
                print("BLOCKED: remote changes would affect active/shared configuration.", file=stream)
                print("Review changes, then explicitly run: dot pull --apply", file=stream)
                return 3
            if args.emit_sha:
                print(data["upstream_sha"])
            else:
                print("preflight passed; linked source can update only after explicit rebase")
        return 0
    except (OSError, ValueError, subprocess.SubprocessError,
            tarfile.TarError) as exc:
        print(f"pull preflight: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
