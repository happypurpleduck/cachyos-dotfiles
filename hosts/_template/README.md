# HOSTNAME

What's specific to this machine. Linked on top of `common/` by `dot link`.

| File | What |
|---|---|
| `home/.config/hypr/host.lua` | monitors, workspace→monitor rules, GPU env vars, autostart apps |
| `home/.config/mocha-shell/host.json` | audio device names, AutoEq target, mic for noise suppression |
| `packages.txt` / `aur.txt` | packages beyond `packages/common.txt` (`dot packages` only reports installed extras) |
| `setup` | optional host-specific script, run with `dot host-setup --apply` |

Add more machine-only files with `dot add --host <file>`.

## Notes

- 


## Multi-machine setup

Use a distinct host directory for every physical CachyOS machine. The default
profile name matches /etc/hostname; do not reuse another machine's profile to
copy its monitor, GPU, audio, or service settings. On a new machine, `./install` creates the new profile before
linking anything. To prepare without installing, run `./install --prepare-host`.
You can also run these commands from the checkout without a globally installed
`dot`:

    ./common/bin/.local/bin/dot plan
    ./common/bin/.local/bin/dot doctor

Shared defaults belong under common/; overrides or additional files for this
machine belong under hosts/<hostname>/home/. A per-file override takes priority
without hiding other files in the same shared app directory.

Packages for the system go in packages/common.txt or this host's packages.txt.
Applications that update themselves from their upstream publisher (mise, Zed)
belong in the separate explicit dot apps lifecycle, never AUR or repo package lists.
Every AUR exception must be documented and reviewed. Do not commit credentials,
secret tokens, local keyrings, runtime histories, device identifiers or
application-generated caches.

Multi-host setup, sync and recovery instructions: README.md.

System services are separate from user services: edit this host's services.txt
to select supported optional services (bluetooth, tailscale, libvirt), run dot services
to inspect readiness, then dot services --apply to enable them.
