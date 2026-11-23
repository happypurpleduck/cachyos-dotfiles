#!/usr/bin/env python3
"""Per-file host-aware linker with collision protection and reversible journal.

The repository retains GNU Stow's package layout. The effective per-file plan
replaces the unsafe 'stow common; stow host' overlay procedure. Only selected
links are changed; unrelated app files and directories are never removed.
Old *folded directory* links are a migration blocker, not silently flattened.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import sys
import tempfile
from uuid import uuid4


def load_plan(repo: Path, host: str):
    return runpy.run_path(str(repo / "scripts/effective-targets.py"))["plan"](
        repo, host
    )


def load_doctor(repo: Path):
    return runpy.run_path(str(repo / "scripts/dot-doctor.py"))["check_target"]


def lexists(path: Path) -> bool:
    return os.path.lexists(path)


def within(path: Path, base: Path) -> bool:
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


def safe_managed_source(source: Path, repo: Path, host: str) -> bool:
    return (within(source, repo / "common")
            or within(source, repo / "hosts" / host / "home"))


def state_path(home: Path, host: str) -> Path:
    return home / ".local/state/cachyos-dotfiles" / f"links-{host}.json"


def tx_root(home: Path) -> Path:
    return home / ".local/state/dotfiles-backup/transactions"


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".new-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(data, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.lexists(tmp):
            os.unlink(tmp)


def read_json(path: Path, default: dict | None = None) -> dict:
    if not path.is_file():
        return {} if default is None else default
    return json.loads(path.read_text(encoding="utf-8"))


def current_symlink_points_to(target: Path, source: Path) -> bool:
    return target.is_symlink() and target.resolve(strict=False) == source.resolve(
        strict=False
    )


def inspect(repo: Path, home: Path, host: str, backup_conflicts: bool, unlink: bool):
    if not (repo / "hosts" / host / "home").is_dir():
        raise ValueError(f"no hosts/{host}/home; run dot new-host first")
    targets = [] if unlink else load_plan(repo, host)
    desired = {item.path: str(item.source) for item in targets}
    state = read_json(state_path(home, host), {"entries": {}})
    old = state.get("entries", {})
    if not isinstance(old, dict):
        raise ValueError("invalid old manifest entries")
    if unlink and not state_path(home, host).is_file():
        raise ValueError("no link state exists; legacy GNU Stow directories require migration")
    for path, source in old.items():
        parsed = Path(path)
        if (not isinstance(path, str) or not isinstance(source, str)
                or parsed.is_absolute() or ".." in parsed.parts or "." in parsed.parts):
            raise ValueError("invalid path or source in previous link manifest")
    check_target = load_doctor(repo)
    actions: list[dict] = []
    blockers: list[str] = []
    for entry in targets:
        info = check_target(home, entry, repo)
        status = info["status"]
        if status == "ok":
            continue
        dest = home / entry.path
        if status == "managed-different":
            actual = dest.resolve(strict=False)
            if not safe_managed_source(actual, repo, host):
                blockers.append(f"{entry.path}: points into another host's profile")
                continue
        elif status in ("collision-file", "foreign-symlink"):
            if not backup_conflicts:
                blockers.append(
                    f"{entry.path}: {status}; preview, then use --backup-conflicts"
                )
                continue
        elif status != "missing":
            blockers.append(
                f"{entry.path}: {status}: {info['detail']} "
                "(directory symlinks require an explicit migration)"
            )
            continue
        actions.append({
            "path": entry.path,
            "source": str(entry.source),
            "operation": "link",
            "before_exists": lexists(dest),
        })

    # Retire links that were owned by the previous transaction but are no
    # longer part of the effective plan. Do not touch app-replaced files.
    for path, old_source in sorted(old.items()):
        if path in desired:
            continue
        dest = home / path
        if not lexists(dest):
            continue
        if not current_symlink_points_to(dest, Path(old_source)):
            blockers.append(f"{path}: retired target was changed by an app/user")
            continue
        # Refuse old directory-folding links: those own a whole subtree.
        if dest.is_dir():
            blockers.append(f"{path}: retired directory symlink needs migration")
            continue
        actions.append({
            "path": path, "source": None,
            "operation": "unlink", "before_exists": True,
        })
    return desired, old, actions, blockers


def verify_no_parent_symlinks(home: Path, target: Path) -> None:
    parent = target.parent
    while parent != home:
        if parent.is_symlink():
            raise ValueError(f"parent symlink disallowed: {parent}")
        if parent.exists() and not parent.is_dir():
            raise ValueError(f"parent not a directory: {parent}")
        if not within(parent, home):
            raise ValueError(f"outside home: {parent}")
        parent = parent.parent


def make_parents(home: Path, target: Path) -> None:
    verify_no_parent_symlinks(home, target)
    target.parent.mkdir(parents=True, exist_ok=True)


def verify_after(target: Path, source: str | None) -> bool:
    if source is None:
        return not lexists(target)
    return current_symlink_points_to(target, Path(source))


def rollback(repo: Path, home: Path, host: str, txid: str, *, internal=False) -> None:
    if not re.fullmatch(r"\d{8}T\d{6}Z-[a-f0-9]{12}", txid):
        raise ValueError("invalid transaction id")
    txdir = tx_root(home) / txid
    journal_path = txdir / "journal.json"
    journal = read_json(journal_path)
    if journal.get("kind") == "folded-migration":
        runpy.run_path(str(repo / "scripts/migrate-folded.py"))["rollback_migration"](
            repo, home, host, txid
        )
        return
    if not journal or journal.get("host") != host or journal.get("home") != str(home):
        raise ValueError(f"no applicable transaction: {txid}")
    if journal.get("status") == "rolled_back":
        print(f"already rolled back: {txid}")
        return
    statefile = state_path(home, host)
    verify_no_parent_symlinks(home, statefile)
    if statefile.is_symlink():
        raise ValueError("refusing symlinked link-state manifest")
    if not internal:
        state = read_json(statefile)
        if state.get("last_transaction") != txid:
            raise ValueError("newer/unrelated link state exists; refusing rollback")

    operations = journal["actions"]
    # Pre-verify all user-facing changes before touching anything. If a user
    # or app replaced a new link, rollback refuses instead of discarding it.
    for action in operations:
        target = home / action["path"]
        backup = txdir / "saved" / action["path"]
        if not lexists(backup) and action["before_exists"]:
            continue  # operation never reached the backup step
        if lexists(target) and not verify_after(target, action["source"]):
            raise ValueError(f"target edited since apply, refusing rollback: {target}")

    for action in reversed(operations):
        target = home / action["path"]
        backup = txdir / "saved" / action["path"]
        if lexists(backup):
            if lexists(target):
                target.unlink()
            make_parents(home, target)
            os.replace(backup, target)
        elif not action["before_exists"] and lexists(target):
            target.unlink()
        # Never delete a directory containing untracked files.
        parent = target.parent
        while parent != home and parent != statefile.parent:
            try:
                parent.rmdir()
            except OSError:
                break
            parent = parent.parent

    previous = txdir / "previous-state.json"
    if previous.is_file():
        write_json(statefile, read_json(previous))
    elif statefile.is_file() and (
        internal or read_json(statefile).get("last_transaction") == txid
    ):
        statefile.unlink()
    journal["status"] = "rolled_back"
    write_json(journal_path, journal)
    print(f"restored transaction: {txid}")


def apply(repo: Path, home: Path, host: str, *, backup_conflicts=False,
          unlink=False, dry_run=False) -> int:
    desired, old, actions, blockers = inspect(
        repo, home, host, backup_conflicts, unlink
    )
    print(f"{'Unlink' if unlink else 'Link'} plan for host {host}: "
          f"{len(actions)} changes, {len(blockers)} blockers")
    for action in actions:
        print(f"  {action['operation']}: {action['path']}")
    for blocker in blockers:
        print(f"  BLOCKED: {blocker}", file=sys.stderr)
    if blockers:
        return 2
    if dry_run:
        print("Dry run: no files changed")
        return 0

    prior = state_path(home, host)
    verify_no_parent_symlinks(home, prior)
    verify_no_parent_symlinks(home, tx_root(home) / "new-transaction")
    if prior.is_symlink():
        raise ValueError("refusing symlinked link-state manifest")
    txid = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid4().hex[:12]
    directory = tx_root(home) / txid
    directory.mkdir(parents=True, exist_ok=False)
    journal_path = directory / "journal.json"
    if prior.is_file():
        shutil.copy2(prior, directory / "previous-state.json")
    journal = {
        "version": 1, "host": host, "home": str(home), "repo": str(repo),
        "status": "started", "actions": actions,
    }
    write_json(journal_path, journal)
    try:
        for action in actions:
            target = home / action["path"]
            make_parents(home, target)
            if action["before_exists"]:
                backup = directory / "saved" / action["path"]
                backup.parent.mkdir(parents=True, exist_ok=True)
                os.replace(target, backup)
            if action["source"] is not None:
                source = Path(action["source"])
                if not source.exists() and not source.is_symlink():
                    raise ValueError(f"source disappeared before apply: {source}")
                os.symlink(os.path.relpath(source, target.parent), target)
        write_json(prior, {
            "version": 1, "repo": str(repo), "host": host,
            "last_transaction": txid, "entries": desired,
        })
        journal["status"] = "applied"
        write_json(journal_path, journal)
    except (OSError, ValueError) as exc:
        print(f"link failed: {exc}; attempting rollback", file=sys.stderr)
        try:
            rollback(repo, home, host, txid, internal=True)
        except (OSError, ValueError) as failure:
            print(
                f"automatic rollback failed: {failure}; saved data in {directory}",
                file=sys.stderr,
            )
        return 1
    print(f"applied; rollback with: dot rollback {txid}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--host", required=True)
    parser.add_argument("--backup-conflicts", action="store_true")
    parser.add_argument("--unlink", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--rollback", metavar="TXID")
    args = parser.parse_args()
    try:
        repo = args.repo.resolve(strict=True)
        home = args.home.expanduser().resolve(strict=True)
        # Guard every operation with the same host identity checks as planner.
        load_plan(repo, args.host)
        if args.rollback:
            rollback(repo, home, args.host, args.rollback)
            return 0
        return apply(
            repo, home, args.host, backup_conflicts=args.backup_conflicts,
            unlink=args.unlink, dry_run=args.dry_run,
        )
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f"dot links: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
