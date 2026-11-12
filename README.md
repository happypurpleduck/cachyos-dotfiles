# cachyos-dotfiles

My CachyOS + Hyprland desktop: the **Mocha shell** (Quickshell; Catppuccin Mocha
with the accent picked from the wallpaper), plus the configs and scripts around
it. Every machine I use syncs through this repo, and each one keeps its own
machine-specific config here too.

## New machine

Install CachyOS (any desktop, or none), log in, then:

```sh
sudo pacman -S --needed git openssh github-cli
gh auth login                       # SSH, so the private repo can be cloned
git clone git@github.com:happypurpleduck/cachyos-dotfiles.git ~/cachyos-dotfiles
~/cachyos-dotfiles/install
```

`install` asks for sudo a few times and:

1. offers to create `hosts/<hostname>/` from `hosts/_template` if this machine is new
2. installs `packages/common.txt` + the host's `packages.txt` (AUR lists via paru, kept minimal)
3. downloads assets: wallpapers, cursors, mpv scripts/shaders, T3 Code, Zed, mise tools
4. links the configs with GNU Stow (anything in the way is moved to `~/.local/state/dotfiles-backup/`)
5. sets up system files: keyring unlock at login, DDC/CI, Chrome theme policy, the Mocha greeter
6. enables user services, runs the host's `setup` if it has one

Then log out and back in from the greeter.

## Day to day

```sh
dot status          # what changed, and any links an app replaced with a plain file
dot save "message"  # commit + push (takes back app-replaced files first)
dot pull            # get the other machines' changes and relink
dot add <file>      # start tracking a file (shared); --host for this machine only
dot packages        # snapshot this machine's extra packages
```

Edits made in `~/.config/...` go straight into the repo, since those files are links.

## Layout

```
common/<app>/       stow packages linked on every machine (paths mirror $HOME)
hosts/<hostname>/   this machine only:
  home/             linked on top of common (file by file)
  packages.txt      extra repo packages        aur.txt  extra AUR packages
  setup             optional script run by `dot install`
  README.md         notes about the hardware
hosts/_template/    starting point for a new machine (`dot new-host`)
packages/           common.txt (repo) and aur.txt (AUR) for every machine
seed/               configs apps keep rewriting (btop, waypaper, zed): copied once, not linked
system/setup        files outside $HOME (run with sudo; idempotent)
scripts/            fetch-assets (downloads that don't belong in git)
install             bootstrap for a fresh machine
```

### What's per machine

The shared config never names hardware. Anything that does goes in the host directory:

- **Hyprland:** `common/hypr/.../hyprland.lua` ends by loading `~/.config/hypr/host.lua`:
  monitors, workspace-to-monitor rules (e.g. husain-pc keeps workspace 10 on the ASUS
  DP-2 monitor), GPU env vars, per-device input, and an `autostart` function for that
  machine's apps. With no host file, monitors use their preferred mode, placed automatically.
- **Shell:** `~/.config/mocha-shell/host.json`:
  - `audio.labels`: friendly names for this machine's audio devices
  - `audio.autoeq`: headphone EQ file and device. Without it, the AutoEq toggle is hidden
  - `audio.micDenoise.source`: which mic RNNoise cleans. Without it, the default mic is used
- **PipeWire:** the AutoEq filter (`mocha-autoeq.conf`) is per machine; mic noise suppression is shared.
- **OBS:** profile + scenes per machine. Stream keys are never committed.

### Generated files

`mocha-theme` rewrites colour files whenever the wallpaper changes (Hyprland borders,
kitty, GTK, Qt, Hokum, MangoHud, fuzzel, nvim accent, uosc, …). They're either outside the
repo or in `.gitignore`, so changing the wallpaper never shows up as a change in git.
