#!/usr/bin/env python3
"""Initialize Mocha desktop theme from a TTY, before user services run.

No display server or network needed. A generated local solid wallpaper is used
when downloads have failed or this host has not selected a wallpaper yet.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import runpy
import struct
import sys
import zlib


def png_chunk(name: bytes, payload: bytes) -> bytes:
    return (struct.pack(">I", len(payload)) + name + payload
            + struct.pack(">I", zlib.crc32(name + payload) & 0xffffffff))


def fallback_image(state: Path) -> Path:
    output = state / "fallback.png"
    state.mkdir(parents=True, exist_ok=True)
    if output.is_file() and output.stat().st_size > 60:
        return output
    # 16x16 Catppuccin Mocha base (#1e1e2e); valid PNG without Pillow.
    pixel = bytes((0x1e, 0x1e, 0x2e))
    data = b"".join(b"\0" + pixel * 16 for _ in range(16))
    payload = (b"\x89PNG\r\n\x1a\n"
               + png_chunk(b"IHDR", struct.pack(">2I5B", 16, 16, 8, 2, 0, 0, 0))
               + png_chunk(b"IDAT", zlib.compress(data))
               + png_chunk(b"IEND", b""))
    temp = output.with_suffix(".tmp")
    temp.write_bytes(payload)
    temp.replace(output)
    return output


def first_login(home: Path, script: Path) -> dict:
    if not script.is_file():
        raise ValueError(f"Mocha theme script is unavailable: {script}")
    # The theme renderer must never alter /etc policy or trigger live
    # process signals during offline initialization.
    os.environ["MOCHA_OFFLINE"] = "1"
    module = runpy.run_path(str(script))
    state_file = home / ".local/state/mocha-shell/theme.json"
    wallpaper_dir = home / "Pictures/Wallpapers/catppuccin-mocha"
    st = module["load_state"]()
    st.setdefault("mode", "auto")
    selected = Path(os.path.expanduser(str(st.get("wallpaper", ""))))
    if not selected.is_file():
        choices = sorted(
            (p for p in wallpaper_dir.iterdir()
             if p.is_file() and p.suffix.lower() in module["IMAGE_EXT"]),
            key=lambda p: p.name,
        ) if wallpaper_dir.is_dir() else []
        selected = choices[0] if choices else fallback_image(state_file.parent)
        st["wallpaper"] = str(selected)
    if st.get("accent") not in module["ACCENTS"]:
        st["accent"] = module["DEFAULT_ACCENT"]
    if st.get("mode") == "auto":
        try:
            st["accent"] = module["detect_accent"](selected)
        except (ImportError, OSError):
            st["accent"] = module["DEFAULT_ACCENT"]
    module["save_state"](st)
    module["apply_all"](st, live=False)

    essential = [
        home / ".config/hypr/mocha-theme.lua",
        home / ".config/kitty/mocha-theme.conf",
        home / ".config/hokum/themes/mocha.kdl",
        home / ".config/zsh/p10k-mocha.zsh",
    ]
    missing = [str(p) for p in essential if not p.is_file() or p.stat().st_size == 0]
    if missing:
        raise ValueError("theme failed to generate required startup files: "
                         + ", ".join(missing))
    return {"wallpaper": str(selected), "accent": st["accent"],
            "generated": [str(p) for p in essential]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--theme-script", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        home = args.home.expanduser().resolve(strict=True)
        if home != Path.home().resolve():
            raise ValueError("HOME mismatch; run initialization as the target user")
        path = (args.theme_script or
                home / ".config/quickshell/scripts/mocha-theme")
        if args.check:
            paths = [
                home / ".config/kitty/mocha-theme.conf",
                home / ".config/hokum/themes/mocha.kdl",
                home / ".config/zsh/p10k-mocha.zsh",
                home / ".local/state/mocha-shell/theme.json",
            ]
            missing = [str(x) for x in paths if not x.is_file()]
            print(json.dumps({"ready": not missing, "missing": missing}))
            return 0 if not missing else 1
        result = first_login(home, path)
        print(json.dumps(result, indent=2))
        return 0
    except (OSError, ValueError) as exc:
        print(f"first-login: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
