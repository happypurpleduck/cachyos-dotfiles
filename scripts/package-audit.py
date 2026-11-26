#!/usr/bin/env python3
"""CachyOS-only package plan. Audit first; never silently skip requirements."""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

NAME = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9@+_.-]*$")


def read_packages(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    found: set[str] = set()
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        value = line.split("#", 1)[0].strip()
        if not value:
            continue
        if len(value.split()) != 1 or not NAME.fullmatch(value):
            raise ValueError(f"invalid package at {path}:{number}: {value!r}")
        found.add(value)
    return found


def requirements(repo: Path, host: str) -> tuple[set[str], set[str]]:
    from runpy import run_path
    # Host naming/checkout validation matches the link ownership planner.
    run_path(str(repo / "scripts/effective-targets.py"))["plan"](repo, host)
    required = read_packages(repo / "packages/common.txt")
    required |= read_packages(repo / "hosts" / host / "packages.txt")
    common_aur = read_packages(repo / "packages/aur.txt")
    aur = common_aur | read_packages(repo / "hosts" / host / "aur.txt")
    optional_path = repo / "hosts" / host / "optional.txt"
    # '!' records declined optional groups, not package names.
    selected: set[str] = set()
    if optional_path.is_file():
        for raw in optional_path.read_text(encoding="utf-8").splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line or line.startswith("!"):
                continue
            if not NAME.fullmatch(line):
                raise ValueError(f"invalid optional group: {line!r}")
            selected.add(line)
    for group in selected:
        file = repo / "packages/optional" / f"{group}.txt"
        if not file.is_file():
            raise ValueError(f"unknown optional group '{group}'")
        for item in read_packages_allow_aur(file):
            (aur if item.startswith("aur:") else required).add(
                item.removeprefix("aur:")
            )
    upstream_only = (required | aur) & {"mise", "zed"}
    if upstream_only:
        raise ValueError("mise/Zed must use first-party self-managed installs; remove from package declarations: "
                         + ", ".join(sorted(upstream_only)))

    # Every AUR dependency must be an explicit, reviewed exception.
    policy_path = repo / "packages/aur-exceptions.json"
    if aur and not policy_path.is_file():
        raise ValueError("AUR exception policy is missing; refusing all AUR packages")
    exceptions = json.loads(policy_path.read_text(encoding="utf-8")) if policy_path.is_file() else {}
    if not isinstance(exceptions, dict):
        raise ValueError("invalid AUR exception policy format")
    for name in sorted(aur):
        record = exceptions.get(name)
        if (not isinstance(record, dict)
                or record.get("scope") not in ("common", "host")
                or not record.get("reason") or not record.get("review")):
            raise ValueError(f"unapproved AUR package '{name}': document an explicit exception first")
        if name in common_aur and record["scope"] != "common":
            raise ValueError(f"AUR package '{name}' is host-only; cannot enable globally")

    overlap = required & aur
    if overlap:
        raise ValueError("declared in repo and AUR lists: " + ", ".join(sorted(overlap)))
    return required, aur


def read_packages_allow_aur(path: Path) -> set[str]:
    values: set[str] = set()
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        value = line.split("#", 1)[0].strip()
        if not value:
            continue
        candidate = value.removeprefix("aur:")
        if len(value.split()) != 1 or not NAME.fullmatch(candidate):
            raise ValueError(f"invalid optional package {path}:{number}: {value!r}")
        values.add(value)
    return values


def query(args: list[str]) -> set[str]:
    return set(subprocess.run(args, check=True, capture_output=True,
                              text=True, timeout=120).stdout.splitlines())


def audit(repo: Path, host: str) -> dict:
    required, aur = requirements(repo, host)
    # Shelly is the only package backend: queries and installs alike.
    shelly = shutil.which("shelly")
    if not shelly:
        return {
            "status": "shelly-unavailable", "desired_repo": sorted(required),
            "desired_aur": sorted(aur), "missing_repo": [], "missing_aur": [],
            "unavailable_repo": [], "shelly": None, "blocking": True,
        }
    installed = query([shelly, "list", "standard", "--names-only"])
    repo_available = query([shelly, "search", "standard", "--available", "--names-only"])
    missing_repo = sorted(required - installed)
    missing_aur = sorted(aur - installed)
    unavailable = sorted(set(missing_repo) - repo_available)
    return {
        "status": "ok", "desired_repo": sorted(required),
        "desired_aur": sorted(aur), "missing_repo": missing_repo,
        "missing_aur": missing_aur, "unavailable_repo": unavailable,
        "shelly": shelly, "blocking": bool(unavailable),
    }


def install_command(shelly: str, kind: str, packages: list[str]) -> list[str]:
    """Non-interactive Shelly install; Shelly elevates via pkexec/run0/sudo itself.

    Repository installs carry --upgrade: the system is upgraded in the same
    transaction (pacman -Syu pkg…). Arch doesn't support partial upgrades: new
    packages from a fresh database can need newer versions of libraries that
    installed packages pin exactly (gstreamer=1.28.9-3), and alpm refuses.
    """
    if kind not in ("standard", "aur"):
        raise ValueError(f"unsupported package type: {kind}")
    upgrade = ["--upgrade"] if kind == "standard" else []
    return [shelly, "install", kind, *upgrade, "--needed", "--no-confirm", *packages]


def sync_command(shelly: str) -> list[str]:
    """Refresh the ALPM package databases before deciding what to install.

    A stale database asks mirrors for versions they have already deleted (a
    mirror answering with an HTML page and HTTP 200 leaves a fake package in the
    cache) and reports packages newer than it as unavailable.
    """
    return [shelly, "sync", "standard", "--no-confirm"]


def upgrade_command(shelly: str) -> list[str]:
    """Full repository upgrade, for when only AUR packages need installing."""
    return [shelly, "upgrade", "standard", "--no-confirm"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--host", required=True)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--install", action="store_true",
                        help="install missing declared packages via Shelly")
    args = parser.parse_args()
    try:
        data = audit(args.repo.resolve(strict=True), args.host)
        # Refresh only when there is something to install, so an up-to-date
        # host never prompts for elevation; then re-audit, since a package that
        # looked unavailable may just be newer than the stale database.
        if args.install and data["shelly"] and (
                data["missing_repo"] or data["missing_aur"]):
            print("packages: refreshing package databases before installing", file=sys.stderr)
            subprocess.run(sync_command(data["shelly"]), check=True)
            data = audit(args.repo.resolve(strict=True), args.host)
        if args.json:
            print(json.dumps(data, indent=2))
        else:
            print(f"Package audit for {args.host}: {data['status']}")
            print(f"  repo missing: {', '.join(data['missing_repo']) or 'none'}")
            print(f"  AUR missing: {', '.join(data['missing_aur']) or 'none'}")
            print(f"  repo unavailable: {', '.join(data['unavailable_repo']) or 'none'}")
            print(f"  Shelly CLI: {data['shelly'] or 'unavailable'}")
            if data["blocking"]:
                if data["unavailable_repo"]:
                    print("  BLOCKED: required repository packages are unavailable")
                else:
                    print("  BLOCKED: Shelly CLI unavailable "
                          "(install the official CachyOS shelly package)")
        if data["blocking"]:
            return 2
        if args.install:
            if data["missing_repo"]:
                subprocess.run(install_command(data["shelly"], "standard",
                                               data["missing_repo"]), check=True)
            elif data["missing_aur"]:
                # AUR builds resolve their repo dependencies against the fresh
                # database too, so bring the system up to it first.
                subprocess.run(upgrade_command(data["shelly"]), check=True)
            if data["missing_aur"]:
                subprocess.run(install_command(data["shelly"], "aur",
                                               data["missing_aur"]), check=True)
            verified = audit(args.repo.resolve(strict=True), args.host)
            if verified["missing_repo"] or verified["missing_aur"]:
                raise ValueError("package manager reported success but required packages remain absent")
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        print(f"packages: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
