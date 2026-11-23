#!/usr/bin/env python3
"""Per-host optional SYSTEM services; read-only status and explicit activation.

Currently supports Bluetooth only. Never disables another machine's services
or changes the system outside an explicit --apply --confirm action.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ALLOWED = {"bluetooth": ("bluez", "bluetooth.service")}


def selected(repo: Path, host: str) -> list[str]:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", host) or host == "_template":
        raise ValueError(f"invalid host profile: {host!r}")
    config = repo / "hosts" / host / "services.txt"
    if not (repo / "hosts" / host / "home").is_dir():
        raise ValueError(f"host profile hosts/{host}/home not found")
    if not config.is_file():
        return []
    names: set[str] = set()
    for line_no, raw in enumerate(config.read_text(encoding="utf-8").splitlines(), 1):
        name = raw.split("#", 1)[0].strip()
        if not name:
            continue
        if name not in ALLOWED:
            raise ValueError(f"unsupported system service at {config}:{line_no}: {name!r}")
        names.add(name)
    return sorted(names)


def command(argv: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(argv, capture_output=True, text=True, timeout=20, check=False)


def inspect(repo: Path, host: str, ctl: str | None = None,
            pacman: str | None = None) -> dict:
    names = selected(repo, host)
    ctl = ctl or shutil.which("systemctl")
    pacman = pacman or shutil.which("pacman")
    out: dict[str, dict] = {}
    for name in names:
        pkg, unit = ALLOWED[name]
        package_installed = bool(pacman and command([pacman, "-Qq", pkg]).returncode == 0)
        unit_exists = bool(ctl and command([ctl, "cat", unit]).returncode == 0)
        enabled = bool(ctl and command([ctl, "is-enabled", unit]).returncode == 0)
        active = bool(ctl and command([ctl, "is-active", unit]).returncode == 0)
        out[name] = {
            "package": pkg, "unit": unit, "package_installed": package_installed,
            "unit_exists": unit_exists, "enabled": enabled, "active": active,
            "ready": package_installed and unit_exists,
        }
    return {"host": host, "selected": names, "services": out,
            "blocking": [name for name, item in out.items() if not item["ready"]]}


def apply(repo: Path, host: str, ctl: str | None, pacman: str | None,
          confirmation: str) -> dict:
    if confirmation != "ENABLE HOST SERVICES":
        raise ValueError("activation requires --confirm 'ENABLE HOST SERVICES'")
    data = inspect(repo, host, ctl, pacman)
    if data["blocking"]:
        raise ValueError("missing package/unit for: " + ", ".join(data["blocking"]))
    ctl = ctl or shutil.which("systemctl")
    if not ctl and data["selected"]:
        raise ValueError("systemctl is not available")
    for name in data["selected"]:
        record = data["services"][name]
        if record["enabled"] and record["active"]:
            print(f"{name}: already enabled and active, no-op")
            continue
        # Explicit caller consent. sudo is invoked by the caller only on a real
        # system; the command does not stop/disable any pre-existing service.
        print(f"{name}: enabling {record['unit']} explicitly")
        subprocess.run(["sudo", ctl, "enable", "--now", record["unit"]],
                       check=True, timeout=60)
    return inspect(repo, host, ctl, pacman)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--host", required=True)
    parser.add_argument("--systemctl", help="testing: isolated systemctl binary")
    parser.add_argument("--pacman", help="testing: isolated package-query binary")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--confirm", default="")
    args = parser.parse_args()
    try:
        repo = args.repo.resolve(strict=True)
        report = (apply(repo, args.host, args.systemctl, args.pacman, args.confirm)
                  if args.apply else inspect(repo, args.host, args.systemctl, args.pacman))
        if args.json:
            print(json.dumps(report, indent=2))
        else:
            print(f"host system services: {report['host']}")
            for name, record in report["services"].items():
                print(f"  {name}: installed={record['package_installed']} "
                      f"unit={record['unit_exists']} enabled={record['enabled']} active={record['active']}")
            if not report["selected"]:
                print("  none selected; existing system services left unchanged")
            elif not args.apply:
                print("  preview only; to activate: dot services --apply --confirm 'ENABLE HOST SERVICES'")
        return 0 if not report["blocking"] else 2
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"host services: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
