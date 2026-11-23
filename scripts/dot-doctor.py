#!/usr/bin/env python3
"""Read-only CachyOS dotfiles preflight. Never installs, links or changes the host."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys


def effective_plan(repo: Path, host: str):
    # Keep issue #2's read-only planner as the single precedence authority.
    return runpy.run_path(str(repo / "scripts/effective-targets.py"))["plan"](repo, host)


def inside(path: Path, base: Path) -> bool:
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


def nearest_obstruction(home: Path, target: Path) -> tuple[str, str] | None:
    parent = target.parent
    while parent != home:
        if parent.is_symlink():
            return ("folded-parent", str(parent))
        if parent.exists() and not parent.is_dir():
            return ("blocked-parent", str(parent))
        if not inside(parent, home):
            return ("outside-home", str(parent))
        parent = parent.parent
    if home.is_symlink() or not home.is_dir():
        return ("invalid-home", str(home))
    return None


def check_target(home: Path, entry, repo: Path) -> dict:
    target = home / entry.path
    record = entry.as_dict(home)
    obstruction = nearest_obstruction(home, target)
    if obstruction:
        record.update(status=obstruction[0], detail=obstruction[1])
        return record
    if target.is_symlink():
        actual = target.resolve(strict=False)
        intended = entry.source.resolve(strict=False)
        if actual == intended:
            record.update(status="ok", detail="")
        elif inside(actual, repo / "common") or inside(actual, repo / "hosts"):
            record.update(status="managed-different", detail=str(actual))
        else:
            record.update(status="foreign-symlink", detail=str(actual))
    elif target.exists():
        record.update(
            status="collision-directory" if target.is_dir() else "collision-file",
            detail=str(target),
        )
    else:
        record.update(status="missing", detail="")
    return record


def package_names(path: Path) -> list[str]:
    if not path.is_file():
        return []
    return [
        line.split("#", 1)[0].strip().split()[0]
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.split("#", 1)[0].strip()
    ]


def packages_status(repo: Path, host: str) -> dict:
    names = set(package_names(repo / "packages/common.txt"))
    names.update(package_names(repo / "hosts" / host / "packages.txt"))
    aurs = set(package_names(repo / "packages/aur.txt"))
    aurs.update(package_names(repo / "hosts" / host / "aur.txt"))
    for selected in package_names(repo / "hosts" / host / "optional.txt"):
        opt = repo / "packages/optional" / f"{selected}.txt"
        for item in package_names(opt):
            if item.startswith("aur:"):
                aurs.add(item[4:])
            else:
                names.add(item)
    pacman = shutil.which("pacman")
    if not pacman:
        return {
            "status": "pacman-unavailable",
            "missing": [],
            "desired_repo": len(names),
            "desired_aur": len(aurs),
            "aur_helper": bool(shutil.which("paru")),
        }
    try:
        installed = subprocess.run(
            [pacman, "-Qq"],
            capture_output=True, text=True, check=True, timeout=15,
        ).stdout.splitlines()
    except (OSError, subprocess.SubprocessError) as exc:
        return {
            "status": "query-failed", "error": str(exc), "missing": [],
            "desired_repo": len(names), "desired_aur": len(aurs),
            "aur_helper": bool(shutil.which("paru")),
        }
    return {
        "status": "ok", "missing": sorted((names | aurs) - set(installed)),
        "desired_repo": len(names), "desired_aur": len(aurs),
        "aur_helper": bool(shutil.which("paru")),
    }


def report(repo: Path, home: Path, host: str) -> dict:
    entries = effective_plan(repo, host)
    records = [check_target(home, e, repo) for e in entries]
    counts: dict[str, int] = {}
    for record in records:
        status = record["status"]
        counts[status] = counts.get(status, 0) + 1
    # Never mutate /etc, services, login manager or current home in a preview.
    display_link = Path("/etc/systemd/system/display-manager.service")
    display_manager = (
        str(display_link.resolve(strict=False)) if display_link.is_symlink()
        else "not detected"
    )
    return {
        "repo": str(repo), "home": str(home), "host": host,
        "targets": records, "counts": counts,
        "blocking_targets": [
            e for e in records if e["status"] not in {"ok", "missing", "managed-different"}
        ],
        "packages": packages_status(repo, host),
        "prerequisites": {
            command: bool(shutil.which(command))
            for command in ("git", "python3", "stow", "pacman", "systemctl")
        },
        "system_changes": {
            "display_manager": display_manager,
            "plan": "not performed; system/setup and greeter need independent approval",
            "greeter_activation": "never included in doctor or link dry-run",
        },
        "assets": "not checked yet; tracked in issue #8",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--host", required=True)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true",
                        help="return failure on collisions or missing packages")
    args = parser.parse_args()
    try:
        repo = args.repo.resolve(strict=True)
        home = args.home.expanduser().resolve(strict=True)
        data = report(repo, home, args.host)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        print(f"dot doctor: {exc}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(data, indent=2))
    else:
        print(f"dot doctor — host {data['host']} at {data['home']}")
        print(f"  repo: {data['repo']}")
        for status, count in sorted(data["counts"].items()):
            print(f"  {status}: {count}")
        for item in data["targets"]:
            if item["status"] not in ("ok", "missing"):
                print(f"  !! {item['status']}: {item['path']} ({item['detail']})")
        pkgs = data["packages"]
        print(f"  packages: {pkgs['status']}, missing: {len(pkgs['missing'])}")
        if pkgs["missing"]:
            print("    missing: " + ", ".join(pkgs["missing"]))
        print("  system: existing display manager "
              f"{data['system_changes']['display_manager']} (unchanged)")
        print("  dry run only: no links, packages, services, backups, or /etc modifications")
        if data["blocking_targets"]:
            print("  BLOCKED: resolve collisions and folded/foreign parent links before apply")

    if args.strict and (data["blocking_targets"] or data["packages"]["missing"]
                        or data["packages"]["status"] != "ok"):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
