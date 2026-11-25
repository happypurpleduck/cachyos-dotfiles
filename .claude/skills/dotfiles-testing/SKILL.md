---
name: dotfiles-testing
description: How to verify changes in this dotfiles repo — the offline test suite in tests/, what CI runs, safe previews of dot commands, and how to tell a pre-existing failure from one you caused. Use before finishing or committing any change here.
---

# Verifying changes

Everything in `tests/` is offline and runs against temporary fake homes and
repos; nothing touches the real `~`, system services or packages. CI is
`.github/workflows/dotfiles-static.yml` (Ubuntu, `bash -n` + the tests).

## Run what you touched

| Changed | Run |
|---|---|
| any shell script | `bash -n <file>` (and add new scripts to the CI `bash -n` line) |
| linking / `effective-targets.py` / `dot-links.py` / new files under `common/` or `hosts/*/home` | `python3 tests/test-effective-targets.py`, `python3 tests/test-links.py`, `python3 tests/test-repository-audit.py` |
| package lists, optional groups, `package-audit.py` | `python3 tests/test-package-audit.py`, `python3 tests/test-repository-audit.py`, `bash tests/test-install-recovery.sh` |
| `host-services.py`, `services.txt` | `python3 tests/test-host-services.py` |
| `dot` itself | `bash tests/test-install-recovery.sh`, `bash tests/test-checkout-discovery.sh`, `bash tests/test-new-host-bootstrap.sh`, `bash tests/test-two-host-sync.sh` |
| greeter, assets, first login, pull/import | the matching `tests/test-<area>.py` |

Run everything CI runs:

```sh
for t in tests/test-*.py; do python3 "$t" >/dev/null || echo "FAIL $t"; done
for t in tests/test-*.sh; do bash "$t" >/dev/null 2>&1 || echo "FAIL $t"; done
```

## Previews against the real machine (read-only)

`dot plan`, `dot link --dry-run`, `dot install --dry-run`, `dot doctor`,
`dot services`, `dot optional --list`, `dot status`, `dot diff`. A dry-run's
"BLOCKED … folded-parent" lines are legacy Stow directory links awaiting
`dot migrate-folded`, not something your change caused — compare against the
same command on a clean `git stash` if unsure.

## Pre-existing failures

If a test fails in a file you didn't touch, confirm it on the base commit
(`git stash; <test>; git stash pop`) and report it separately instead of
"fixing" unrelated code in the same change. Report results honestly: say which
tests ran, which passed, and what you could not test (anything needing sudo,
a reboot, a graphical login or hardware).
