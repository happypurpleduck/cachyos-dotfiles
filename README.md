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

### Installation checkpoints and recovery

Regular `dot install` performs preflight before package changes or linking.
It checks user-systemd/Hokum unit availability before the link transaction.
Once links are applied, essential offline theme generation and user-service
activation must succeed. If a later mandatory phase fails, the installer
attempts to **roll back this installation's managed links** using the exact
transaction ID, rather than leaving the HOME symlinks half-applied. Repeat
`dot link` is now a precise no-op when the effective targets already match.
The installer reports changed links and whether a recovery transaction exists.

First-use files from `seed/` are **copied, never symlinked**, as part of the
same verified home-file transaction as the managed links. Preflight rejects
missing seed destinations below symlinked or blocked parent directories; existing
seed destinations (including app-owned files) are left untouched. A rollback
removes newly created seeds only if their contents remain unchanged, and refuses
to delete any seed subsequently edited by an application or user. `dot unlink`
intentionally leaves copy-once application state in place.

Packages installed by pacman/AUR are **not automatically uninstalled**
on failure; reversing those transactions or root-owned PAM backups requires
separate user review. Optional assets may remain cached. The Mocha greeter
is staged and enabled by default for the next boot, without restarting the
running display manager. Its root-owned rollback is separate from HOME links.

Arbitrary host scripts are also separate from routine installation:

```sh
dot host-setup             # preview selected host-specific executable path
dot host-setup --apply     # explicitly authorize its execution
```

Inspect a host script before consenting. It may perform machine-specific
actions that do not have a generic undo operation.

Installed system packages, explicit host scripts and privileged system
integration are still separate operations with their own recovery boundaries.
The managed-home linker is transactionally restorable; there is no unsafe
promise that all pacman or PAM operations can be rolled back automatically.
Successful link application does not reload Hyprland or restart Quickshell.


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
The uosc and Anime4K multi-file installs carry versioned file-checksum manifests:
missing, modified or partly deleted members are reported as not installed and
can be repaired through a targeted retry. Existing files survive a failed update.
The T3 Code nightly resolver refuses missing/invalid GitHub release metadata
and only installs a plausible ELF AppImage. Anime4K is pinned to v4.0.1;
other downloads deliberately track the upstream latest URLs, and the resolved
T3 release/tag is stored under `~/.local/opt/t3code/.version.json`.

Zed and mise are **not** pacman/AUR packages in this project.
Their **official upstream user-local installers** manage the binary and its
subsequent updates. A full `dot install` bootstraps **missing** mise and Zed
by default, without sudo or a package manager, and does not upgrade existing
user-local installations. These commands also remain available:

```sh
dot apps status               # read-only: self-managed / externally managed / missing
dot apps install mise zed     # install missing binaries independently of full install
dot apps update mise          # runs mise self-update --yes --no-plugins
dot apps update zed           # reminder: Zed auto-updates on restart
```

`dot apps install` and full `dot install` download and execute a script
from the official `https://mise.run` or `https://zed.dev/install.sh` endpoint
**only when that upstream-managed application is missing**. It rejects non-HTTPS or unexpected
redirect domains, prints the script SHA256, and never uses sudo. Do not mix
a pacman-managed `mise` or `zed` executable with upstream self-update:
the command refuses an already detected external installation and asks for
a manual migration. Mise's official installer validates its downloaded
binary against upstream release checksums; Zed uses its own built-in
automatic updater. Neither application is silently updated during `dot install` or Git
synchronization. Existing external/package-managed installations are never
replaced silently; the installer reports the conflict rather than mixing
self-updating and pacman-managed copies.

Installed-package discovery is **not** an installation manifest: `dot packages`
prints repository and foreign/local packages outside declared requirements,
without changing tracked host files. Foreign entries are not necessarily AUR
packages. To replicate a chosen extra on this machine, explicitly review and
edit `hosts/<host>/packages.txt` for official repository packages or
`hosts/<host>/aur.txt` for reviewed, allowlisted AUR exceptions. Previously
pacman-installed mise/Zed are reported for manual migration, never adopted into
managed host requirements or silently replaced.

