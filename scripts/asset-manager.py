#!/usr/bin/env python3
"""Optional CachyOS desktop assets: verified, staged, and safely retryable.

No remote shell installers. Optional failures are reported but do not prevent
the core dotfiles link/first-login fallback from working.
"""
from __future__ import annotations

import argparse
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from zipfile import ZipFile, BadZipFile
from uuid import uuid4

WALLS = "https://github.com/orangci/walls-catppuccin-mocha.git"
CURSORS = "https://github.com/catppuccin/cursors/releases/latest/download/catppuccin-mocha-dark-cursors.zip"
UOSC = "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip"
THUMBFAST = "https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua"
ANIME4K = "https://github.com/bloc97/Anime4K/releases/download/v4.0.1/Anime4K_v4.0.zip"
NIGHTLIES = "https://api.github.com/repos/pingdotgg/t3code/releases?per_page=20"
NAMES = ("wallpapers", "cursors", "uosc", "thumbfast", "anime4k", "t3code", "zed", "mise")


def locations(home: Path) -> dict[str, Path]:
    mpv = home / ".config/mpv"
    return {
        "wallpapers": home / "Pictures/Wallpapers/catppuccin-mocha",
        "cursors": home / ".local/share/icons/catppuccin-mocha-dark-cursors",
        "uosc": mpv / "scripts/uosc",
        "thumbfast": mpv / "scripts/thumbfast.lua",
        "anime4k": mpv / "shaders/Anime4K_Clamp_Highlights.glsl",
        "t3code": home / ".local/opt/t3code/T3-Code.AppImage",
        "zed": home / ".local/zed.app",
        "mise": home / ".local/bin/mise",
    }


def status(home: Path) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for name, dest in locations(home).items():
        if name == "mise":
            installed = bool(shutil.which("mise")) or dest.is_file()
        elif name == "zed":
            installed = bool(shutil.which("zed")) or dest.exists()
        elif name == "cursors":
            installed = (dest / "index.theme").is_file() and (dest / "cursors").is_dir()
        elif name == "wallpapers":
            installed = dest.is_dir() and any(
                p.is_file() and p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")
                for p in dest.rglob("*")
            )
        elif name == "uosc":
            installed = dest.is_dir() and any(dest.rglob("*.lua"))
        elif name == "t3code":
            installed = dest.is_file() and dest.stat().st_size > 100 * 1024
            if installed:
                with dest.open("rb") as f:
                    installed = f.read(4) == b"\x7fELF"
        elif name in ("thumbfast", "anime4k"):
            installed = dest.is_file() and dest.stat().st_size > 100
        else:
            installed = dest.exists()
        out[name] = {"installed": installed, "path": str(dest), "optional": True}
    return out


def download(url: str, max_size: int, attempts: int = 3) -> bytes:
    if not url.startswith("https://"):
        raise ValueError("only HTTPS asset downloads are permitted")
    for attempt in range(attempts):
        try:
            request = Request(url, headers={"User-Agent": "cachyos-dotfiles/1",
                                            "Accept": "application/octet-stream"})
            with urlopen(request, timeout=35) as response:
                length = response.headers.get("Content-Length")
                if length and int(length) > max_size:
                    raise ValueError("asset exceeds declared size limit")
                chunks = []
                size = 0
                while True:
                    part = response.read(1024 * 1024)
                    if not part:
                        break
                    size += len(part)
                    if size > max_size:
                        raise ValueError("asset exceeds declared size limit")
                    chunks.append(part)
                if size < 32:
                    raise ValueError("empty or suspiciously short asset response")
                return b"".join(chunks)
        except (HTTPError, URLError, OSError) as exc:
            if attempt + 1 == attempts:
                raise ValueError(f"{url}: download failed after {attempts} tries: {exc}") from exc
            time.sleep(min(2 ** attempt, 4))
    raise ValueError("unreachable download failure")


