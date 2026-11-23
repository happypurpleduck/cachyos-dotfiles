# CachyOS VM acceptance record — TEMPLATE (unverified)

Do not fill PASS without actually running the test on the named VM.

| Field | Observation |
| --- | --- |
| VM scenario (A desktop / B CLI) | NOT TESTED |
| CachyOS ISO and installation date | NOT RECORDED |
| Kernel / architecture | NOT RECORDED |
| Username, anonymized | NOT RECORDED |
| Host profile name | NOT RECORDED |
| Repository commit SHA | NOT RECORDED |
| Initial display manager | NOT RECORDED |
| Snapshot / recovery method | NOT RECORDED |
| Final login manager | NOT RECORDED |

## Checklist

| Check | Status (PASS/FAIL/NOT RUN) | Evidence / notes |
| --- | --- | --- |
| Fresh checkout in non-default directory | NOT RUN | |
| Local host confirmation and isolation | NOT RUN | |
| Read-only doctor and dry-run | NOT RUN | |
| Prerequisite packages and AUR approvals | NOT RUN | |
| Safe home-file linking and rollback | NOT RUN | |
| First-login generated files and offline fallback | NOT RUN | |
| Hyprland + Quickshell + Kitty | NOT RUN | |
| Hokum notifications and systemd user unit | NOT RUN | |
| Lock/unlock, session restore, keyring | NOT RUN | |
| Browser/editor MIME defaults | NOT RUN | |
| Audio, Bluetooth and hardware devices | NOT RUN | |
| Native-managed mise/Zed install/update | NOT RUN | |
| Greeter stage / activation / TTY rollback | NOT RUN | |
| A/B shared and independent-host sync | NOT RUN | |
| Shared-edit Git conflict and recovery | NOT RUN | |
| Optional asset download failure and retry | NOT RUN | |
| Repeat application is idempotent | NOT RUN | |

## Observed defects

For each defect, record: reproduction steps, expected/actual result, redacted logs, a GitHub issue URL, and whether rollback restored the previous working session.

## Recovery evidence

Record exact transaction IDs only when safe to share, whether files were restored byte-for-byte, and whether the previous login manager remains usable.

## Verdict

NOT TESTED. Leave issue #9 and epic #1 open until both CachyOS VM scenarios have reproducible passing evidence.