On a new machine, `./install` provides the shared packages and self-managed
mise/Zed automatically. On an already configured machine the same command
skips applications already present. You may also use `dot apps install mise zed`
independently to repair only those applications. `dot doctor` reports missing
or externally managed upstream apps separately from optional asset downloads.

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
dot install                      # stage and enable Mocha greetd for next boot
dot install --apply-system       # additionally apply limited PAM/DDC setup
```

The system setup script makes a timestamped root-owned backup before changing
greetd PAM hooks and refuses to edit an unfamiliar PAM layout. Recovery
instructions are printed when a backup is written. The optional i2c-dev
module-load rule is additive. Browser managed-policy ownership and the
display manager/greeter **are staged and enabled by default** during a
successful `dot install`. The currently running session is never restarted.

### Default greeter installation and TTY recovery

```sh
dot greeter                                      # read-only preflight: deps and existing DMs
dot greeter --install                            # reconcile greeter (also done by dot install)
dot greeter --stage                              # sudo: stage a complete independent greeter
dot greeter --activate --confirm 'ACTIVATE greetd'
# If replacing SDDM, GDM or LightDM, explicitly include:
dot greeter --activate --replace-display-manager --confirm 'ACTIVATE greetd'
# From a TTY if login is broken: Ctrl+Alt+F2, log in, then:
dot greeter --rollback TXID
```

`dot install` stages and activates the Mocha greeter as the default login
manager, including replacing an existing SDDM/GDM/LightDM for the next boot.
Repeated installations that already match the expected theme, greetd config,
and service state do not make another greeter transaction. If activation fails,
the original display manager is restored by its own transaction and installation
reports failure. This is a default *declarative desktop setup*, not a forced
restart or an unchecked replacement.

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
working greeter assets before validation. A fake-root automated test checks staging and recovery logic. The owner
will verify the actual login path on their machine when adopting the configuration;
no virtual-machine test is required for merging.

### Optional system services belong to the host

`hosts/<host>/services.txt` is an allowlisted manifest for optional system
services; currently only `bluetooth` is supported. By default it is empty.
No other host's preferences are copied or activated.

```sh
dot services                                   # read-only selected-host service status
dot doctor --strict                             # includes missing chosen Bluetooth prerequisites
dot services --apply --confirm 'ENABLE HOST SERVICES'
```

The last command is explicit opt-in and may run sudo to enable/start
`bluetooth.service` after checking `bluez` and the unit exist. It is
idempotent and never disables other services. Generic `dot install` reports
service readiness but **does not silently enable Bluetooth**. A host with
no selected optional services needs no privileged system-service changes.

### CachyOS dependency and service gates

The installer audits the selected host's declared pacman and AUR requirements
**before running either package manager**. `python3 scripts/package-audit.py
--repo "$(dot cd)" --host "$(hostname)"` is a read-only standalone check.
AUR usage is restricted to explicitly documented exceptions in
`packages/aur-exceptions.json`: `hokum-bin` as the core notification
service, and shared `google-chrome` for Chrome on every desktop. No other AUR
package may be introduced without a separate review and policy update.
An AUR installer is never invoked unattended; the installer displays
the pending exceptions and requires typing `APPROVE AUR` before proceeding.
**Shelly is the only supported AUR manager.** The installer uses
`shelly install aur <package>` for allowlisted exceptions and does not
attempt another AUR backend. A missing Shelly CLI blocks installation
before any package changes, with guidance to install `shelly` from the
official CachyOS repository. AUR installations still require explicit
`APPROVE AUR` confirmation and Shelly's own PKGBUILD review. Unavailable
repository packages also block rather than being silently skipped. Selected
optional groups and host packages remain isolated to their host. `dot doctor`
uses the same audit.

Shared Zsh aliases explicitly require `eza`, `bat`, and `fd`, and the
installer now declares those packages. After linking, a missing Hokum systemd
user unit is a blocking error rather than a swallowed service failure;
optional keyring units produce warnings. An existing polkit agent is never
disabled without a verified replacement. Login-shell changes are offered
only with explicit consent (or left to `chsh`).

The optional T3 Code nightly asset is fetched directly from the upstream
GitHub release API with JSON media negotiation, then selects and verifies the
AppImage for the current CPU architecture (x86-64 or ARM64). If a previous
attempt failed, retry just this asset with
`./scripts/fetch-assets --asset t3code`; it does not require reinstalling
packages or relinking the desktop configuration.

## Owner verification on CachyOS

Automated checks exercise disposable homes, two independent Git clones,
host-specific overrides, rollback, package policy and simulated system services.
They cannot prove real desktop, login-manager or hardware behavior.

The owner will adopt this configuration directly on their own machine and
verify it there. **No VM matrix, recorded evidence or additional manual test
is a prerequisite for merging.** Start with `dot doctor` and
`dot install --dry-run`, review any blockers and backups, then apply.
Greeter activation, privileged PAM changes, host scripts and Bluetooth changes
remain separately opt-in. Verify the session and multi-machine sync in normal
use; report any defects as GitHub issues.

## New machine

**Stock CachyOS configuration replacement:** Even a new installation may
contain files such as `~/.zshrc`, `~/.config/hypr/hyprland.lua` and Micro
editor syntax definitions. `./install` **replaces them with the repository's
managed links by default** without a separate conflict-approval prompt.
Existing files are automatically saved in the transaction journal before
replacement; no complete app directory is removed. Directory/symlink parent
collisions and cross-host links remain hard blockers. Use
`./install --dry-run` to preview exactly what will be replaced without
modifying the machine. The installer prints a transaction ID for
`dot rollback TXID`, and attempts automatic rollback on later install
failures. Package installations and privileged changes are not part of
home-file rollback.

Install CachyOS (any desktop, or none), log in, then:

```sh
sudo pacman -S --needed git openssh github-cli
gh auth login                       # SSH, so the private repo can be cloned
git clone git@github.com:happypurpleduck/cachyos-dotfiles.git ~/cachyos-dotfiles
~/cachyos-dotfiles/install             # creates and confirms a new host profile interactively
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

