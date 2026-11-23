# Two-host CachyOS acceptance and recovery

**Status: automated mock tests implemented; real CachyOS VM execution remains UNVERIFIED.** No live machine is touched by CI. Record results using the verification template before closing issue #9.

## Test environments

| Scenario | Base install | Login manager | Login user | Profile |
| --- | --- | --- | --- | --- |
| A | CachyOS existing graphical desktop | Existing SDDM/GDM | Distinct username A | desktop-a |
| B | CachyOS minimal/CLI install | None initially | Distinct username B | minimal-b |

Set each VM hostname to desktop-a or minimal-b during CachyOS installation so its /etc/hostname matches its selected profile. Record ISO/date, kernel, architecture, session, selected display manager, VM snapshot, git SHA and redacted logs. Never record full machine-id, API keys or credentials.

## First-time host setup (repeat separately on A and B)

Install Git, Python and GitHub SSH authentication from CachyOS official repos.
Clone the private repository to a **different checkout path** on each machine.
Before any install:

    git clone git@github.com:happypurpleduck/cachyos-dotfiles.git "$HOME/config-checkout"
    cd "$HOME/config-checkout"
    ./install --dry-run
    ./common/bin/.local/bin/dot new-host desktop-a
    DOT_HOST=desktop-a ./common/bin/.local/bin/dot confirm-host
    DOT_HOST=desktop-a ./common/bin/.local/bin/dot plan --json
    DOT_HOST=desktop-a ./common/bin/.local/bin/dot doctor --json

Use minimal-b as the profile on B. Inspect host.lua, monitor layout, GPU/audio settings and package extras before confirmation; no other machine's hardware profile should be reused blindly. Check that preflight never modifies /etc, any login manager or the home directory.

Review packages/aur-exceptions.json and the actual AUR PKGBUILD for every exception. Only approved, essential Hokum and chosen Chrome may use AUR; the install prompt requires typing APPROVE AUR. Mise and Zed must be first-party/self-managed.

    dot install
    dot doctor
    python3 "$(dot cd)/scripts/first-login.py" --check
    dot assets --status
    dot apps status
    dot apps install mise zed        # only when explicitly wanted
    dot apps update mise             # self-update
    dot apps update zed              # app handles updates on restart

Check generated Hyprland, Kitty, Hokum and Zsh theme files and the local wallpaper fallback before first GUI login. Ordinary dot install must **never** replace an existing greeter.

### Explicit greeter opt-in

Keep the working SDDM/GDM on A initially. B may separately stage the greeter after a VM snapshot:

    dot greeter
    dot greeter --stage
    dot greeter --activate --confirm 'ACTIVATE greetd'

To replace an existing display manager, --replace-display-manager must also be specified. Activation must not restart an active manager or terminate the current session. Observe it after next boot. From a TTY, recover via:

    dot greeter --rollback TXID

## First-login verification

- Verify Hyprland session, screen layout, scale and host-specific autostart.
- Verify Quickshell bar, launcher, lock, shortcuts and controls; unlock and relogin.
- Verify Hokum notification service and absence of conflicting D-Bus notification servers.
- Verify Zsh aliases (eza/bat/fd), fonts, Kitty, generated GTK/Qt/KDE theme outputs, audio.
- Check that the fallback cursor and wallpaper render without optional downloads.
- Test optional Bluetooth only when the host has selected it in
  hosts/<hostname>/services.txt: dot services is read-only,
  dot services --apply --confirm 'ENABLE HOST SERVICES' explicitly enables
  it after unit/package checks. Other hosts must not be affected.
- Confirm that B's browser/editor MIME defaults do not assume Chrome/Zed are installed.
- Confirm self-managed mise/Zed update independently from pacman and AUR.

## A edits, B syncs, and ownership boundaries

1. On A, edit shared Quickshell and A-only Hyprland config, leave an unrelated private app file, run dot status and dot diff.
2. Run dot save "A updates"; verify only tracked shared/current-host files are published.
3. On B, dot pull must preview/block active shared config; inspect then dot pull --apply, followed by dot doctor and dot link when new links are needed.
4. Confirm B receives shared edits, but never A-only monitor/GPU/audio configuration.
5. Modify B-only Zsh, Hyprland and Quickshell overrides. Sync A and verify its effective config is independent. Remove a B override and verify a shared fallback on B only.
6. Edit the same shared file concurrently on A and B; verify a recoverable rebase conflict, with git -C "$(dot cd)" rebase --abort as the recovery option.
7. Put a fake secret in an untracked file; normal dot save must not add it. Confirm intentional staged maintenance requires an explicit opt-in.

## Failure injection (on disposable VM snapshots only)

- Missing required package: the audit blocks; no silently skipped AUR packages.
- Missing Hokum unit, missing optional mise/Zed, failed wallpaper/cursor download: setup reports accurate status, first-login shell remains usable.
- App-replaced home symlink: plain dot link blocks; approved --backup-conflicts retains exact bytes; dot rollback TXID restores them.
- Legacy Stow directory symlink: dot migrate-folded previews, --apply converts to per-file managed links without deleting generated state, rollback restores the original link.
- Conflicting display manager: activation blocks without explicit consent; from a TTY restore the previous known-good login manager and config.
- Interrupted sync/failed shared rebase: no forced push, no lost local commits or silent active-config changes.
- Repeated link/setup: verify idempotence and truthful no-op vs changed summary.

## Acceptance evidence

For each VM, save an anonymized result: CachyOS image/date, Git SHA, environment, doctor output, optional asset status, screenshots or text observations, greeter service state, sync scenarios, failure-injection results and rollback steps. Record unresolved defects as linked GitHub issues.

**Do not mark issue #9 or epic #1 fully accepted on Ubuntu CI alone.** Only a real CachyOS VM can verify PAM/greetd login, first-boot Hyprland/Quickshell, GPU, audio, Bluetooth and persistent session state.
