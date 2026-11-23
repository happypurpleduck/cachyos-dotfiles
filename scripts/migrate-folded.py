#!/usr/bin/env python3
"""Explicit, reversible migration of legacy GNU Stow folded directory links.

Converts a symlinked application DIRECTORY into a real directory containing
per-file links. It preserves existing generated and ignored files from the
linked source alongside planned host overrides. Not part of regular dot link.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import sys
from uuid import uuid4


def helpers(repo: Path) -> dict:
    return runpy.run_path(str(repo / "scripts/dot-links.py"))


def source_plan(repo: Path, host: str):
    return runpy.run_path(str(repo / "scripts/effective-targets.py"))["plan"](
        repo, host
    )


def within(path: Path, base: Path) -> bool:
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


def fingerprint(path: Path) -> str | None:
    if not path.exists():
        return None
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"invalid link-state manifest: {path}")
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(home: Path, path: Path) -> str:
    if not within(path, home):
        raise ValueError(f"path outside home: {path}")
    return path.relative_to(home).as_posix()


def directory_contents(source: Path, target: Path, home: Path) -> dict[str, str]:
    """Map all files visible through an old folded symlink, including ignored."""
    result: dict[str, str] = {}
    for root, dirs, files in os.walk(source, followlinks=False):
        current = Path(root)
        for dirname in list(dirs):
            child = current / dirname
            if child.is_symlink():
                files.append(dirname)  # keep symlinked directories as leaf links
                dirs.remove(dirname)
        for filename in files:
            child = current / filename
            result[relative(home, target / child.relative_to(source))] = str(child)
    return result


def discover(repo: Path, home: Path, host: str) -> list[dict]:
    entries = source_plan(repo, host)
    if not (repo / "hosts" / host / "home").is_dir():
        raise ValueError(f"no hosts/{host}/home")
    candidates: dict[Path, Path] = {}
    for entry in entries:
        target = home / entry.path
        ancestor = target.parent
        while ancestor != home:
            if ancestor.is_symlink():
                destination = ancestor.resolve(strict=False)
                if not ancestor.is_dir():
                    raise ValueError(f"broken folded directory link: {ancestor}")
                if not (within(destination, repo / "common") or
                        within(destination, repo / "hosts" / host / "home")):
                    raise ValueError(
                        f"folder symlink points outside the selected host: {ancestor}"
                    )
                candidates[ancestor] = destination
                break
            if ancestor.exists() and not ancestor.is_dir():
                raise ValueError(f"non-directory ancestor: {ancestor}")
            ancestor = ancestor.parent

    roots = sorted(candidates, key=lambda p: (len(p.parts), str(p)))
    selected: list[dict] = []
    for root in roots:
        if any(within(root, Path(item["path"])) for item in selected):
            continue
        source = candidates[root]
        raw_link = os.readlink(root)
        files = directory_contents(source, root, home)
        for entry in entries:
            dest = home / entry.path
            if within(dest, root):
                # Effective host file must beat the common source file.
                files[relative(home, dest)] = str(entry.source)
        # A source directory symlink cannot enclose another planned target.
        for file in sorted(files):
            current = Path(file).parent
            while str(current) != ".":
                if current.as_posix() in files:
                    raise ValueError(
                        f"nested file/parent collision during migration: {current}"
                    )
                current = current.parent
        selected.append({
            "path": relative(home, root),
            "source": str(source),
            "raw_link": raw_link,
            "files": [{"path": key, "source": value}
                      for key, value in sorted(files.items())],
        })
    return selected


def tx_dir(home: Path, txid: str) -> Path:
    return home / ".local/state/dotfiles-backup/transactions" / txid


def validate_transaction_id(txid: str) -> None:
    if not re.fullmatch(r"\d{8}T\d{6}Z-[a-f0-9]{12}", txid):
        raise ValueError("invalid migration transaction id")


def verify_root(home: Path, item: dict) -> bool:
    root = home / item["path"]
    if root.is_symlink() and os.readlink(root) == item["raw_link"]:
        return False  # not migrated yet
    if not os.path.lexists(root):
        return True  # interrupted between unlinking old link and mkdir
    if not root.is_dir() or root.is_symlink():
        raise ValueError(f"modified migrated directory: {root}")
    expected = {x["path"]: Path(x["source"]) for x in item["files"]}
    seen: set[str] = set()
    for parent, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            child = Path(parent) / name
            rel = relative(home, child)
            if child.is_dir() and not child.is_symlink():
                continue
            seen.add(rel)
            if rel not in expected:
                raise ValueError(f"new user file since migration; refusing: {child}")
            if (not child.is_symlink() or
                    child.resolve(strict=False) != expected[rel].resolve(strict=False)):
                raise ValueError(f"file replaced since migration; refusing: {child}")
    return True


def rollback_migration(repo: Path, home: Path, host: str, txid: str) -> None:
    validate_transaction_id(txid)
    helpers_map = helpers(repo)
    write_json = helpers_map["write_json"]
    journal_file = tx_dir(home, txid) / "journal.json"
    if not journal_file.is_file():
        raise ValueError(f"no migration transaction: {txid}")
    journal = json.loads(journal_file.read_text(encoding="utf-8"))
    if (journal.get("kind") != "folded-migration" or
            journal.get("home") != str(home) or journal.get("host") != host or
            journal.get("repo") != str(repo)):
        raise ValueError("migration journal belongs to another checkout/host")
    if journal.get("status") == "rolled_back":
        print(f"already rolled back: {txid}")
        return
    state = home / ".local/state/cachyos-dotfiles" / f"links-{host}.json"
    if fingerprint(state) != journal["state_fingerprint"]:
        raise ValueError("link state changed since migration; undo later link transactions first")

    # All-or-nothing verification before removing any links.
    migrated = [(item, verify_root(home, item)) for item in journal["roots"]]
    for item, applied in reversed(migrated):
        if not applied:
            continue
        root = home / item["path"]
        if not os.path.lexists(root):
            os.symlink(item["raw_link"], root)
            continue
        for entry in reversed(item["files"]):
            file = home / entry["path"]
            if file.is_symlink():
                file.unlink()
        # rmdir refuses unrelated/newly written contents.
        for base, dirs, files in os.walk(root, topdown=False, followlinks=False):
            directory = Path(base)
            if directory != root:
                directory.rmdir()
        root.rmdir()
        os.symlink(item["raw_link"], root)
    journal["status"] = "rolled_back"
    write_json(journal_file, journal)
    print(f"restored legacy folded symlinks: {txid}")


def migrate(repo: Path, home: Path, host: str, apply: bool) -> int:
    objects = discover(repo, home, host)
    print(f"legacy Stow directory symlinks for {host}: {len(objects)}")
    for item in objects:
        print(f"  {item['path']} -> {item['source']} "
              f"({len(item['files'])} file links incl. generated assets)")
    if not objects:
        return 0
    if not apply:
        print("Read-only preview; apply explicitly with dot migrate-folded --apply")
        return 0

    toolkit = helpers(repo)
    write_json = toolkit["write_json"]
    verify = toolkit["verify_no_parent_symlinks"]
    txroot = toolkit["tx_root"](home)
    state = toolkit["state_path"](home, host)
    verify(home, txroot / "candidate")
    verify(home, state)
    txid = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid4().hex[:12]
    directory = txroot / txid
    directory.mkdir(parents=True, exist_ok=False)
    journal_file = directory / "journal.json"
    journal = {
        "kind": "folded-migration", "version": 1,
        "repo": str(repo), "host": host, "home": str(home),
        "state_fingerprint": fingerprint(state),
        "roots": objects, "status": "started",
    }
    write_json(journal_file, journal)
    try:
        for item in objects:
            root = home / item["path"]
            if not root.is_symlink() or os.readlink(root) != item["raw_link"]:
                raise ValueError(f"folder changed while planning: {root}")
            root.unlink()
            root.mkdir()
            for entry in item["files"]:
                dest = home / entry["path"]
                dest.parent.mkdir(parents=True, exist_ok=True)
                if os.path.lexists(dest):
                    raise ValueError(f"unexpected file during migration: {dest}")
                src = Path(entry["source"])
                os.symlink(os.path.relpath(src, dest.parent), dest)
        journal["status"] = "applied"
        write_json(journal_file, journal)
    except (OSError, ValueError) as exc:
        print(f"migration interrupted: {exc}; attempting rollback", file=sys.stderr)
        try:
            rollback_migration(repo, home, host, txid)
        except (OSError, ValueError) as rb_err:
            print(f"rollback needs attention: {rb_err}; journal: {directory}",
                  file=sys.stderr)
        return 1
    print(f"migrated; check dot doctor, then dot link. Roll back with: dot rollback {txid}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--host", required=True)
    parser.add_argument("--home", type=Path, required=True)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--apply", action="store_true")
    group.add_argument("--rollback", metavar="TXID")
    args = parser.parse_args()
    try:
        repo = args.repo.resolve(strict=True)
        home = args.home.expanduser().resolve(strict=True)
        if args.rollback:
            rollback_migration(repo, home, args.host, args.rollback)
            return 0
        return migrate(repo, home, args.host, args.apply)
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f"migrate-folded: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
