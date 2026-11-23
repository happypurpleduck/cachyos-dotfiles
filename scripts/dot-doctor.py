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
    from runpy import run_path

    path = repo / "scripts/package-audit.py"
    if path.is_file():
        data = run_path(str(path))["audit"](repo, host)
        data["missing"] = sorted(set(data["missing_repo"] + data["missing_aur"]))
        return data
    return {"status": "package-audit-unavailable", "missing": [],
            "blocking": True, "aur_helper": None}


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
    linker = repo / "scripts/dot-links.py"
    seed_actions, seed_blockers, seed_records = (
        runpy.run_path(str(linker))["inspect_seeds"](
            repo, home, {e.path for e in entries})
        if linker.is_file() else ([], [], [])
    )
    stale = (runpy.run_path(str(linker))["retired_links"](repo, home, host)
             if linker.is_file() else [])
    return {
        "repo": str(repo), "home": str(home), "host": host,
        "seeds": seed_records, "seed_blockers": seed_blockers,
        "retired_links": stale,
        "targets": records, "counts": counts,
        "blocking_targets": [
            e for e in records if e["status"] not in {"ok", "missing", "managed-different"}
        ],
        "packages": packages_status(repo, host),
        "prerequisites": {
            command: bool(shutil.which(command))
            for command in ("git", "python3", "stow", "pacman", "systemctl")
        },
        "host_services": (
            __import__("runpy").run_path(str(repo / "scripts/host-services.py"))["inspect"](repo, host)
            if (repo / "scripts/host-services.py").is_file()
            else {"host": host, "selected": [], "services": {}, "blocking": []}
        ),
        "system_changes": {
            "display_manager": display_manager,
            "plan": "not performed; system/setup and greeter need independent approval",
            "greeter_activation": "never included in doctor or link dry-run",
        },
        "assets": (
            __import__("runpy").run_path(str(repo / "scripts/asset-manager.py"))["status"](home)
            if (repo / "scripts/asset-manager.py").is_file() else {}
        ),
        "upstream_apps": (
            __import__("runpy").run_path(str(repo / "scripts/upstream-apps.py"))["status"](home)
            if (repo / "scripts/upstream-apps.py").is_file() else {}
        ),
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
        missing_assets = [name for name, asset in data["assets"].items()
                          if not asset["installed"]]
        print("  optional assets missing: " + (", ".join(missing_assets) or "none"))
        for name, app in data["upstream_apps"].items():
            mode = "upstream/self-managed" if app["upstream_managed"] else (
                "other manager" if app["installed"] else "missing"
            )
            print(f"  {name}: {mode} (dot apps status)")
        for name, item in data["host_services"]["services"].items():
            print(f"  host service {name}: "
                  f"{'ready' if item['ready'] else 'missing prerequisites'}, "
                  f"enabled={item['enabled']}, active={item['active']}")
        print("  system: existing display manager "
              f"{data['system_changes']['display_manager']} (unchanged)")
        print("  dry run only: no links, packages, services, backups, or /etc modifications")
        if data["retired_links"]:
            for item in data["retired_links"]:
                print(f"  !! {item['status']}: {item['path']} (dot link to retire)")
        if data["seeds"]:
            print("  first-use seeds missing: " + str(sum(x["status"] == "missing" for x in data["seeds"])))
        for item in data["seed_blockers"]:
            print("  BLOCKED seed: " + item)
        if data["blocking_targets"]:
            print("  BLOCKED: resolve collisions and folded/foreign parent links before apply")

    if args.strict and (data["seed_blockers"] or data["blocking_targets"] or data["packages"]["missing"]
                        or data["packages"]["blocking"]
                        or data["host_services"]["blocking"]):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
