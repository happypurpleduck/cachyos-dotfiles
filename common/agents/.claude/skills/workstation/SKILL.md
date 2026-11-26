---
name: workstation
description: What this Linux machine is and which tools it has (CachyOS + Hyprland desktop, Shelly packages, mise runtimes, ~/.local/bin tools like vm, dot and android-sdk-setup, T3 Code, Tailscale). Use before installing software, choosing a runtime or CLI, touching anything under ~/.config, or when unsure what is available on the host.
---

# This workstation

CachyOS (Arch-based, rolling) with a Hyprland desktop and a Quickshell shell
("mocha-shell", Catppuccin Mocha). Terminal is kitty, login shell zsh (oh-my-zsh +
powerlevel10k), editors neovim, micro and Zed. Hosts: `husain-pc` (desktop,
Ryzen + RTX 4070 Ti) and `husain-parcel`; `cat /etc/hostname` says which.

## Installing things

- **Dev runtimes and CLIs: mise**, not system packages. Global tools live in
  `~/.config/mise/config.toml` (node, bun, pnpm, rust, java temurin-17, gh,
  claude, codex, opencode). In a project prefer a project `mise.toml`, or
  `mise exec node@22 -- …` for one-offs.
- **System packages: Shelly** (`shelly install standard <pkg>`, `shelly list …`),
  never `pacman`/`yay` directly. Installing system packages changes the user's
  machine: ask first, and say which package and why. Anything meant to stay
  belongs in the dotfiles manifests (see below), not a one-off install.
- No sudo without asking. You can't answer password prompts; hand the exact
  command to the user (they can run it with `! <command>` in Claude Code).

## Tools on PATH (`~/.local/bin`)

| Tool | Use |
|---|---|
| `vm` | local KVM/libvirt VMs: create, ssh, snapshot, delete (see the `vm` skill) |
| `dot` | manages the dotfiles checkout; read-only: `dot status`, `dot doctor`, `dot plan`, `dot optional --list`, `dot help` |
| `android-sdk-setup` | Android SDK + emulator at `~/Android/Sdk` (`--status` is read-only) |
| `t3code-launch` | starts the T3 Code desktop app |
| `~/.t3/bin/t3` (not on PATH) | T3 Code CLI: start and read agent threads (see the `t3code` skill) |

Also present: Tailscale (`tailscale status`), Google Chrome, ripgrep, fd, eza, bat,
fzf, jq, lazygit, tmux. Docker is an optional group (`dot optional docker`), so check `command -v docker`
before relying on it; Podman is not installed. Prefer `vm` for isolation.

## Configuration is managed — don't edit it in place

Most of `~/.config`, `~/.zshrc`, `~/.local/bin/*` and these skills are
**symlinks into the dotfiles repo** at `~/cachyos-dotfiles` (`dot cd` prints the
path). Editing a linked file edits the repo for every machine.

- Before changing any config under `~`, check `readlink -f <file>`. If it
  points into the dotfiles repo, do the work **from inside that repo**, where its
  own skills (`dotfiles`, `dotfiles-packages`, `dotfiles-desktop`,
  `dotfiles-testing`) explain the layout, per-host rules and tests.
- Don't run state-changing `dot` commands (`install`, `link`, `save`, `pull
  --apply`, `optional <group>`, `services --apply`) from an unrelated task; they
  install packages, relink files or push commits. Suggest them to the user.
- Desktop theming is generated from the wallpaper (`mocha-theme`); files like
  `~/.config/kitty/mocha-theme.conf` are overwritten on every wallpaper change.
