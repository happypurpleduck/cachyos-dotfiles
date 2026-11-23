#!/usr/bin/env python3
"""Install user-owned self-updating apps from their FIRST-PARTY Linux installers.

Never runs during dot install or package audit. Invoking dot apps install NAME
explicitly opts in to executing the vendor-maintained installer. Use pacman
for system dependencies, not for these self-managed application binaries.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlparse
from urllib.request import Request, urlopen


APPS = {
    "mise": {
        "url": "https://mise.run",
        "domains": ("mise.run", "mise.jdx.dev"),
        "binary": ".local/bin/mise",
        "updater": "mise self-update --yes --no-plugins",
        "documentation": "https://mise.jdx.dev/cli/self-update.html",
    },
    "zed": {
        "url": "https://zed.dev/install.sh",
        "domains": ("zed.dev",),
        "binary": ".local/zed.app/bin/zed",
        "updater": "Zed automatically updates on restart (official installer build)",
        "documentation": "https://zed.dev/docs/update",
    },
}


def app_state(home: Path, name: str) -> dict:
    config = APPS[name]
    local = home / config["binary"]
    executable = shutil.which(name)
    managed = local.is_file()
    external = executable if executable and (
        Path(executable).resolve(strict=False) != local.resolve(strict=False)
    ) else None
    return {
        "installed": managed or bool(executable),
        "upstream_managed": managed,
        "local_executable": str(local),
        "detected_executable": executable,
        "other_installation": external,
        "updater": config["updater"],
        "documentation": config["documentation"],
    }


def status(home: Path) -> dict:
    return {name: app_state(home, name) for name in APPS}


def fetch_vendor_script(name: str) -> tuple[bytes, str]:
    config = APPS[name]
    request = Request(config["url"], headers={
        "User-Agent": "cachyos-dotfiles-upstream-bootstrap/1",
        "Accept": "text/plain",
    })
    # urllib verifies TLS certificates; reject HTTP redirects, unexpected
    # publishing domains, or unbounded responses before executing anything.
    with urlopen(request, timeout=30) as response:
        final_url = response.geturl()
        parsed = urlparse(final_url)
        if parsed.scheme != "https" or parsed.hostname not in config["domains"]:
            raise ValueError(f"untrusted installer redirect: {final_url}")
        declared = response.headers.get("Content-Length")
        if declared and int(declared) > 2 * 1024 * 1024:
            raise ValueError("vendor installation script is unexpectedly large")
        body = response.read(2 * 1024 * 1024 + 1)
    if not 200 <= len(body) <= 2 * 1024 * 1024 or b"\0" in body:
        raise ValueError("invalid or unexpectedly small vendor installation script")
    if not body.lstrip().startswith((b"#!/bin/", b"#!/usr/bin/env ")):
        raise ValueError("downloaded content is not an expected shell installer")
    return body, final_url


def install(home: Path, name: str) -> None:
    current = app_state(home, name)
    if current["upstream_managed"]:
        print(f"{name}: user-local installation already present; update using {current['updater']}")
        return
    if current["other_installation"]:
        raise ValueError(
            f"{name}: an installation already exists at {current['other_installation']}; "
            "do not mix pacman and upstream self-update. Migrate it manually first."
        )
    body, url = fetch_vendor_script(name)
    digest = hashlib.sha256(body).hexdigest()
    print(f"{name}: downloaded first-party installer from {url}", flush=True)
    print(f"{name}: script SHA256 {digest}", flush=True)
    print(f"{name}: running official installer as current user (no sudo)", flush=True)
    with tempfile.TemporaryDirectory(prefix=f"dot-{name}-vendor-") as directory:
        path = Path(directory) / "install.sh"
        path.write_bytes(body)
        path.chmod(0o600)
        env = dict(os.environ)
        env["HOME"] = str(home)
        if name == "zed":
            env["ZED_CHANNEL"] = "stable"
        subprocess.run(["sh", str(path)], env=env, cwd=home, check=True, timeout=480)
    fresh = app_state(home, name)
    if not fresh["upstream_managed"]:
        raise ValueError(f"{name}: installer succeeded but expected local binary is absent")
    print(f"{name}: installed from upstream; future updates owned by the application")


def update(home: Path, name: str) -> None:
    current = app_state(home, name)
    if not current["upstream_managed"]:
        raise ValueError(f"{name}: not an official local installation; install first")
    if name == "mise":
        subprocess.run([str(home / APPS[name]["binary"]), "self-update",
                        "--yes", "--no-plugins"], check=True, timeout=300)
    else:
        print("Zed checks/downloads updates itself and applies them on restart.")
        print("Keep Auto Update enabled in Zed settings; no package-manager update needed.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--json", action="store_true")
    parser.add_argument("action", nargs="?", choices=("status", "install", "update"),
                        default="status")
    parser.add_argument("names", nargs="*", choices=tuple(APPS))
    args = parser.parse_args()
    try:
        home = args.home.expanduser().resolve(strict=True)
        if home != Path.home().resolve():
            raise ValueError("run as the target account; other homes unsupported")
        if args.action == "status":
            data = status(home)
            if args.json:
                print(json.dumps(data, indent=2))
            else:
                for name, item in data.items():
                    if item["upstream_managed"]:
                        print(f"{name}: self-managed ({item['local_executable']})")
                    elif item["installed"]:
                        print(f"{name}: externally managed ({item['detected_executable']}); do not self-update")
                    else:
                        print(f"{name}: missing; dot apps install {name}")
            return 0
        if not args.names:
            raise ValueError(f"specify an application: {', '.join(APPS)}")
        for name in args.names:
            if args.action == "install":
                install(home, name)
            else:
                update(home, name)
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        print(f"upstream apps: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
