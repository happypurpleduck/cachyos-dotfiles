#!/usr/bin/env python3
"""Read-only effective target planner for the CachyOS common/host Stow layout.

This is not an installer. It lists the final per-file ownership map *before*
any tool mutates a home directory. Host files win over common files at the
same target; unrelated app files outside the repo are never enumerated.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Target:
    path: str
    source: Path
    owner: str
    overridden_source: Path | None = None

    def as_dict(self, home: Path) -> dict[str, str | None]:
        return {
            "path": self.path,
            "target": str(home / self.path),
            "source": str(self.source),
            "owner": self.owner,
            "overridden_source": (
                str(self.overridden_source) if self.overridden_source else None
            ),
        }


def tracked_and_new_paths(repo: Path, host: str) -> list[Path]:
    # Include intentional new overrides before commit, but never list
    # gitignored downloaded/generated runtime state as managed config.
    result = subprocess.run(
        [
            "git", "-C", str(repo), "ls-files", "-z", "--cached",
            "--others", "--exclude-standard", "--", "common",
            f"hosts/{host}/home",
        ],
        check=True,
        capture_output=True,
    )
    paths: list[Path] = []
    for raw in result.stdout.split(b"\0"):
        if not raw:
            continue
        rel = Path(raw.decode("utf-8", "surrogateescape"))
        source = repo / rel
        if source.is_file() or source.is_symlink():
            paths.append(rel)
    return sorted(set(paths), key=lambda p: str(p))


def plan(repo: Path, host: str) -> list[Target]:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", host) or host in {
        ".", "..", "_template"
    }:
        raise ValueError(f"invalid host: {host!r}")
    if not (repo / "common").is_dir() or not (repo / "hosts").is_dir():
        raise ValueError(f"not a dotfiles checkout: {repo}")

    common: dict[str, Target] = {}
    local: dict[str, Target] = {}
    for rel in tracked_and_new_paths(repo, host):
        parts = rel.parts
        if rel.name == ".gitignore":
            continue
        if parts[0] == "common" and len(parts) >= 3:
            owner = f"common:{parts[1]}"
            target = Path(*parts[2:]).as_posix()
            if target in common:
                raise ValueError(
                    f"multiple common packages own {target}: "
                    f"{common[target].source} and {repo / rel}"
                )
            common[target] = Target(target, repo / rel, owner)
        elif (
            len(parts) >= 4
            and parts[0] == "hosts"
            and parts[1] == host
            and parts[2] == "home"
        ):
            target = Path(*parts[3:]).as_posix()
            local[target] = Target(target, repo / rel, f"host:{host}")

    effective = dict(common)
    for target, entry in local.items():
        effective[target] = Target(
            entry.path,
            entry.source,
            entry.owner,
            common[target].source if target in common else None,
        )

    # A managed file may not also be the parent of a different target.
    for path in effective:
        parent = Path(path).parent
        while str(parent) != ".":
            if parent.as_posix() in effective:
                raise ValueError(
                    f"managed file/parent conflict: {parent} and {path}"
                )
            parent = parent.parent

    # Stable ordering makes plan output reviewable and comparable between hosts.
    return [effective[k] for k in sorted(effective)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--host", required=True)
    parser.add_argument("--home", required=True, type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    try:
        entries = plan(args.repo.resolve(), args.host)
        home = args.home.expanduser().resolve()
        if args.json:
            print(
                json.dumps(
                    {
                        "host": args.host,
                        "home": str(home),
                        "entries": [t.as_dict(home) for t in entries],
                        "overrides": sum(
                            t.overridden_source is not None for t in entries
                        ),
                    },
                    indent=2,
                )
            )
        else:
            print(f"Effective targets for {args.host} ({len(entries)} files):")
            for entry in entries:
                tag = "host override" if entry.overridden_source else entry.owner
                rel = entry.source.relative_to(args.repo.resolve())
                print(f"  {entry.path} <- {rel} [{tag}]")
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        print(f"effective-targets: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
