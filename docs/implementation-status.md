# Implementation status for epic #1

**As of 2026-11-23:** The scoped implementation is on **draft, stacked pull requests #10–#27**, with **follow-up PR #29 merged into the tip (#27 and integration #28)** after passing its offline regression suite. **Nothing has been merged into `main`, no actual machine has been modified, and the real CachyOS VM acceptance matrix has not run.**

This document separates code coverage from operational verification so review/reflection can evaluate the actual state rather than conflating passing unit/fixture tests with a usable first login.

| Issue | Implemented changes | Draft PRs | Remaining validation |
| --- | --- | --- | --- |
| #2 Host overrides | Deterministic effective per-file precedence for shared vs host files; transactional link/unlink, no-op reapplication and rollback; legacy folded-Stow migration; retired-link status | #12, #14, #15, #27, #29 | Test on both real CachyOS profile layouts |
| #3 Two-way sync | Ownership-scoped saves and staged exceptions; gated remote fetch/preflight/approved rebase; exact-SHA sync; preview-first app config import | #11, #23, #26 | Observe cross-machine sync and rebase conflicts on two VMs |
| #4 Prerequisites | CachyOS package/AUR audit, Zsh dependencies, required user service checks, host-only Bluetooth activation, Chrome host MIME defaults, read-only installed-package inventory separated from managed requirements | #17, #18, #22, #25, #29 | Validate real package inventory, Hokum and optional Bluetooth |
| #5 Portability | Checkout discovery outside HOME default; account-agnostic launcher/seed; explicit machine enrollment; repo-wide source audit | #10, #18, #24 | Verify alternative usernames/checkout paths on VMs |
| #6 Recovery | Doctor/dry-run, file transaction journal including copy-once seeds, explicit Stow migration, opt-in PAM/DDC, safe greeter staging and TTY rollback, installer failure checkpoints | #13–#16, #21, #27, #29 | Test login-manager recovery, PAM and interrupted install on VM snapshots |
| #7 First login | Offline wallpaper/theme generation before services, missing-file fallback, greeter dependency checks, optional remote assets | #19, #20, #21, #27 | Verify Hyprland, Quickshell, Kitty, Hokum, lock, login, keyring and session |
| #8 Assets | Safe optional asset retries, staged download/validation and checksummed MPV group manifests, previous-asset preservation, explicit first-party mise and Zed lifecycle | #20, #22, #29 | Exercise actual upstream installs and corrupted downloads on VM |
| #9 Acceptance | Disposable two-host Git and HOME tests, fake systemd/greeter root, seed/link fault injection, repository audit, VM test matrix and blank results template | #10–#27, #29 | **Execute** and record two CachyOS VM scenarios in docs/verification-result-template.md |

## Package-management principle

Use **CachyOS/Arch official repositories** for base/system dependencies. Use an explicitly selected **first-party upstream installer and updater** for mise and Zed: `dot apps install mise zed`, `dot apps update mise`; Zed updates itself on restart. Do not distribute either application via pacman/AUR in this setup.

The `dot packages` command reports installed extras without rewriting host requirement manifests. Every managed package choice is deliberate; observed foreign/local packages must never be automatically promoted to approved AUR requirements.

The only currently allowlisted AUR exceptions are **Hokum**, the core notification daemon, and **Google Chrome**, selected by the original host. Both remain exceptional packages requiring explicit human review and the typed `APPROVE AUR` consent before missing AUR packages are installed. New AUR dependencies fail policy validation until justified and approved. See `packages/aur-exceptions.json`.

## Safety and rollback boundaries

- Home-file symlinks **and new copy-once seed files** have transactional journals and backups; an installer failure after linking attempts automatic restoration of the relevant transaction, while refusing to remove seeds subsequently edited by an application/user.
- Existing **linked sources** in a Git checkout can change immediately after an **explicitly approved** remote rebase. Remote scripts are never executed as part of preflight.
- Existing Stow **directory** symlinks are deliberately migrated only by explicit `dot migrate-folded --apply`.
- Greeter activation is a distinct manually consented operation. It does **not** restart the active login manager, preserves root-owned backups and exposes TTY rollback.
- Installation does **not** provide a false whole-machine rollback guarantee. Installed packages, AUR packages, downloaded optional assets, and privileged PAM/DDC changes may need separate review/manual recovery. Never presume `dot rollback` undoes those operations.
- `dot add` only imports configurations after a preview and explicit copy. It never moves home data, stages Git paths or publishes secrets automatically.

## Review readiness

The cumulative integration diff can be reviewed without merging the individual stacked PRs. Review in issue order or PR order; apply only after a clean code/security review.

To declare the epic fully **accepted**, complete **both** documented CachyOS scenarios in [verification.md](verification.md) and record observed outcomes in [verification-result-template.md](verification-result-template.md). In particular, do not infer that Ubuntu CI can validate real greetd/PAM, Hyprland/Quickshell startup, session lock, Bluetooth, audio or hardware-specific device behavior.

**Current verdict: implementation ready for review; operational acceptance pending real CachyOS validation.**
