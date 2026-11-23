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

**Migrating an existing Stow installation:** `dot link` deliberately
blocks legacy folded *directory* symlinks. Use an explicit, separate migration
for those directories:

```sh
dot migrate-folded             # preview exactly which directories and files
dot migrate-folded --apply     # explicitly convert legacy directory symlinks
dot doctor                     # verify each new per-file link
dot link                       # adopt the effective common/host links
```

The migration turns each selected directory link into a real directory and
individual links to source files, including **ignored/generated files and
originally empty directories**. It applies host overrides at the file level,
without writing to the source repository or overwriting unrelated app state.
Each migration has its own journal; to roll it back, first roll back any
subsequent `dot link` transaction(s), then run `dot rollback <migration-id>`.
Rollback refuses to delete files or directories created by an application
after migration. Never manually remove folded directory symlinks.

`dot unlink` without a new link-state manifest still refuses to guess
ownership; it does not automatically reverse a legacy Stow installation.

System-level changes, startup/service activation, greeter migration and a
full interrupted-install recovery path remain work in #6; the per-file
transaction only covers managed links. Successful link application does not
automatically reload Hyprland or restart Quickshell.


### Optional assets, retries and failure recovery

Asset downloads are independent of linking. Core first-login config works
even when an upstream release, wallpaper or cursor download fails.

```sh
dot assets --status                        # offline inventory
dot assets --status --json                 # machine-readable report
dot assets --asset cursors                  # retry one missing asset
dot assets --asset t3code --force          # explicitly update one AppImage
dot assets --asset wallpapers --force      # refresh the wallpaper collection
```

`scripts/fetch-assets` uses the same asset manager: download to temporary
storage, validate ZIP members and expected content, then promote complete
assets. Existing AppImages survive failed downloads. Directory replacements
retain their previous version beside the new one as a `.previous-...` backup.
The T3 Code nightly resolver refuses missing/invalid GitHub release metadata
and only installs a plausible ELF AppImage. Anime4K is pinned to v4.0.1;
other downloads deliberately track the upstream latest URLs, and the resolved
T3 release/tag is stored under `~/.local/opt/t3code/.version.json`.

Zed and mise do **not** run remote `curl | sh` installers anymore.
Install them via `dot optional zed` and `dot optional mise` (official
repository packages). If they are absent, startup and shell initialization
continue without them; mise tool installation is optional. `dot doctor`
lists all remaining optional asset gaps.

### Initial theme and session readiness

`dot install` now runs `scripts/first-login.py` immediately after linking
and **before** enabling Hokum or other user services. This works from a TTY,
without an existing Hyprland session. It generates the required Kitty, Hokum,
Hyprland, and Zsh colour files and checks that they exist. Missing
wallpaper downloads use a locally generated Catppuccin Mocha solid-colour PNG
instead of relying on a missing `sword.jpg` file; an already selected valid
wallpaper always takes priority.

To troubleshoot a first login without affecting a running display server:

```sh
python3 "$(dot cd)/scripts/first-login.py" --check
python3 "$(dot cd)/scripts/first-login.py"        # repair missing initial theme
```

The theme renderer no longer writes `/etc` browser policies during
ordinary wallpaper changes; explicit system-level policy management must be
handled separately. Host-specific audio/GPU/device settings remain under
`hosts/<host>` and are not regenerated.

### System integration is always explicit

```sh
dot system-setup                 # read-only preview of PAM/keyring and i2c-dev
dot system-setup --apply         # explicitly apply the limited changes with sudo
dot install                      # does NOT modify /etc or the login manager
dot install --apply-system       # explicitly include limited PAM/DDC setup
```

The system setup script makes a timestamped root-owned backup before changing
greetd PAM hooks and refuses to edit an unfamiliar PAM layout. Recovery
instructions are printed when a backup is written. The optional i2c-dev
module-load rule is additive. Browser managed-policy ownership and the
display manager/greeter are **never** changed by ordinary `dot install`.

### Explicit greeter staging and TTY recovery

```sh
dot greeter                                      # read-only preflight: deps and existing DMs
dot greeter --stage                              # sudo: stage a complete independent greeter
dot greeter --activate --confirm 'ACTIVATE greetd'
# If replacing SDDM, GDM or LightDM, explicitly include:
dot greeter --activate --replace-display-manager --confirm 'ACTIVATE greetd'
# From a TTY if login is broken: Ctrl+Alt+F2, log in, then:
dot greeter --rollback TXID
```

