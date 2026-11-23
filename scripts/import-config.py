#!/usr/bin/env python3
"""Safely copy app-owned files into shared or host-owned dotfiles sources.

Preview by default. Applying copies, never moves or deletes the original HOME
file; linking/committing is always a separate explicit operation.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import tempfile
from uuid import uuid4

BLOCKED_PATH = re.compile(
    r"(^|/)(\.ssh|\.gnupg|\.env(?:\..*)?|[^/]*(?:secret|credential|token|password|"
    r"keyring|id_rsa|id_ed25519|streamkey)[^/]*)(/|$)", re.IGNORECASE
)


def inside(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def no_symlink_parents(path: Path, base: Path) -> None:
    here = path.parent
    while here != base:
        if not inside(here, base):
            raise ValueError(f"path escapes selected root: {path}")
        if here.is_symlink():
            raise ValueError(f"parent is a symlink: {here}; migrate folded Stow links first")
        here = here.parent


def package_name(relative: Path) -> str:
    parts = relative.parts
    if len(parts) >= 3 and parts[0] == ".config":
        return parts[1]
    if len(parts) >= 4 and parts[:2] == (".local", "share"):
        return parts[2]
    if len(parts) >= 4 and parts[:2] == (".local", "bin"):
        return "bin"
    name = relative.name.lstrip(".")
    return re.sub(r"[^A-Za-z0-9_.-]", "-", name.split(".")[0].removesuffix("rc")) or "misc"


def inspect(repo: Path, home: Path, host: str, files: list[str],
            *, host_only=False, replace_source=False) -> list[dict]:
    from runpy import run_path
    plan = run_path(str(repo / "scripts/effective-targets.py"))["plan"](repo, host)
    managed = {entry.path: entry for entry in plan}
    if not (repo / "hosts" / host / "home").is_dir():
        raise ValueError(f"host profile does not exist: {host}")
    if not files:
        raise ValueError("specify one or more regular text files inside HOME")
    results = []
    seen: set[str] = set()
    for raw in files:
        raw_path = Path(raw).expanduser()
        src = (raw_path if raw_path.is_absolute() else Path.cwd() / raw_path).absolute()
        if not inside(src, home):
            raise ValueError(f"source outside HOME: {src}")
        no_symlink_parents(src, home)
        if src.is_symlink() or not src.is_file():
            raise ValueError(f"not a regular, app-owned file: {src}")
        relative = src.relative_to(home)
        rel = relative.as_posix()
        if rel in seen:
            raise ValueError(f"duplicate import source: {src}")
        seen.add(rel)
        if BLOCKED_PATH.search(rel):
            raise ValueError(f"potential credential/secret location is never imported: {rel}")
        if src.stat().st_size > 2 * 1024 * 1024:
            raise ValueError(f"file exceeds 2 MiB text-config limit: {rel}")
        data = src.read_bytes()
        if b"\0" in data:
            raise ValueError(f"binary file is not supported for automatic import: {rel}")
        try:
            data.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ValueError(f"non-UTF8 file requires manual review: {rel}") from exc
        if host_only:
            dst = repo / "hosts" / host / "home" / relative
            owner = f"host:{host}"
        else:
            package = package_name(relative)
            dst = repo / "common" / package / relative
            owner = f"common:{package}"
        no_symlink_parents(dst, repo)
        current = managed.get(rel)
        if current is not None and current.source != dst:
            if not host_only:
                raise ValueError(
                    f"common target already owned by {current.source}; "
                    "select --host for a host override or edit the existing common source"
                )
            if current.owner == f"host:{host}":
                raise ValueError(f"unexpected duplicate host target: {rel}")
        if dst.is_symlink() or (dst.exists() and not dst.is_file()):
            raise ValueError(f"unsafe repository destination: {dst}")
        exists = dst.is_file()
        old = dst.read_bytes() if exists else None
        different = old != data
        if exists and different and not replace_source:
            raise ValueError(
                f"source already exists with different content: {dst}; "
                "explicitly choose --replace-source after review"
            )
        results.append({
            "src": src, "dst": dst, "rel": rel, "owner": owner, "data": data,
            "mode": stat.S_IMODE(src.stat().st_mode),
            "exists": exists, "different": different,
            "sha256": hashlib.sha256(data).hexdigest(),
        })
    return results


def apply(repo: Path, home: Path, entries: list[dict]) -> None:
    changes = [item for item in entries if item["different"]]
    if not changes:
        print("All requested sources already match; no-op")
        return
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid4().hex[:12]
    backup_root = home / ".local/state/dotfiles-backup/imports" / stamp
    journal: list[tuple[Path, Path | None]] = []
    try:
        for item in changes:
            dest = item["dst"]
            if dest.is_symlink() or (dest.exists() and not dest.is_file()):
                raise ValueError(f"destination changed during import: {dest}")
            if dest.exists() != item["exists"]:
                raise ValueError(f"destination appeared/disappeared during import: {dest}")
            dest.parent.mkdir(parents=True, exist_ok=True)
            backup = None
            if item["exists"]:
                backup = backup_root / dest.relative_to(repo)
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(dest, backup)
            fd, staged = tempfile.mkstemp(prefix=".dot-import-", dir=dest.parent)
            try:
                with os.fdopen(fd, "wb") as out:
                    out.write(item["data"])
                    out.flush()
                    os.fsync(out.fileno())
                os.chmod(staged, item["mode"])
                os.replace(staged, dest)
            finally:
                if os.path.lexists(staged):
                    os.unlink(staged)
            journal.append((dest, backup))
    except (OSError, ValueError):
        for dest, backup in reversed(journal):
            if backup:
                os.replace(backup, dest)
            elif dest.is_file():
                dest.unlink()
        raise
    print(f"copied {len(changes)} config file(s) into the repo; originals left in HOME")
    if any(item["exists"] for item in changes):
        print(f"prior repo sources were backed up at {backup_root}")
    print("Next: review dot doctor, run dot link --backup-conflicts if needed,")
    print("      stage only reviewed repository sources with git add, then dot save.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--host", required=True)
    parser.add_argument("--host-only", action="store_true")
    parser.add_argument("--replace-source", action="store_true")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("files", nargs="*")
    args = parser.parse_args()
    try:
        repo = args.repo.resolve(strict=True)
        home = args.home.expanduser().resolve(strict=True)
        entries = inspect(repo, home, args.host, args.files,
                          host_only=args.host_only, replace_source=args.replace_source)
        for item in entries:
            status = "copy" if not item["exists"] else (
                "replace (backed up)" if item["different"] else "unchanged")
            print(f"{status}: {item['rel']} -> {item['dst'].relative_to(repo)} "
                  f"[{item['owner']}] sha256={item['sha256'][:12]}")
        if not args.apply:
            print("PREVIEW ONLY: use --apply to copy files; HOME is never moved/deleted")
            return 0
        apply(repo, home, entries)
        return 0
    except (OSError, ValueError) as exc:
        print(f"dot import: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
