# Implementation status for epic #1

**As of 2026-11-23:** The scoped implementation is on stacked pull requests #10–#27, with review fixes from merged #29 integrated into #27/#28. All cumulative automated checks passed. The owner has opted to verify the setup directly on their own CachyOS systems; virtual-machine testing is **not** an acceptance or merge requirement.

This document distinguishes automated code verification from real-device behavior, which the owner will check during adoption. Real-device testing is not represented as already completed.

| Issue | Implemented changes | PRs | Optional owner checks during use |
| --- | --- | --- | --- |
| #2 Host overrides | Deterministic effective per-file precedence for shared vs host files; transactional link/unlink, no-op reapplication and rollback; legacy folded-Stow migration; retired-link status | #12, #14, #15, #27, #29 | Confirm host overrides on actual configured systems |
| #3 Two-way sync | Ownership-scoped saves and staged exceptions; gated remote fetch/preflight/approved rebase; exact-SHA sync; preview-first app config import | #11, #23, #26 | Try shared and host-only edits across normal machines |
| #4 Prerequisites | CachyOS package/AUR audit, Zsh dependencies, required user service checks, host-only Bluetooth activation, Chrome host MIME defaults, read-only installed-package inventory separated from managed requirements | #17, #18, #22, #25, #29 | Confirm local package choices and optional services |
| #5 Portability | Checkout discovery outside HOME default; account-agnostic launcher/seed; explicit machine enrollment; repo-wide source audit | #10, #18, #24 | Confirm any new system's account and checkout path |
| #6 Recovery | Doctor/dry-run, file transaction journal including copy-once seeds, explicit Stow migration, opt-in PAM/DDC, safe greeter staging and TTY rollback, installer failure checkpoints | #13–#16, #21, #27, #29 | Keep rollback/TTY recovery instructions available before opt-in greeter changes |
| #7 First login | Offline wallpaper/theme generation before services, missing-file fallback, greeter dependency checks, optional remote assets | #19, #20, #21, #27 | Confirm first login and optional desktop integrations |
| #8 Assets | Safe optional asset retries, staged download/validation and checksummed MPV group manifests, previous-asset preservation, explicit first-party mise and Zed lifecycle | #20, #22, #29 | Use upstream installers only as needed |
| #9 Automated regression and documentation | Disposable two-host Git and HOME tests, fake systemd/greeter root, seed/link fault injection, portability audit and owner-facing README | #10–#27, #29 | Optional runtime feedback, not a merge gate |

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

## Merge readiness and owner adoption

The integrated changes have passed automated code/security review and regression
CI in disposable environments. **No VM scenario or manual evidence collection
is required for merge.** The owner will validate the actual desktop, login,
audio/Bluetooth and A↔B synchronization directly on their CachyOS machines
after pulling the changes.

For safer initial adoption, use `dot doctor` and `dot install --dry-run`,
review any home-file collisions, and keep a TTY and recovery path available
before explicitly enabling a new greeter or privileged PAM changes. These
are operational precautions, not a demand for separate test infrastructure.

**Verdict: eligible for merge subject to a green final CI run and GitHub
mergeability. Actual-device results are owner-verified after adoption.**
