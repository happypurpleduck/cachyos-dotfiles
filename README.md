# cachyos-dotfiles

My CachyOS + Hyprland desktop: the **Mocha shell** (Quickshell; Catppuccin Mocha
with the accent picked from the wallpaper), plus the configs and scripts around
it. Every machine I use syncs through this repo, and each one keeps its own
machine-specific config here too.

## Preflight: inspect before activating

```sh
dot doctor                 # inspect effective link targets and common dependencies
dot doctor --json          # machine-readable preflight results
dot doctor --strict        # nonzero when blockers or required packages are absent
dot link --dry-run         # read-only link preview (does not link)
dot install --dry-run      # read-only bootstrap preview (no sudo or pacman)
./install --dry-run        # the same preview on a new checkout
```

The doctor reports `missing` links, already correct links, safe-looking
managed target differences, foreign symlinks, ordinary files that would
collide, and **folded-parent** directory symlinks left by earlier GNU Stow
runs. A folded parent is deliberately treated as a blocker: automatically
replacing that directory link risks losing access to app-generated files.
The package inventory is read-only and uses the local pacman database when
present; no package/asset/service installation is implied. Display-manager
status is informational only. It does not touch /etc or the greeter.

### Applying file links (transactional)

Once `dot doctor` has been reviewed, `dot link` now uses the effective
per-file ownership map rather than stowing common and host directories in
sequence. Each host may replace exactly one common target without replacing
its sibling files. This retains the existing GNU Stow-shaped package layout
but uses explicit symlinks to avoid Stow's folder-folding/overlay ambiguity.

```sh
dot link                     # refuse unapproved home-file collisions
dot link --backup-conflicts  # explicitly back up colliding files/symlinks
dot unlink                   # unlink only targets recorded in this host's manifest
dot rollback TXID            # undo the latest applied link/unlink transaction
```

Each change has a unique ID under
`~/.local/state/dotfiles-backup/transactions/`, including moved originals
and a JSON journal. A link manifest is stored outside Git at
`~/.local/state/cachyos-dotfiles/links-<host>.json`. App-created files next
to managed links are untouched. Removed host overrides fall back to their
common source; changes in other hosts are never applied. Rollback refuses to
overwrite files replaced by an app since the transaction, or to rewind past
newer transactions.

**Migration caution:** legacy Stow *directory* symlinks are intentionally
blocked. These may contain generated files or application data. A separate
audited migration is needed before `dot link` can run on those installations;
do not delete or flatten these links by hand. `dot unlink` without a new
link-state manifest likewise refuses to guess ownership.

System-level changes, startup/service activation, greeter migration and a
full interrupted-install recovery path remain work in #6; the per-file
transaction only covers managed links. Successful link application does not
automatically reload Hyprland or restart Quickshell.


**Important:** this is a preflight-only increment. The existing `dot link`
and non-preview `dot install` retain their old behavior until the
transactional/linker follow-ups under #2 and #6 have been reviewed.
Do not treat a successful preview as authorization to replace a
working display manager or migrate folded links.

## New machine

Install CachyOS (any desktop, or none), log in, then:

```sh
sudo pacman -S --needed git openssh github-cli
gh auth login                       # SSH, so the private repo can be cloned
git clone git@github.com:happypurpleduck/cachyos-dotfiles.git ~/cachyos-dotfiles
~/cachyos-dotfiles/install
```

The checkout can also live in another directory. After installation, `dot`
resolves its actual checkout through its `~/.local/bin/dot` symlink instead
of assuming `~/cachyos-dotfiles`. For deliberate overrides, set
`DOTFILES=/path/to/checkout`.

The default host is the system hostname (`/etc/hostname`). To intentionally
use a different profile, run commands with `DOT_HOST=profile-name`, for
example `DOT_HOST=laptop dot status`. Keep **one distinct host directory per
physical machine**; do not select another machine's hardware profile merely
because its settings look similar. `hosts/_template` is never selectable.

