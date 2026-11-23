#!/usr/bin/env python3
"""Offline failures, validation and atomic asset retry tests."""
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from io import BytesIO
import json
from urllib.request import Request
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from zipfile import ZipFile

script = Path(__file__).resolve().parents[1] / "scripts/asset-manager.py"
loader = SourceFileLoader("asset_manager", str(script))
spec = spec_from_loader(loader.name, loader)
asset = module_from_spec(spec)
loader.exec_module(asset)

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    home = root / "some other account"
    home.mkdir()
    target = asset.locations(home)["t3code"]
    target.parent.mkdir(parents=True)
    target.write_bytes(b"\x7fELF" + b"old-build" * 20000)
    assert asset.status(home)["t3code"]["installed"]

    try:
        asset.download("https://127.0.0.1:1/nope", 1024, attempts=1)
        assert False, "network failure did not raise"
    except ValueError:
        pass
    assert b"old-build" in target.read_bytes(), "failed download replaced working file"

    def zip_bytes(entries: dict[str, bytes]) -> bytes:
        out = BytesIO()
        with ZipFile(out, "w") as z:
            for name, data in entries.items():
                z.writestr(name, data)
        return out.getvalue()

    assert asset.archive_files(zip_bytes({"scripts/uosc/main.lua": b"return 1"}))
    try:
        asset.archive_files(zip_bytes({"../bad": b"danger"}))
        assert False, "archive traversal accepted"
    except ValueError:
        pass
    try:
        asset.archive_files(b"not a zip")
        assert False, "corrupt archive accepted"
    except ValueError:
        pass

    old = root / "old"
    old.mkdir()
    (old / "generated").write_text("keep old")
    staged = root / "staged"
    staged.mkdir()
    (staged / "new").write_text("new")
    asset.swap_directory(old, staged)
    assert (old / "new").read_text() == "new"
    backups = list(root.glob("old.previous-*"))
    assert len(backups) == 1
    assert (backups[0] / "generated").read_text() == "keep old"

    # The GitHub Releases JSON API must be requested as JSON, not binary.
    # A binary Accept header causes an HTTP 415 on some API responses.
    old_urlopen = asset.urlopen
    observed = []
    def fake_urlopen(request: Request, *, timeout):
        observed.append((request.full_url, request.get_header("Accept")))
        return BytesIO(b"x" * 48)
    try:
        asset.urlopen = fake_urlopen
        assert len(asset.download(asset.NIGHTLIES, 1024, attempts=1)) == 48
        assert len(asset.download("https://github.com/example/data.zip", 1024, attempts=1)) == 48
        assert observed == [
            (asset.NIGHTLIES, "application/vnd.github+json"),
            ("https://github.com/example/data.zip", "application/octet-stream"),
        ]
    finally:
        asset.urlopen = old_urlopen

    # Releases publish both architectures; x86_64 must never select ARM64.
    tag = "v0.1.12-nightly.20261123.5138"
    url_base = f"https://github.com/pingdotgg/t3code/releases/download/{tag}/"
    releases = [{
        "prerelease": True, "tag_name": tag,
        "assets": [
            {"name": "T3-Code-Nightly-arm64.AppImage",
             "browser_download_url": url_base + "T3-Code-Nightly-arm64.AppImage"},
            {"name": "T3-Code-Nightly-x86_64.AppImage",
             "browser_download_url": url_base + "T3-Code-Nightly-x86_64.AppImage"},
        ],
    }]
    assert asset.nightly_asset(releases, "x86_64") == (
        tag, url_base + "T3-Code-Nightly-x86_64.AppImage")
    assert asset.nightly_asset(releases, "aarch64") == (
        tag, url_base + "T3-Code-Nightly-arm64.AppImage")
    for unsupported in ("i686", "riscv64"):
        try:
            asset.nightly_asset(releases, unsupported)
            assert False, "unsupported CPU architecture was accepted"
        except ValueError:
            pass
    for machine, wrong in (("x86_64", "arm64"), ("aarch64", "x86_64")):
        try:
            asset.nightly_asset([{"prerelease": True, "tag_name": tag,
                                 "assets": [releases[0]["assets"][0 if wrong == "arm64" else 1]]}], machine)
            assert False, "wrong architecture was accepted"
        except ValueError:
            pass

    # Check ELF CPU target, not only the four-byte magic.
    def fake_elf(machine_id: int) -> bytes:
        data = bytearray(128 * 1024)
        data[:4] = b"\x7fELF"
        data[4:6] = b"\x02\x01"
        data[18:20] = machine_id.to_bytes(2, "little")
        return bytes(data)
    asset.validate_appimage(fake_elf(62), "x86_64")
    asset.validate_appimage(fake_elf(183), "aarch64")
    try:
        asset.validate_appimage(fake_elf(183), "x86_64")
        assert False, "ARM64 ELF accepted on x86_64"
    except ValueError:
        pass
    for bad in ([], {"message": "API rate limit exceeded"}):
        try:
            asset.nightly_asset(bad)
            assert False, "missing release metadata was accepted"
        except ValueError:
            pass

    old_download = asset.download
    asset.download = lambda url, *args, **kwargs: (
        json.dumps(releases).encode() if "api.github.com" in url
        else b"HTML error response"
    )
    try:
        asset.install_t3code(home)
        assert False, "HTML response installed as AppImage"
    except ValueError:
        pass
    assert b"old-build" in target.read_bytes()
    asset.download = old_download

    # Failure after the first live promotion must restore the entire MPV group.
    mpv = home / ".config/mpv"
    group = {"scripts/uosc/main.lua": b"new main", "scripts/uosc/two.lua": b"new two"}
    first = mpv / "scripts/uosc/main.lua"
    second = mpv / "scripts/uosc/two.lua"
    real_replace = asset.os.replace

    def fail_second(src, dst):
        if Path(dst) == second:
            raise OSError("injected second promotion failure")
        return real_replace(src, dst)

    for existing in (False, True):
        first.parent.mkdir(parents=True, exist_ok=True)
        first.unlink(missing_ok=True)
        second.unlink(missing_ok=True)
        if existing:
            first.write_bytes(b"previous main")
            second.write_bytes(b"previous two")
        asset.os.replace = fail_second
        try:
            try:
                asset.promote_zip_group(mpv, group, "uosc")
                assert False, "partial asset update erroneously succeeded"
            except OSError:
                pass
        finally:
            asset.os.replace = real_replace
        assert first.exists() == existing
        assert second.exists() == existing
        if existing:
            assert first.read_bytes() == b"previous main"
            assert second.read_bytes() == b"previous two"
    asset.promote_zip_group(mpv, group, "uosc")
    assert first.read_bytes() == b"new main"
    assert second.read_bytes() == b"new two"
    assert asset.status(home)["uosc"]["installed"]
    # The manifest is only healthy while EVERY member remains intact.
    second.unlink()
    assert not asset.status(home)["uosc"]["installed"]
    original_download = asset.download
    asset.download = lambda *args, **kwargs: zip_bytes({
        "scripts/uosc/main.lua": b"restored main",
        "scripts/uosc/two.lua": b"restored two",
    })
    asset.install_zip_group(home, "uosc")
    asset.download = original_download
    assert second.read_bytes() == b"restored two"
    assert asset.status(home)["uosc"]["installed"]

    anime = {
        "shaders/Anime4K_Clamp_Highlights.glsl": b"shader clamp" * 20,
        "shaders/Anime4K_Upscale.glsl": b"shader upscale" * 20,
    }
    asset.promote_zip_group(mpv, anime, "anime4k")
    assert asset.status(home)["anime4k"]["installed"]
    (mpv / "shaders/Anime4K_Upscale.glsl").unlink()
    assert not asset.status(home)["anime4k"]["installed"]

    cli = subprocess.run(
        [sys.executable, str(script), "--status", "--json"],
        env={**os.environ, "HOME": str(home)},
        capture_output=True, text=True, check=True,
    )
    assert json.loads(cli.stdout)["t3code"]["installed"]
    assert not (home / ".local/bin/mise").exists()
print("asset validation, corruption, rollback preservation and offline status: OK")