def atomic_file(dst: Path, data: bytes, *, executable=False) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".download-", dir=dst.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        if executable:
            os.chmod(tmp, 0o755)
        os.replace(tmp, dst)
    finally:
        if os.path.lexists(tmp):
            os.unlink(tmp)


def archive_files(data: bytes) -> dict[str, bytes]:
    try:
        with ZipFile(io.BytesIO(data)) as z:
            result: dict[str, bytes] = {}
            total_uncompressed = 0
            for info in z.infolist():
                p = Path(info.filename)
                if (info.is_dir() or p.is_absolute()
                        or ".." in p.parts or "\\" in info.filename):
                    if not info.is_dir():
                        raise ValueError("unsafe archive member: " + info.filename)
                    continue
                total_uncompressed += info.file_size
                if info.file_size > 40 * 1024 * 1024 or total_uncompressed > 250 * 1024 * 1024:
                    raise ValueError("oversized decompressed archive")
                result[p.as_posix()] = z.read(info)
            return result
    except BadZipFile as exc:
        raise ValueError("invalid downloaded ZIP") from exc


def swap_directory(target: Path, prepared: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    old = target.with_name(target.name + ".previous-" + uuid4().hex[:12])
    if target.exists() or target.is_symlink():
        os.replace(target, old)
    try:
        os.replace(prepared, target)
    except BaseException:
        if old.exists() or old.is_symlink():
            os.replace(old, target)
        raise
    if old.is_dir() and not old.is_symlink():
        shutil.rmtree(old)
    elif old.is_symlink() or old.exists():
        old.unlink()


def install_cursor(home: Path) -> None:
    target = locations(home)["cursors"]
    contents = archive_files(download(CURSORS, 60 * 1024 * 1024))
    matches = [p for p in contents if p.endswith("/index.theme") or p == "index.theme"]
    if not matches:
        raise ValueError("cursor ZIP has no index.theme")
    base = matches[0].removesuffix("index.theme")
    subset = {name[len(base):]: data for name, data in contents.items()
              if name.startswith(base) and name[len(base):]}
    if not any(name.startswith("cursors/") for name in subset):
        raise ValueError("cursor ZIP has no cursor files")
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=target.parent) as tmp:
        prepared = Path(tmp) / "cursor-theme"
        prepared.mkdir()
        for name, data in subset.items():
            atomic_file(prepared / name, data)
        swap_directory(target, prepared)


def install_wallpapers(home: Path) -> None:
    target = locations(home)["wallpapers"]
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=target.parent) as tmp:
        staging = Path(tmp) / "wallpapers"
        subprocess.run(["git", "clone", "--quiet", "--depth", "1", WALLS,
                        str(staging)], check=True, timeout=180)
        if not any(p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
                   for p in staging.rglob("*") if p.is_file()):
            raise ValueError("wallpaper checkout contains no images")
        swap_directory(target, staging)


def install_zip_group(home: Path, name: str) -> None:
    mpv = home / ".config/mpv"
    url = UOSC if name == "uosc" else ANIME4K
    files = archive_files(download(url, 150 * 1024 * 1024))
    selected: dict[str, bytes] = {}
    if name == "uosc":
        selected = {p: data for p, data in files.items()
                    if p.startswith(("scripts/uosc/", "fonts/"))}
        if not any(p.startswith("scripts/uosc/") for p in selected):
            raise ValueError("uosc archive lacks scripts/uosc files")
    else:
        selected = {f"shaders/{Path(p).name}": data for p, data in files.items()
                    if p.endswith(".glsl")}
        if not any("Clamp_Highlights" in p for p in selected):
            raise ValueError("Anime4K archive missing expected shader")
    # Every file is atomically promoted after the full archive is validated.
    for rel, data in selected.items():
        if not data:
            raise ValueError(f"empty archive file: {rel}")
        atomic_file(mpv / rel, data)