`install` asks for sudo a few times and:

1. offers to create `hosts/<hostname>/` from `hosts/_template` if this machine is new
2. asks about optional apps (`packages/optional/`, e.g. qBittorrent) — answers are saved per machine —
   then installs `packages/common.txt`, the host's `packages.txt` and the chosen optional groups
   (AUR lists via paru, kept minimal)
3. downloads assets: wallpapers, cursors, mpv scripts/shaders, T3 Code, Zed, mise tools
4. links the configs with GNU Stow (anything in the way is moved to `~/.local/state/dotfiles-backup/`)
5. sets up system files: keyring unlock at login, DDC/CI, Chrome theme policy, the Mocha greeter
6. enables user services, runs the host's `setup` if it has one

Then log out and back in from the greeter.

## Day to day

```sh
dot status          # tracked changes and app-replaced managed links
dot diff            # review tracked changes for common/ + this host
dot save "message"  # commit tracked shared/current-host files, rebase and push
dot pull            # fetch/rebase without stashing or creating new links
dot add <file>      # add a file to the repo; --host for this machine only
dot packages        # snapshot this machine's extra packages
dot optional        # optional apps: --list, or `dot optional qbittorrent` to install one
```

Edits made in currently linked files go straight into the repo. By default, `dot
save` stages **only edits/deletions of already tracked files** under `common/`
and `hosts/<this-host>/`. It does not commit unrelated hosts, new untracked
files or app-replaced files. Inspect `dot status` first. For intentional new
files, stage the exact paths with `git -C "$(dot cd)" add -- PATH` and then
run `dot save`. For deliberately staged maintenance or another host's files,
use `dot save --allow-staged "message"`; do not use this for secrets or runtime
state.

If an application replaces a symlink with a regular file, `dot save` refuses
to guess which repository copy should receive it. Inspect and back up that
file, copy it to the intended source under `common/` or
`hosts/<this-host>/home/`, then run `dot link` when ready. Rebase conflicts
stop the sync without force pushing; follow Git's `rebase --continue` or
`rebase --abort` guidance. `dot pull` does not automatically apply new
links. **Existing symlinks still point into Git, so updating tracked files can
change the active config immediately**; preflight/activation protections are
being built separately in #6.

## Layout

```
common/<app>/       stow packages linked on every machine (paths mirror $HOME)
hosts/<hostname>/   this machine only:
  home/             linked on top of common (file by file)
  packages.txt      extra repo packages        aur.txt  extra AUR packages
  optional.txt      optional groups chosen here ("!group" = declined)
  setup             optional script run by `dot install`
  README.md         notes about the hardware
hosts/_template/    starting point for a new machine (`dot new-host`)
packages/           common.txt (repo) and aur.txt (AUR) for every machine;
  optional/<group>.txt   opt-in apps ("# description" line, then packages; aur:<name> for AUR)
seed/               configs apps keep rewriting (btop, waypaper, zed): copied once, not linked
system/setup        files outside $HOME (run with sudo; idempotent)
scripts/            fetch-assets (downloads that don't belong in git)
install             bootstrap for a fresh machine
```

### Host overrides: precedence preview

The intended target policy is **per-file**, not "host copies the entire app":
`common/<app>/<home-path>` supplies a default, while
`hosts/<hostname>/home/<home-path>` replaces exactly that target *on that
host*. A host can also add files that do not exist in common. For example, one
host can replace `~/.zshrc`, another can replace a Quickshell QML component,
and both can keep shared defaults for their remaining files.

Run `dot plan` or `dot plan --json` to inspect the deterministic effective
targets and their owners **without linking or changing anything**. It rejects
duplicate common ownership and file-versus-parent conflicts and excludes
ignored runtime/generated files. The effective target planner is the source of truth for `dot link`,
`dot unlink`, and ownership checks. Actual application is blocked where
legacy Stow directory links or unapproved file collisions exist; inspect
`dot doctor` and the transaction notes above before first use.

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
