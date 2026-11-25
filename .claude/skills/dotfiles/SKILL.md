---
name: dotfiles
description: How this CachyOS dotfiles repo is laid out and how to change it safely — common vs per-host files, per-file linking into ~, the dot command, adding a new config or ~/.local/bin tool, committing. Use for any change in this repository; the dotfiles-packages, dotfiles-desktop and dotfiles-testing skills cover those areas in depth.
---

# The dotfiles repo

One checkout (`dot cd`, normally `~/cachyos-dotfiles`) drives several machines
(`husain-pc`, `husain-parcel`). `dot` is `common/bin/.local/bin/dot`; the heavy
lifting is in `scripts/*.py`. README.md is the long-form reference.

## Layout

```
common/<pkg>/<path under ~>     shared by every host, e.g. common/kitty/.config/kitty/kitty.conf
hosts/<host>/home/<path under ~>  replaces exactly that one file on that host (or adds one)
hosts/<host>/packages.txt aur.txt optional.txt services.txt setup README.md
hosts/_template/                 starting point for `dot new-host`
packages/                        common.txt, aur.txt, aur-exceptions.json, optional/<group>.txt|.setup
seed/                            app-writable defaults copied once, never linked
system/setup                     limited PAM/DDC changes (opt-in)
scripts/  tests/  docs/          implementation, tests, status notes
.claude/skills  .agents/skills   these repo skills (Claude Code / Codex)
```

`<pkg>` is just a grouping name (stow-shaped). Each *file* is linked
individually into `~`; directories are created for real. `dot plan` shows every
target and which source owns it; two common packages may not own one path.

## Rules

- **Shared or host?** Put a file in `common/` only if it is right on every
  machine. Monitors, GPU env, device names, autostart apps, audio hardware →
  `hosts/<host>/home/...`. Never edit or commit another host's files as a side
  effect; when a change is for one host, touch only `hosts/<that-host>/`.
- **No hardcoded home paths** (`/home/<user>`): use `$HOME`, `~`, `{{env.HOME}}`
  (mise) or relative paths. `tests/test-repository-audit.py` enforces this.
- **Linked files are live.** Editing `common/...` changes the running desktop
  of this machine at once (and others after `dot pull`). Generated theme files
  are gitignored; don't commit them.
- **Never** commit secrets (OBS `service.json`, tokens, keyrings). `dot add`
  refuses known secret paths, but check contents yourself.
- State-changing commands — `dot install`, `dot link`, `dot save`, `dot pull
  --apply`, `dot optional <grp>`, `dot services --apply`, `dot host-setup
  --apply`, `dot greeter …` — act on the real machine. Run read-only previews
  (`dot status`, `dot diff`, `dot plan`, `dot doctor`, `dot link --dry-run`,
  `dot install --dry-run`, `dot services`) freely; ask before the others, and
  remember anything needing sudo must be run by the user.

## Common changes

- **Edit an existing config:** edit the repo source (the `~` file is a symlink
  to it). Check `dot plan | grep <path>` to find which source wins on this host.
- **Start managing a new config:** `dot add <file>` (preview) → `dot add --apply
  [--host] <file>` copies it in → `dot link` → `git add` the new path.
- **New tool in `~/.local/bin`:** add `common/bin/.local/bin/<tool>` (executable,
  `set -euo pipefail`, header comment that doubles as `--help`, like `vm` and
  `android-sdk-setup`), add it to the `bash -n` line in
  `.github/workflows/dotfiles-static.yml`, then `dot link`. If agents should use
  it, add a global skill (below).
- **Global agent skills** (installed for every agent on every host) live in
  `common/agents/.claude/skills/<name>/SKILL.md`; `common/agents/.codex/skills/<name>/SKILL.md`
  is a relative symlink to the same file. Repo-only skills go in
  `.claude/skills/` (`.agents/skills` links there).
- **App replaced a link with a plain file** (atomic save): `dot status` shows it;
  `dot link` absorbs app edits to linked files back into the repo first.

## Committing

Conventional, scoped subjects as in `git log` (`feat(vm): …`, `fix(hypr): …`),
a short body explaining why, and the Co-Authored-By trailer you were given.
Stage explicit paths, not `git add -A`: other files in the worktree are often
app edits through links (e.g. `mimeapps.list`) that the user hasn't reviewed.
Commit only when asked; `dot save` also pushes, so prefer plain `git commit`.