Staging verifies the Quickshell source, greetd/cage/qs/session dependencies,
then writes only `/etc/greetd/mocha-greeter-staged/`. A missing wallpaper uses
the locally generated fallback or a plain Mocha background. Stage **never**
edits the active login configuration. Activation refuses an existing display
manager without an explicit replacement flag. It atomically swaps prepared
assets into place, backs up the old greetd configuration/assets under
`/var/backups/cachyos-dotfiles/greeter/TXID`, switches service enablement
for the next boot, and **never restarts the active display manager**.
Rollback checks that no one has edited the new greeter since activation,
then restores previous assets, config and service selection.

The former direct `install-greeter` script is disabled because it deleted
working greeter assets before validation. A fake-root automated test verifies
these steps; the real login path still requires a separate CachyOS VM test
before considering installation readiness accepted.

### CachyOS dependency and service gates

The installer audits the selected host's declared pacman and AUR requirements
**before running either package manager**. `python3 scripts/package-audit.py
--repo "$(dot cd)" --host "$(hostname)"` is a read-only standalone check.
A missing mandatory AUR package without an installed `paru` or `yay`
blocks installation with an actionable message. An unavailable repo package
also blocks rather than silently continuing. Install an AUR helper from the
trusted CachyOS setup before retrying. Selected optional groups and host
packages are isolated to their host. `dot doctor` uses the same audit.

Shared Zsh aliases explicitly require `eza`, `bat`, and `fd`, and the
installer now declares those packages. After linking, a missing Hokum systemd
user unit is a blocking error rather than a swallowed service failure;
optional keyring units produce warnings. An existing polkit agent is never
disabled without a verified replacement. Login-shell changes are offered
only with explicit consent (or left to `chsh`).

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

Before first use **on each physical machine**, create a new host profile if
needed and confirm it explicitly:

```sh
dot new-host my-new-host       # only if it doesn't exist yet
DOT_HOST=my-new-host dot confirm-host
DOT_HOST=my-new-host dot doctor
DOT_HOST=my-new-host dot install
```

`dot confirm-host` requires typing the chosen profile name and saves a
non-Git local marker tied to `/etc/machine-id`. Mutating commands refuse to
operate on an unconfirmed profile, even if the hostname matches. A renamed
machine or a cloned system with a new machine-id must be confirmed again.
This is **not** a hardware probe: inspect display/GPU/audio configuration
before confirming. The original host's Chrome and Zed MIME defaults now live
in `hosts/husain-pc/home/.config/mimeapps.list`; the shared defaults make no
assumption that other hosts have those optional applications. The T3 Code
launcher uses `t3code-launch` from the user's `~/.local/bin`, which must be
available in the graphical session `PATH`. The Waypaper seed no longer
references a different user's wallpaper file.

`install` asks for sudo a few times and:

1. requires explicit `dot confirm-host` enrollment (create the host profile first if this machine is new)
2. asks about optional apps (`packages/optional/`, e.g. qBittorrent) — answers are saved per machine —
   then installs `packages/common.txt`, the host's `packages.txt` and the chosen optional groups
   (AUR lists via paru, kept minimal)
3. attempts optional assets: wallpapers, cursors, mpv scripts/shaders and T3 Code (failures are reported but do not block linking; Zed/mise are package-managed)
4. links the effective per-host files transactionally (blocking existing collisions unless explicitly approved)
5. **skips system-level changes by default**; pass `--apply-system` to opt into limited PAM/DDC setup
6. configures user services and runs the host's `setup` if it has one

Keep the existing display manager. Check `dot doctor`, required services,
theme generation, and shell startup before logging out or changing sessions.

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
common/<app>/       GNU Stow-shaped package sources; effective files linked individually
hosts/<hostname>/   this machine only:
  home/             linked on top of common (file by file)
  packages.txt      extra repo packages        aur.txt  extra AUR packages
  optional.txt      optional groups chosen here ("!group" = declined)
  setup             optional script run by `dot install`
  README.md         notes about the hardware
hosts/_template/    starting point for a new machine (`dot new-host`)
packages/           common.txt (repo) and aur.txt (AUR) for every machine;
  optional/<group>.txt   opt-in apps ("# description" line, then packages; aur:<name> for AUR)
seed/               app-writable default configs (btop, waypaper, zed); not linked
system/setup        read-only by default; --apply changes limited PAM/DDC settings
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