**First install:** `./install` detects a missing host profile, asks before
creating `hosts/<hostname>/` from `hosts/_template`, and prompts you to
confirm the selected machine by typing its hostname. It uses the repository's
own `./common/bin/.local/bin/dot` script, so `dot` does **not** need to be
installed yet. On a returning/confirmed machine, the confirmation step is a
no-op. If you want to review and commit the new host-specific settings before
applying packages, links or services, use `./install --prepare-host` and then
`./install`. Read-only `./install --dry-run` never creates a host profile.

For manual control, you can also create/confirm the profile explicitly:

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
   (reviewed AUR exceptions via Shelly only)
3. attempts optional assets: wallpapers, cursors, mpv scripts/shaders and T3 Code (failures do not block linking)
4. links the effective per-host files transactionally, automatically backing up replaced stock config files
5. installs missing mise and Zed via their official user-local installers, with no pacman/AUR management
6. stages and activates Mocha greetd for the next boot, backing up any previous display-manager state; no login-session restart
7. keeps other system integration opt-in via `--apply-system` (PAM/DDC), and host scripts separately consented

After a full installation, confirm the printed Mocha greeter rollback command,
check `dot doctor`, required services, theme generation and shell startup before
rebooting. If login breaks, switch to a TTY (Ctrl+Alt+F2) and use
`dot greeter --rollback TXID` from the activation output.

**Multi-host update discipline:** Commit and push `hosts/husain-parcel` only
with that machine's settings, leaving `hosts/husain-pc` unchanged. On each
machine, fetch and preview changes independently; a successful CI build does
not prove a graphical login will work on that particular hardware. Do not
assume repository commits also apply themselves to already-running desktops.

## Day to day

```sh
dot status          # tracked changes and app-replaced managed links
dot diff            # review tracked changes for common/ + this host
dot save "message"  # commit tracked shared/current-host files, rebase and push
dot pull            # fetch/rebase without stashing or creating new links
dot add <file>      # preview a safe, non-destructive config import
dot add --apply --host <file>  # copy into this host (review/link/commit separately)
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
to guess which repository copy should receive it. Importing that app-authored
file is explicit and preview-first:

```sh
dot add ~/.config/example/settings.conf                 # preview shared source
dot add --host ~/.config/example/settings.conf          # preview host override
dot add --host --apply ~/.config/example/settings.conf  # COPY; do not move/delete HOME
dot add --apply --replace-source ~/.config/example/settings.conf
# Next: dot doctor, dot link --backup-conflicts, git add <reviewed path>, dot save
```

The importer refuses existing managed-source replacement without
`--replace-source`, prevents common-owner collisions, detects symlinked
parents, rejects binary/oversized configs and known secret/keyring paths,
and preserves the original user file. When replacing a repository source
it saves the previous version under
`~/.local/state/dotfiles-backup/imports/<TXID>/`. It does **not**
stage/commit any new files automatically. Inspect contents before running
Git add; path heuristics cannot guarantee a config has no credentials.
A common-source replacement can affect other linked machines after their
approved sync, so choose `--host` for machine-specific values. Rebase conflicts
stop the sync without force pushing; follow Git's `rebase --continue` or
`rebase --abort` guidance. **Incoming shared/current-host changes are now
reviewed before any Git rebase can touch linked source files.**

```sh
dot pull                  # fetch and preview; accepts only other-host changes
dot pull --apply          # explicitly permit preflight-checked active updates
dot doctor                # inspect resulting targets/dependencies
dot link                  # apply newly added effective file links if wanted
```

When `dot save` encounters active remote changes, it preserves the local
commit but refuses to rebase or push. Review with `dot pull`, then run
`dot pull --apply` (after fixing missing dependencies) and `dot save`
again. The upstream SHA is pinned after fetch: Git rebases only against the
exact revision that passed the preflight. Incoming new file targets that would
overwrite local app data are blocked. Remote scripts are **never executed**
as part of the preflight. Git conflicts still stop safely for normal Git
resolution; there is no auto-stash, forced push, or implicit service reload.

**Important limitation:** Config files already linked into the checkout
can still change as soon as the deliberately approved Git rebase runs;
existing applications may reload those files automatically. For sensitive
live sessions, review the diff and apply during a safe maintenance window.
The command never silently activates *new links*, restarts services, or
installs packages.

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
