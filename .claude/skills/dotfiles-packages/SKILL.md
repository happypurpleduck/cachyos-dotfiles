---
name: dotfiles-packages
description: Package and service management in this dotfiles repo — common/host package lists, the AUR exception policy, optional groups (dot optional) with setup hooks, the allowlisted system services (dot services), and self-managed apps (mise, Zed, T3 Code assets). Use when adding, removing or moving a package, creating an optional group, or enabling a system service.
---

# Packages, optional groups and services

All installs go through **Shelly** (`shelly install standard|aur … --needed
--no-confirm`); the repo never calls pacman. `scripts/package-audit.py` builds
the plan and refuses anything outside the rules below.

## Where a package goes

| File | For |
|---|---|
| `packages/common.txt` | repo packages every host needs (grouped with `#` comments) |
| `hosts/<host>/packages.txt` | repo packages only that host needs |
| `packages/aur.txt`, `hosts/<host>/aur.txt` | AUR packages — each must have an entry in `packages/aur-exceptions.json` (scope, reason, source, review) |
| `packages/optional/<group>.txt` | opt-in apps, chosen per host with `dot optional` |

- One package name per line; `#` comments. Check the name exists first:
  `pacman -Si <pkg>` (read-only) or `shelly search`.
- AUR is a last resort: prefer the official repos (CachyOS repos included),
  then an upstream installer/AppImage. Adding an AUR package means adding its
  exception record with a real justification.
- **mise and Zed are self-managed** (`scripts/upstream-apps.py`, `dot apps`)
  and must never appear in any package list — the repository audit fails if they
  do. Dev runtimes/CLIs (node, bun, claude, codex, …) go in
  `common/mise/.config/mise/config.toml`, not package lists.
- Downloaded assets (wallpapers, cursors, mpv scripts/shaders, the T3 Code
  AppImage) are `scripts/asset-manager.py` / `scripts/fetch-assets`, not packages.
- `dot packages` lists what's installed but undeclared; it never adopts anything.

## Optional groups

`packages/optional/<group>.txt`: line 1 is `# <Title> — <description>` (shown by
`dot optional --list`), then packages (`aur:<name>` for AUR). Each host records
its answers in `hosts/<host>/optional.txt` (`group` = chosen, `!group` =
declined); `dot install` installs chosen groups but never asks about new ones.

If a group needs one-time host setup that packages can't do (user groups,
services, firewall, keys), add an executable `packages/optional/<group>.setup`.
`dot optional <group>` runs it after installing, with `DOT` and `HOST` set. It
must be idempotent and may use sudo (the user is at the terminal). Keep the real
logic in a tool the user can rerun — `virtualization.setup` just runs `vm setup`.

## System services

`hosts/<host>/services.txt` selects services from the allowlist `ALLOWED` in
`scripts/host-services.py` (name → package, unit): currently bluetooth,
tailscale and libvirt. `dot services` is a read-only report; `dot services
--apply` runs `systemctl enable --now` via polkit. To support a new service, add
it to `ALLOWED`, list it commented-out in `hosts/_template/services.txt`, update
the README's services section and run `tests/test-host-services.py`.

## Host-specific scripts

`hosts/<host>/setup` (idempotent bash) is for machine-only system tweaks — ufw
rules, static IPs. It runs only via `dot host-setup --apply`, never during
`dot install`.