def nightly_asset(releases: object) -> tuple[str, str]:
    if not isinstance(releases, list):
        raise ValueError("GitHub release API returned a non-list response (rate limit?)")
    for release in releases:
        if not isinstance(release, dict):
            continue
        tag = release.get("tag_name")
        if (not release.get("prerelease") or not isinstance(tag, str)
                or "nightly" not in tag or not re.fullmatch(r"[A-Za-z0-9._-]+", tag)):
            continue
        assets = release.get("assets") or []
        for asset in assets:
            name = asset.get("name", "") if isinstance(asset, dict) else ""
            url = asset.get("browser_download_url", "") if isinstance(asset, dict) else ""
            if (re.fullmatch(r"[A-Za-z0-9._-]+\.AppImage", name)
                    and url.startswith(f"https://github.com/pingdotgg/t3code/releases/download/{tag}/")):
                return tag, url
        # Legacy update YAML: verify tag and all path characters before use.
        yml = (f"https://github.com/pingdotgg/t3code/releases/download/"
               f"{tag}/nightly-linux.yml")
        try:
            body = download(yml, 128 * 1024).decode("utf-8")
        except (ValueError, UnicodeError):
            continue
        m = re.search(r"^path:\s*([A-Za-z0-9._-]+\.AppImage)\s*$",
                      body, flags=re.MULTILINE)
        if m:
            return tag, f"https://github.com/pingdotgg/t3code/releases/download/{tag}/{m.group(1)}"
    raise ValueError("no valid T3 Code Linux nightly AppImage found; optional asset skipped")


def install_t3code(home: Path) -> None:
    releases = json.loads(download(NIGHTLIES, 4 * 1024 * 1024))
    tag, url = nightly_asset(releases)
    data = download(url, 600 * 1024 * 1024)
    if not data.startswith(b"\x7fELF") or len(data) < 100 * 1024:
        raise ValueError("download is not a plausible Linux AppImage")
    target = locations(home)["t3code"]
    atomic_file(target, data, executable=True)
    atomic_file(target.parent / ".version.json",
                (json.dumps({"source": url, "tag": tag}, indent=2) + "\n").encode())


def install_asset(home: Path, name: str) -> None:
    loc = locations(home)
    if name == "wallpapers":
        install_wallpapers(home)
    elif name == "cursors":
        install_cursor(home)
    elif name in ("uosc", "anime4k"):
        install_zip_group(home, name)
    elif name == "thumbfast":
        body = download(THUMBFAST, 3 * 1024 * 1024)
        if len(body) < 200 or b"function" not in body:
            raise ValueError("thumbfast download failed content sanity check")
        atomic_file(loc[name], body)
    elif name == "t3code":
        install_t3code(home)
    elif name == "zed":
        raise ValueError("manual optional install only: use the CachyOS/Arch zed package; no remote shell installer")
    elif name == "mise":
        binary = shutil.which("mise") or (
            str(loc["mise"]) if loc["mise"].is_file() else None
        )
        if not binary:
            raise ValueError("manual optional install only: install mise from a trusted package source")
        subprocess.run([binary, "install", "--yes"], check=True, timeout=300)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--status", action="store_true", help="offline asset status")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--asset", choices=NAMES, action="append")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    home = args.home.expanduser().resolve()
    if home != Path.home().resolve():
        print("asset manager must run as the selected home owner", file=sys.stderr)
        return 2
    initial = status(home)
    if args.status:
        if args.json:
            print(json.dumps(initial, indent=2))
        else:
            for name, info in initial.items():
                print(f"{name}: {'installed' if info['installed'] else 'missing'} ({info['path']})")
        return 0
    failures = {}
    for name in args.asset or NAMES:
        if initial[name]["installed"] and not args.force:
            print(f"{name}: already installed, skipped")
            continue
        try:
            print(f"{name}: acquiring (optional)")
            install_asset(home, name)
        except (ValueError, OSError, subprocess.SubprocessError) as exc:
            failures[name] = str(exc)
            print(f"!! {name}: {exc}", file=sys.stderr)
    print(f"optional assets: {len(failures)} failed, {len(NAMES) - len(failures)} without errors")
    if args.strict or args.asset:
        return 1 if failures else 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
