# HOSTNAME

What's specific to this machine. Linked on top of `common/` by `dot link`.

| File | What |
|---|---|
| `home/.config/hypr/host.lua` | monitors, workspace→monitor rules, GPU env vars, autostart apps |
| `home/.config/mocha-shell/host.json` | audio device names, AutoEq target, mic for noise suppression |
| `packages.txt` / `aur.txt` | packages beyond `packages/common.txt` (`dot packages` snapshots them) |
| `setup` | optional script run at the end of `dot install` |

Add more machine-only files with `dot add --host <file>`.

## Notes

- 


## Multi-machine setup

Use a distinct host directory for every physical CachyOS machine. The default
profile name matches /etc/hostname; do not reuse another machine's profile to
copy its monitor, GPU, audio, or service settings. Confirm it locally with:

    dot confirm-host
    dot plan
    dot doctor

Shared defaults belong under common/; overrides or additional files for this
machine belong under hosts/<hostname>/home/. A per-file override takes priority
without hiding other files in the same shared app directory.

Packages for the system go in packages/common.txt or this host's packages.txt.
Applications that update themselves from their upstream publisher (mise, Zed)
belong in the separate explicit dot apps lifecycle, never AUR or pacman lists.
Every AUR exception must be documented and reviewed. Do not commit credentials,
secret tokens, local keyrings, runtime histories, device identifiers or
application-generated caches.

Full multi-host test and recovery instructions: docs/verification.md.

System services are separate from user services: edit this host's services.txt
to select supported optional Bluetooth service, run dot services to inspect
readiness, and only then explicitly authorize dot services --apply.
